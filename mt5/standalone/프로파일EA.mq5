//+------------------------------------------------------------------+
//|  프로파일EA.mq5                                                    |
//|  가격대별 틱 프로파일 (3W vs 1W) → 팬트리 → 웹앱                    |
//|                                                                  |
//|  WebRequest 허용 필요: 도구>옵션>전문가 자문                       |
//|     https://getpantry.cloud , https://api.telegram.org            |
//|  매매하지 않음 (관찰 전용)                                         |
//+------------------------------------------------------------------+
#property copyright "day1"
#property version   "1.08"
#property strict

//--- 입력 ---------------------------------------------------------
input string  InpDashUrl        = "";      // 팬트리 바스켓 URL (프로파일 전용 · 새로 발급)
input bool    InpDashEnable     = true;    // 전송 ON
input double  InpBucket         = 2.0;     // 가격 버킷 크기 ($)
input int     InpW3Days         = 3;       // 장기 창 (일) — 브로커 틱보관 3일에 맞춤 (예:3=3D)
input int     InpW1Days         = 1;       // 단기 창 (일) — 예:1=1D
input int     InpMaxBuckets     = 60;      // 최대 버킷 수 (초과시 현재가 중심 클램프)
input int     InpSendSec        = 15;      // 전송 주기 (초) — 현재가 갱신
input int     InpW1RefreshSec   = 120;     // 1W 재계산 주기 (초)
input int     InpW3RefreshSec   = 600;     // 3W 재계산 주기 (초)
input int     InpServerToKST    = 6;       // 서버→KST 시차 (시간)
input ENUM_TIMEFRAMES InpDensTF_A = PERIOD_H4;  // 밀도 상위 TF (직전봉)
input ENUM_TIMEFRAMES InpDensTF_B = PERIOD_H1;  // 밀도 중위 TF (직전+현재)
input ENUM_TIMEFRAMES InpDensTF_C = PERIOD_M15; // 밀도 하위 TF (직전+현재)
input bool    InpTgEnable       = false;   // 텔레그램 브리핑 ON
input string  InpTgToken        = "";      // 텔레그램 봇 토큰
input string  InpTgChatId       = "";      // 텔레그램 chat_id
input int     InpBriefMin       = 30;      // 정기 브리핑 주기(분) — 0=끔
input bool    InpBriefEvents    = true;    // 이벤트(자리/밀도 전환) 브리핑
input int     InpEventGapSec    = 300;     // 이벤트 브리핑 최소 간격(초) — 스팸 방지
input int     InpBriefStartKST  = 9;       // 브리핑 시간대 시작 (KST 시)
input int     InpBriefEndKST    = 23;      // 브리핑 시간대 끝 (KST 시)

//--- 전역 ---------------------------------------------------------
double  g_base = 0.0;
int     g_nb   = 0;
long    g_t3[], g_u3[], g_d3[];   // 3W: 틱수/매수/매도
long    g_t1[], g_u1[], g_d1[];   // 1W
datetime g_lastW3=0, g_lastW1=0, g_lastSend=0;
bool    g_ready=false;
// 완료봉 밀도 캐시 (slot0=A직전, slot1=B직전, slot2=C직전) — 봉이 넘어갈 때만 재계산
datetime g_cBarT[3]; double g_cDens[3]; long g_cTk[3]; double g_cNet[3]; int g_cDir[3];
// 진행봉 증분 누적 (slot0=C현재) — 매 전송 새 틱만 추가
datetime g_fBarT[1]; ulong g_fLastMs[1]; long g_fCnt[1]; double g_fOpen[1];
// 브리핑용 밀도 스냅샷 (BuildJson에서 갱신) + 이벤트 상태
double g_dvA=0,g_dvB=0,g_dvC1=0,g_dvC0=0,g_netC0=0; int g_dirC0=0;
datetime g_lastBrief=0; string g_lastSig="";

//--- 유틸 ---------------------------------------------------------
double PriceOf(const MqlTick &t){
   if(t.last>0.0) return t.last;
   if(t.bid>0.0 && t.ask>0.0) return (t.bid+t.ask)/2.0;
   if(t.bid>0.0) return t.bid;
   return t.ask;
}
string JNum(const double v,const int d){ return DoubleToString(v,d); }

//--- 범위 결정 (D1 봉 고저 기준) ----------------------------------
void ComputeRange(){
   double hi=-1, lo=-1;
   for(int s=0;s<=InpW3Days;s++){
      double h=iHigh(_Symbol,PERIOD_D1,s), l=iLow(_Symbol,PERIOD_D1,s);
      if(h<=0.0) continue;
      if(hi<0||h>hi) hi=h;
      if(lo<0||l<lo) lo=l;
   }
   double live=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(hi<0){ hi=live+InpBucket*20; lo=live-InpBucket*20; }
   double blo=MathFloor(lo/InpBucket)*InpBucket;
   int cnt=(int)MathCeil((hi-blo)/InpBucket)+1;
   if(cnt>InpMaxBuckets){
      blo=MathFloor((live-InpBucket*(InpMaxBuckets/2.0))/InpBucket)*InpBucket;
      cnt=InpMaxBuckets;
   }
   if(cnt<4) cnt=4;
   g_base=blo; g_nb=cnt;
   ArrayResize(g_t3,cnt); ArrayResize(g_u3,cnt); ArrayResize(g_d3,cnt);
   ArrayResize(g_t1,cnt); ArrayResize(g_u1,cnt); ArrayResize(g_d1,cnt);
}

//--- 창 누적 (하루 단위 청크로 부하 분산) --------------------------
bool AccumWindow(const int days, long &tk[], long &up[], long &dn[]){
   ArrayInitialize(tk,0); ArrayInitialize(up,0); ArrayInitialize(dn,0);
   datetime now=TimeCurrent();
   datetime start=now-(datetime)days*86400;
   long total=0;
   for(datetime c=start; c<now; c+=86400){
      datetime ce=c+86400; if(ce>now) ce=now;
      MqlTick t[];
      int g=CopyTicksRange(_Symbol,t,COPY_TICKS_ALL,(ulong)c*1000,(ulong)ce*1000+999);
      if(g<=0) continue;
      double pb=0,pa=0; bool hp=false;   // 직전 bid/ask (틱룰 폴백용)
      for(int i=0;i<g;i++){
         double px=PriceOf(t[i]);
         int idx=(px>0.0)?(int)MathFloor((px-g_base)/InpBucket):-1;
         if(px>0.0 && idx>=0 && idx<g_nb){
            tk[idx]++; total++;
            uint fl=t[i].flags;
            bool cl=false;
            if((fl&TICK_FLAG_BUY)!=0){ up[idx]++; cl=true; }
            else if((fl&TICK_FLAG_SELL)!=0){ dn[idx]++; cl=true; }
            if(!cl && hp){   // 플래그 없으면 틱룰: 체결가가 ask쪽=매수, bid쪽=매도
               double da=MathAbs(px-pa), db=MathAbs(px-pb);
               if(da<db) up[idx]++; else if(db<da) dn[idx]++;
            }
         }
         if(t[i].bid>0.0){ pb=t[i].bid; hp=true; }
         if(t[i].ask>0.0) pa=t[i].ask;
      }
   }
   return(total>0);
}

//--- JSON ---------------------------------------------------------
double DeltaPct(const long u,const long d){ long s=u+d; return s>0? (double)(u-d)/(double)s*100.0 : 0.0; }
string PerLabel(const int d){ if(d>=7 && d%7==0) return (string)(d/7)+"W"; return (string)d+"D"; }
string MarkOf(const double lo,const double hi,const double live,const double o,const double h,const double l){
   if(lo<=live && live<hi) return "LIVE";
   if(lo<=h && h<hi)       return "HIGH";
   if(lo<=l && l<hi)       return "LOW";
   if(lo<=o && o<hi)       return "OPEN";
   return "";
}
//--- 봉별 밀도(분당): 소모틱 ÷ 순이동($) ÷ 봉길이(분) = "$1 이동에 든 틱/분" (TF 무관 비교) --
string TFStr(const ENUM_TIMEFRAMES tf){
   switch(tf){
      case PERIOD_M1: return "M1";  case PERIOD_M5: return "M5";  case PERIOD_M15: return "M15";
      case PERIOD_M30:return "M30"; case PERIOD_H1: return "H1";  case PERIOD_H4:  return "H4";
      case PERIOD_D1: return "D1";  case PERIOD_W1: return "W1";  case PERIOD_MN1: return "MN";
   }
   return "TF";
}
double BarRawDens(const datetime bt,const datetime et,const double o,const double c,long &tk){
   MqlTick t[]; tk=0;
   int g=CopyTicksRange(_Symbol,t,COPY_TICKS_ALL,(ulong)bt*1000,(ulong)et*1000+999);
   long cnt=0;
   if(g>0) for(int i=0;i<g;i++){ if(PriceOf(t[i])>0.0) cnt++; }
   tk=cnt;
   double net=MathAbs(c-o);
   double denom=MathMax(net,InpBucket*0.1);   // 순이동 0 근처(도지=흡수)면 바닥값 클램프
   return (cnt>0)?(double)cnt/denom:0.0;       // 틱 / $1 (분당 정규화 전)
}
double CompletedDensity(const ENUM_TIMEFRAMES tf,const int slot,long &tk,double &net,int &dir){
   datetime bt=iTime(_Symbol,tf,1);            // 직전(완료) 봉
   if(bt!=g_cBarT[slot]){
      double o=iOpen(_Symbol,tf,1), c=iClose(_Symbol,tf,1);
      long t; double raw=BarRawDens(bt,bt+(datetime)PeriodSeconds(tf),o,c,t);
      double mins=PeriodSeconds(tf)/60.0; if(mins<1.0)mins=1.0;
      g_cBarT[slot]=bt; g_cDens[slot]=raw/mins; g_cTk[slot]=t; g_cNet[slot]=MathAbs(c-o); g_cDir[slot]=(c>o)?1:(c<o?-1:0);
   }
   tk=g_cTk[slot]; net=g_cNet[slot]; dir=g_cDir[slot];
   return g_cDens[slot];                        // 틱/$·분
}
double FormingDensity(const ENUM_TIMEFRAMES tf,const int slot,const double bid,long &tk,double &net,int &dir){
   datetime bt=iTime(_Symbol,tf,0);            // 현재(진행) 봉
   if(bt!=g_fBarT[slot]){ g_fBarT[slot]=bt; g_fOpen[slot]=iOpen(_Symbol,tf,0); g_fCnt[slot]=0; g_fLastMs[slot]=(ulong)bt*1000; }
   MqlTick t[];
   int g=CopyTicksRange(_Symbol,t,COPY_TICKS_ALL,g_fLastMs[slot],(ulong)TimeCurrent()*1000+999);
   if(g>0){
      for(int i=0;i<g;i++){ if(PriceOf(t[i])>0.0) g_fCnt[slot]++; }
      g_fLastMs[slot]=(ulong)t[g-1].time_msc+1;   // 다음 전송엔 이 다음 틱부터 (중복 방지)
   }
   double o=g_fOpen[slot];
   net=MathAbs(bid-o);
   dir=(bid>o)?1:(bid<o?-1:0);
   tk=g_fCnt[slot];
   double denom=MathMax(net,InpBucket*0.1);
   double raw=(g_fCnt[slot]>0)?(double)g_fCnt[slot]/denom:0.0;
   double mins=(double)(TimeCurrent()-bt)/60.0; if(mins<0.5)mins=0.5;  // 봉 시작 직후 과대 방지
   return raw/mins;                             // 틱/$·분
}
string DensRow(const string lab,const bool cur,const double d,const double net,const long tk,const int dir,const int dig){
   return "{\"lab\":\""+lab+"\",\"cur\":"+(cur?"true":"false")+",\"d\":"+JNum(d,1)+
          ",\"net\":"+JNum(net,dig)+",\"tk\":"+(string)tk+",\"dir\":"+(string)dir+"}";
}

//--- 브리핑 (수치 → 한국어 시장판단) --------------------------------
string FmtDiff(const double d){ return (d>=0?"+":"")+DoubleToString(d,1); }
void ProfileCtx(double &live,double &poc3,double &poc1,double &upW,double &dnW,double &heavy){
   live=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   int p3=-1,p1=-1; long v3=-1,v1=-1;
   for(int i=0;i<g_nb;i++){ if(g_t3[i]>v3){v3=g_t3[i];p3=i;} if(g_t1[i]>v1){v1=g_t1[i];p1=i;} }
   poc3=(p3>=0)?g_base+(p3+0.5)*InpBucket:0.0;
   poc1=(p1>=0)?g_base+(p1+0.5)*InpBucket:0.0;
   int li=(int)MathFloor((live-g_base)/InpBucket);
   heavy=(li>=0 && li<g_nb && v3>0)?(double)g_t3[li]/(double)v3:0.0;
   upW=0; dnW=0;
   for(int i=0;i<g_nb;i++){
      if(v3>0 && g_t3[i]>=v3*0.5){ double mid=g_base+(i+0.5)*InpBucket;
         if(mid>live+InpBucket*0.5){ if(upW==0||mid<upW) upW=mid; }
         else if(mid<live-InpBucket*0.5){ if(dnW==0||mid>dnW) dnW=mid; } }
   }
}
string ZoneWord(const double heavy){ return heavy>=0.6?"매물대 안(두꺼움)":(heavy>=0.3?"매물대 경계":"진공(얇음)"); }
string DenWord(){ double rat=(g_dvC1>0)?g_dvC0/g_dvC1:1.0; return rat>=1.25?"빡빡":(rat<=0.75?"술술":"보통"); }
string StateSig(){ double lv,p3,p1,uw,dw,hv; ProfileCtx(lv,p3,p1,uw,dw,hv); return ZoneWord(hv)+"|"+DenWord(); }
string BuildBriefing(){
   double live,poc3,poc1,upW,dnW,heavy; ProfileCtx(live,poc3,poc1,upW,dnW,heavy);
   int dig=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   string hm=TimeToString(TimeCurrent()+(datetime)InpServerToKST*3600,TIME_MINUTES);
   string zone=ZoneWord(heavy), den=DenWord();
   string arr=(g_dirC0>0?"▲":(g_dirC0<0?"▼":"·"));
   string judge;
   if(den=="빡빡"){
      if(zone=="진공(얇음)") judge="빈 공간인데 안 나감 = 흡수/이상 → 되돌림 경계, 추격 자제.";
      else                  judge="매물대에서 저항·흡수 중 → 돌파 확인 전 관망. 돌파 시 다음 매물대까지 여지.";
   } else if(den=="술술"){
      if(zone=="진공(얇음)") judge="저항 얇고 잘 나감 → 방향("+arr+") 따라가기 유리. 밀도 식으면 이탈 경계.";
      else                  judge="매물대 소화하며 진행 → 돌파 임박 가능, 방향 확인.";
   } else judge="특이 신호 없음 → 관망.";
   string s="📊 XAUUSD 브리핑 · "+hm+" KST\n";
   s+="현재가 "+JNum(live,dig)+"\n\n";
   s+="① 자리: "+zone+"\n";
   s+=" · POC 3D "+JNum(poc3,dig)+" ("+FmtDiff(poc3-live)+") / 1D "+JNum(poc1,dig)+" ("+FmtDiff(poc1-live)+")\n";
   s+=" · 위매물대 "+(upW>0?JNum(upW,dig)+" ("+FmtDiff(upW-live)+")":"—")
     +" · 아래매물대 "+(dnW>0?JNum(dnW,dig)+" ("+FmtDiff(dnW-live)+")":"—")+"\n\n";
   s+="② 힘(밀도, 틱/$·분): 현재"+TFStr(InpDensTF_C)+" "+JNum(g_dvC0,1)+" vs 직전 "+JNum(g_dvC1,1)+" → "+den+" "+arr+"\n";
   s+=" · 흐름 "+TFStr(InpDensTF_A)+" "+JNum(g_dvA,1)+" → "+TFStr(InpDensTF_B)+" "+JNum(g_dvB,1)
     +" → "+TFStr(InpDensTF_C)+" "+JNum(g_dvC1,1)+" → 현재 "+JNum(g_dvC0,1)+"\n\n";
   s+="③ 판단: "+judge;
   return s;
}

string BuildJson(){
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double o=iOpen(_Symbol,PERIOD_D1,0), h=iHigh(_Symbol,PERIOD_D1,0), l=iLow(_Symbol,PERIOD_D1,0);
   long s3=0,s1=0; for(int i=0;i<g_nb;i++){ s3+=g_t3[i]; s1+=g_t1[i]; }
   string kst=TimeToString(TimeCurrent()+(datetime)InpServerToKST*3600,TIME_DATE|TIME_MINUTES);
   int dig=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   string s="{";
   s+="\"sym\":\""+_Symbol+"\",";
   s+="\"bid\":"+JNum(bid,dig)+",\"ask\":"+JNum(ask,dig)+",";
   s+="\"live\":"+JNum(bid,dig)+",\"bucket\":"+JNum(InpBucket,2)+",";
   s+="\"labA\":\""+PerLabel(InpW3Days)+"\",\"labB\":\""+PerLabel(InpW1Days)+"\",";
   s+="\"kst\":\""+kst+"\",";
   // --- 멀티TF 밀도: 직전 A / 직전 B / 직전 C / 현재 C ---
   long tkx; double nx; int dix;
   double dA =CompletedDensity(InpDensTF_A,0,tkx,nx,dix); string rA =DensRow("직전 "+TFStr(InpDensTF_A),false,dA, nx,tkx,dix,dig);
   double dB =CompletedDensity(InpDensTF_B,1,tkx,nx,dix); string rB =DensRow("직전 "+TFStr(InpDensTF_B),false,dB, nx,tkx,dix,dig);
   double dC1=CompletedDensity(InpDensTF_C,2,tkx,nx,dix); string rC1=DensRow("직전 "+TFStr(InpDensTF_C),false,dC1,nx,tkx,dix,dig);
   double dC0=FormingDensity(InpDensTF_C,0,bid,tkx,nx,dix); string rC0=DensRow("현재 "+TFStr(InpDensTF_C),true, dC0,nx,tkx,dix,dig);
   g_dvA=dA; g_dvB=dB; g_dvC1=dC1; g_dvC0=dC0; g_dirC0=dix; g_netC0=nx;   // 브리핑용 스냅샷
   s+="\"dens\":["+rA+","+rB+","+rC1+","+rC0+"],";
   s+="\"d1\":{\"open\":"+JNum(o,dig)+",\"high\":"+JNum(h,dig)+",\"low\":"+JNum(l,dig)+"},";
   s+="\"sample\":{\"w3\":"+(string)s3+",\"w1\":"+(string)s1+"},";
   s+="\"rows\":[";
   bool first=true;
   for(int idx=g_nb-1; idx>=0; idx--){
      double blo=g_base+idx*InpBucket, bhi=blo+InpBucket;
      double e3=DeltaPct(g_u3[idx],g_d3[idx]);
      double e1=DeltaPct(g_u1[idx],g_d1[idx]);
      string mk=MarkOf(blo,bhi,bid,o,h,l);
      if(!first) s+=",";
      first=false;
      s+="{\"hi\":"+JNum(bhi,dig)+",\"lo\":"+JNum(blo,dig)+",";
      s+="\"t3\":"+(string)g_t3[idx]+",\"e3\":"+JNum(e3,1)+",";
      s+="\"t1\":"+(string)g_t1[idx]+",\"e1\":"+JNum(e1,1)+",";
      s+="\"mark\":"+(mk==""?"null":("\""+mk+"\""))+"}";
   }
   s+="]}";
   return s;
}

//--- 전송 ---------------------------------------------------------
void SendPantry(const string json){
   if(!InpDashEnable || InpDashUrl=="") return;
   char post[]; char res[]; string rh;
   int tot=StringToCharArray(json,post,0,WHOLE_ARRAY,CP_UTF8); if(tot>0) ArrayResize(post,tot-1);
   ResetLastError();
   int r=WebRequest("POST",InpDashUrl,"Content-Type: application/json\r\n",5000,post,res,rh);
   if(r==-1) Print("전송 실패 오류 ",GetLastError()," — getpantry.cloud WebRequest 허용 확인");
   else if(r!=200 && r!=201) Print("응답 ",r,": ",CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8));
}

//--- 텔레그램 -----------------------------------------------------
string JsonEscape(string s){ StringReplace(s,"\\","\\\\"); StringReplace(s,"\"","\\\""); StringReplace(s,"\r",""); StringReplace(s,"\n","\\n"); return(s); }
void SendTelegram(const string text){
   if(!InpTgEnable) return;
   if(InpTgToken=="" || InpTgChatId==""){ Print("텔레그램: 토큰/chat_id 비어있음"); return; }
   string url="https://api.telegram.org/bot"+InpTgToken+"/sendMessage";
   string body="{\"chat_id\":\""+InpTgChatId+"\",\"text\":\""+JsonEscape(text)+"\",\"disable_web_page_preview\":true}";
   char post[]; char res[]; string rh; int tot=StringToCharArray(body,post,0,WHOLE_ARRAY,CP_UTF8); if(tot>0)ArrayResize(post,tot-1);
   ResetLastError();
   int r=WebRequest("POST",url,"Content-Type: application/json\r\n",5000,post,res,rh);
   if(r==-1) Print("텔레그램 실패 오류 ",GetLastError()," — api.telegram.org WebRequest 허용 확인");
   else if(r!=200) Print("텔레그램 응답 ",r,": ",CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8));
}
//--- 브리핑 스케줄 (주기 + 이벤트, 시간대 게이트) ------------------
void MaybeBrief(const datetime now){
   if(!InpTgEnable || !g_ready) return;
   int kh=(int)(((now+(datetime)InpServerToKST*3600)%86400)/3600);
   if(kh<InpBriefStartKST || kh>=InpBriefEndKST) return;   // 브리핑 시간대 밖
   string sig=StateSig();
   bool changed=(sig!=g_lastSig && g_lastSig!="");
   bool evt=(InpBriefEvents && changed && (g_lastBrief==0 || (now-g_lastBrief)>=(datetime)InpEventGapSec));
   bool per=(InpBriefMin>0 && (g_lastBrief==0 || (now-g_lastBrief)>=(datetime)InpBriefMin*60));
   if(evt||per){ SendTelegram(BuildBriefing()); g_lastBrief=now; }
   g_lastSig=sig;
}

//--- MT5 이벤트 ---------------------------------------------------
int OnInit(){
   ComputeRange();
   EventSetTimer(InpSendSec>0?InpSendSec:15);
   Print("프로파일EA v1.08 — 버킷 $",DoubleToString(InpBucket,2),
         " | 밀도 ",TFStr(InpDensTF_A),"/",TFStr(InpDensTF_B),"/",TFStr(InpDensTF_C),
         " | 버킷수 ",g_nb," | 전송 ",(InpDashEnable?"ON":"OFF"),
         " | 브리핑 ",(InpTgEnable?("ON "+(string)InpBriefMin+"분"):"OFF")," | 매매안함");
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){ EventKillTimer(); }
void OnTimer(){
   datetime now=TimeCurrent();
   // 범위는 하루 한 번 정도 갱신 (3W 재계산과 함께)
   bool doW3=(g_lastW3==0 || (now-g_lastW3)>=(datetime)InpW3RefreshSec);
   bool doW1=(g_lastW1==0 || (now-g_lastW1)>=(datetime)InpW1RefreshSec);
   if(doW3){
      // 범위 재계산 → 버킷 인덱스가 바뀌므로 W1도 같은 창으로 재정렬
      ComputeRange();
      AccumWindow(InpW3Days,g_t3,g_u3,g_d3);
      AccumWindow(InpW1Days,g_t1,g_u1,g_d1);
      g_lastW3=now; g_lastW1=now; g_ready=true;
   }
   else if(doW1){ AccumWindow(InpW1Days,g_t1,g_u1,g_d1); g_lastW1=now; }
   if(!g_ready) return;
   if(InpSendSec>0 && (g_lastSend==0 || (now-g_lastSend)>=(datetime)InpSendSec)){
      g_lastSend=now; SendPantry(BuildJson());   // 밀도 스냅샷도 여기서 갱신됨
   }
   MaybeBrief(now);
}
//+------------------------------------------------------------------+
