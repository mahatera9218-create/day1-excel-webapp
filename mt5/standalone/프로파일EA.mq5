//+------------------------------------------------------------------+
//|  프로파일EA.mq5                                                    |
//|  가격대별 틱 프로파일 (3W vs 1W) → 팬트리 → 웹앱                    |
//|                                                                  |
//|  WebRequest 허용 필요: 도구>옵션>전문가 자문                       |
//|     https://getpantry.cloud                                       |
//|  매매하지 않음 (관찰 전용)                                         |
//+------------------------------------------------------------------+
#property copyright "day1"
#property version   "1.06"
#property strict

//--- 입력 ---------------------------------------------------------
input string  InpDashUrl        = "";      // 팬트리 바스켓 URL (프로파일 전용 · 새로 발급)
input bool    InpDashEnable     = true;    // 전송 ON
input double  InpBucket         = 2.0;     // 가격 버킷 크기 ($)
input int     InpW3Days         = 7;       // 장기 창 (일) — 예:7=1W
input int     InpW1Days         = 1;       // 단기 창 (일) — 예:1=1D
input int     InpMaxBuckets     = 60;      // 최대 버킷 수 (초과시 현재가 중심 클램프)
input int     InpSendSec        = 15;      // 전송 주기 (초) — 현재가 갱신
input int     InpW1RefreshSec   = 120;     // 1W 재계산 주기 (초)
input int     InpW3RefreshSec   = 600;     // 3W 재계산 주기 (초)
input int     InpServerToKST    = 6;       // 서버→KST 시차 (시간)
input ENUM_TIMEFRAMES InpDensTF_A = PERIOD_H4;  // 밀도 상위 TF (직전봉)
input ENUM_TIMEFRAMES InpDensTF_B = PERIOD_H1;  // 밀도 중위 TF (직전+현재)
input ENUM_TIMEFRAMES InpDensTF_C = PERIOD_M15; // 밀도 하위 TF (현재)

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
//--- 봉별 밀도: 그 봉의 소모틱 ÷ 순이동($) = "가격 $1 움직이는 데 든 틱수" -----------
string TFStr(const ENUM_TIMEFRAMES tf){
   switch(tf){
      case PERIOD_M1: return "M1";  case PERIOD_M5: return "M5";  case PERIOD_M15: return "M15";
      case PERIOD_M30:return "M30"; case PERIOD_H1: return "H1";  case PERIOD_H4:  return "H4";
      case PERIOD_D1: return "D1";  case PERIOD_W1: return "W1";  case PERIOD_MN1: return "MN";
   }
   return "TF";
}
double BarDensity(const datetime bt,const datetime et,const double o,const double c,long &tk){
   MqlTick t[]; tk=0;
   int g=CopyTicksRange(_Symbol,t,COPY_TICKS_ALL,(ulong)bt*1000,(ulong)et*1000+999);
   long cnt=0;
   if(g>0) for(int i=0;i<g;i++){ if(PriceOf(t[i])>0.0) cnt++; }
   tk=cnt;
   double net=MathAbs(c-o);
   double denom=MathMax(net,InpBucket*0.1);   // 순이동 0 근처(도지=흡수)면 바닥값 클램프
   return (cnt>0)?(double)cnt/denom:0.0;       // 틱 / $1
}
double CompletedDensity(const ENUM_TIMEFRAMES tf,const int slot,long &tk,double &net,int &dir){
   datetime bt=iTime(_Symbol,tf,1);            // 직전(완료) 봉
   if(bt!=g_cBarT[slot]){
      double o=iOpen(_Symbol,tf,1), c=iClose(_Symbol,tf,1);
      long t; double d=BarDensity(bt,bt+(datetime)PeriodSeconds(tf),o,c,t);
      g_cBarT[slot]=bt; g_cDens[slot]=d; g_cTk[slot]=t; g_cNet[slot]=MathAbs(c-o); g_cDir[slot]=(c>o)?1:(c<o?-1:0);
   }
   tk=g_cTk[slot]; net=g_cNet[slot]; dir=g_cDir[slot];
   return g_cDens[slot];
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
   return (g_fCnt[slot]>0)?(double)g_fCnt[slot]/denom:0.0;
}
string DensRow(const string lab,const bool cur,const double d,const double net,const long tk,const int dir,const int dig){
   return "{\"lab\":\""+lab+"\",\"cur\":"+(cur?"true":"false")+",\"d\":"+JNum(d,1)+
          ",\"net\":"+JNum(net,dig)+",\"tk\":"+(string)tk+",\"dir\":"+(string)dir+"}";
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

//--- MT5 이벤트 ---------------------------------------------------
int OnInit(){
   ComputeRange();
   EventSetTimer(InpSendSec>0?InpSendSec:15);
   Print("프로파일EA v1.06 — 버킷 $",DoubleToString(InpBucket,2),
         " | 3W ",InpW3Days,"d/",InpW3RefreshSec,"s · 1W ",InpW1Days,"d/",InpW1RefreshSec,"s",
         " | 밀도 ",TFStr(InpDensTF_A),"/",TFStr(InpDensTF_B),"/",TFStr(InpDensTF_C),
         " | 버킷수 ",g_nb," | 전송 ",(InpDashEnable?"ON":"OFF")," | 매매안함");
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
      g_lastSend=now; SendPantry(BuildJson());
   }
}
//+------------------------------------------------------------------+
