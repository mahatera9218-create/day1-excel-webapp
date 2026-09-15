//+------------------------------------------------------------------+
//|  프로파일EA.mq5                                                    |
//|  가격대별 틱 프로파일 (3W vs 1W) → 팬트리 → 웹앱                    |
//|                                                                  |
//|  WebRequest 허용 필요: 도구>옵션>전문가 자문                       |
//|     https://getpantry.cloud                                       |
//|  매매하지 않음 (관찰 전용)                                         |
//+------------------------------------------------------------------+
#property copyright "day1"
#property version   "1.01"
#property strict

//--- 입력 ---------------------------------------------------------
input string  InpDashUrl        = "";      // 팬트리 바스켓 URL (프로파일 전용 · 새로 발급)
input bool    InpDashEnable     = true;    // 전송 ON
input double  InpBucket         = 2.0;     // 가격 버킷 크기 ($)
input int     InpW3Days         = 21;      // 장기 창 (일)
input int     InpW1Days         = 7;       // 단기 창 (일)
input int     InpMaxBuckets     = 60;      // 최대 버킷 수 (초과시 현재가 중심 클램프)
input int     InpSendSec        = 15;      // 전송 주기 (초) — 현재가 갱신
input int     InpW1RefreshSec   = 120;     // 1W 재계산 주기 (초)
input int     InpW3RefreshSec   = 600;     // 3W 재계산 주기 (초)
input int     InpServerToKST    = 6;       // 서버→KST 시차 (시간)

//--- 전역 ---------------------------------------------------------
double  g_base = 0.0;
int     g_nb   = 0;
long    g_t3[], g_u3[], g_d3[];   // 3W: 틱수/매수/매도
long    g_t1[], g_u1[], g_d1[];   // 1W
datetime g_lastW3=0, g_lastW1=0, g_lastSend=0;
bool    g_ready=false;

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
string MarkOf(const double lo,const double hi,const double live,const double o,const double h,const double l){
   if(lo<=live && live<hi) return "LIVE";
   if(lo<=h && h<hi)       return "HIGH";
   if(lo<=l && l<hi)       return "LOW";
   if(lo<=o && o<hi)       return "OPEN";
   return "";
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
   s+="\"kst\":\""+kst+"\",";
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
   Print("프로파일EA v1.01 — 버킷 $",DoubleToString(InpBucket,2),
         " | 3W ",InpW3Days,"d/",InpW3RefreshSec,"s · 1W ",InpW1Days,"d/",InpW1RefreshSec,"s",
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
