//+------------------------------------------------------------------+
//|                                            체결터미널.mq5         |
//|   지표 B — 체결 터미널 (CopyTicks, 한 파일 완결판, #include 없음)  |
//|                                                                  |
//|  [1] 최근 4H 체결 역학 요약                                       |
//|  [2] 진입 프레임(기본 M5) 완성봉 vs 진행봉 대조                   |
//|  [3] 자리 프레임(기본 H1) 완성봉 vs 진행봉 대조                   |
//+------------------------------------------------------------------+
#property copyright "Engulf Strategy Indicator Set"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots   0

//--- 입력 --------------------------------------------------------
input ENUM_TIMEFRAMES InpEntryTF = PERIOD_M5;   // 진입 프레임
input ENUM_TIMEFRAMES InpZoneTF  = PERIOD_H1;   // 자리 프레임
input int    InpServerToKST      = 7;           // 서버→KST 시차(시간)
input int    InpRefreshSec       = 5;           // 갱신 주기(초)
input color  InpTextColor        = clrKhaki;
input int    InpFontSize          = 9;
input string InpFontName          = "Consolas";
input int    InpCorner            = 1;          // 0좌상 1우상 2좌하 3우하
input int    InpX                 = 10;
input int    InpY                 = 18;

string g_prefix = "EXT_";
int    g_lineH  = 14;
bool   g_useFlag = true;

//==================================================================//
//  공용 함수                                                        //
//==================================================================//
double OnePip(){ return((_Digits==5 || _Digits==3)? _Point*10.0 : _Point); }
double ToPips(const double d){ double p=OnePip(); return(p>0.0? d/p : 0.0); }
double DirStrength(const double open, const double high, const double low,
                   const double close, const bool keepSign=true, const bool asPercent=true)
{
   double range=high-low;
   if(range<=0.0) return(0.0);
   double body=close-open;
   if(!keepSign) body=MathAbs(body);
   double v=body/range;
   return(asPercent? v*100.0 : v);
}
double ElapsedRatio(const datetime barOpen, const datetime now, const int periodSec)
{
   if(periodSec<=0) return(0.0);
   double r=(double)(now-barOpen)/(double)periodSec;
   if(r<0.0)r=0.0; if(r>1.0)r=1.0;
   return(r);
}
datetime ToKST(const datetime t, const int h){ return(t+(datetime)h*3600); }
int MinuteOfDay(const datetime kst){ MqlDateTime t; TimeToStruct(kst,t); return(t.hour*60+t.min); }

enum ENUM_SESSION { SESSION_NONE=0, SESSION_ASIA, SESSION_LONDON, SESSION_TRANSIT, SESSION_NY1, SESSION_NY2 };
string SessionName(const ENUM_SESSION s)
{
   switch(s)
   {
      case SESSION_ASIA:    return("아시아");
      case SESSION_LONDON:  return("런던전반");
      case SESSION_TRANSIT: return("전환");
      case SESSION_NY1:     return("뉴욕전반");
      case SESSION_NY2:     return("뉴욕후반");
      default:              return("휴장/대기");
   }
}
ENUM_SESSION SessionOfMinute(const int m)
{
   if(m>=540 && m<960)   return(SESSION_ASIA);
   if(m>=960 && m<1140)  return(SESSION_LONDON);
   if(m>=1140 && m<1290) return(SESSION_TRANSIT);
   if(m>=1290 || m<30)   return(SESSION_NY1);
   if(m>=30 && m<360)    return(SESSION_NY2);
   return(SESSION_NONE);
}
ENUM_SESSION CurrentSession(){ return(SessionOfMinute(MinuteOfDay(ToKST(TimeCurrent(),InpServerToKST)))); }
double CurrentPrice()
{
   MqlTick t;
   if(SymbolInfoTick(_Symbol,t)) return((t.bid+t.ask)/2.0);
   return(iClose(_Symbol,PERIOD_M1,0));
}
double OpenAtTime(const datetime serverTime)
{
   int shift=iBarShift(_Symbol,PERIOD_M1,serverTime,false);
   if(shift<0) return(0.0);
   return(iOpen(_Symbol,PERIOD_M1,shift));
}
string SignStr(const double v, const int digits=1)
{
   string s=DoubleToString(v,digits);
   if(v>0.0) s="+"+s;
   return(s);
}
string TfName(const ENUM_TIMEFRAMES tf)
{
   string s=EnumToString(tf);
   if(StringFind(s,"PERIOD_")==0) s=StringSubstr(s,7);
   return(s);
}

//==================================================================//
//  틱 집계                                                          //
//==================================================================//
struct TickStats
{
   long total, up, down, distort;
   bool valid;
   void Reset(){ total=0; up=0; down=0; distort=0; valid=false; }
   double Dominance() const { return(total>0? (double)(up-down)/(double)total*100.0 : 0.0); }
};
bool AggregateTicks(const datetime from, const datetime to, TickStats &out, const bool useFlag)
{
   out.Reset();
   if(to<from) return(false);
   MqlTick ticks[];
   int got=CopyTicksRange(_Symbol,ticks,COPY_TICKS_ALL,(ulong)from*1000,(ulong)to*1000+999);
   if(got<=0) return(false);
   double prevBid=0, prevAsk=0; bool havePrev=false;
   for(int i=0;i<got;i++)
   {
      out.total++;
      uint fl=ticks[i].flags;
      bool bidUpd=(fl&TICK_FLAG_BID)!=0, askUpd=(fl&TICK_FLAG_ASK)!=0;
      if(bidUpd!=askUpd) out.distort++;
      bool counted=false;
      if(useFlag)
      {
         if((fl&TICK_FLAG_BUY)!=0){ out.up++; counted=true; }
         if((fl&TICK_FLAG_SELL)!=0){ out.down++; counted=true; }
      }
      if(!counted)
      {
         double last=ticks[i].last;
         if(last<=0.0) last=(ticks[i].bid+ticks[i].ask)/2.0;
         if(havePrev)
         {
            double dAsk=MathAbs(last-prevAsk), dBid=MathAbs(last-prevBid);
            if(dAsk<dBid) out.up++; else if(dBid<dAsk) out.down++;
         }
      }
      if(ticks[i].bid>0.0){ prevBid=ticks[i].bid; havePrev=true; }
      if(ticks[i].ask>0.0){ prevAsk=ticks[i].ask; }
   }
   out.valid=true;
   return(true);
}
bool BrokerProvidesTradeFlags()
{
   MqlTick ticks[];
   int got=CopyTicks(_Symbol,ticks,COPY_TICKS_ALL,0,500);
   if(got<=0) return(false);
   for(int i=0;i<got;i++)
      if((ticks[i].flags&(TICK_FLAG_BUY|TICK_FLAG_SELL))!=0) return(true);
   return(false);
}
bool AggregateBarTicks(const ENUM_TIMEFRAMES tf, const int shift, TickStats &out, const bool useFlag)
{
   datetime openT=iTime(_Symbol,tf,shift);
   if(openT==0) return(false);
   datetime closeT=(shift<=0)? TimeCurrent() : iTime(_Symbol,tf,shift-1);
   if(closeT<=openT) closeT=openT+PeriodSeconds(tf);
   return(AggregateTicks(openT, closeT-1, out, useFlag));
}

//==================================================================//
//  MT5 이벤트                                                       //
//==================================================================//
int OnInit()
{
   g_lineH=InpFontSize+5;
   g_useFlag=BrokerProvidesTradeFlags();
   EventSetTimer((int)MathMax(1,InpRefreshSec));
   Redraw();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){ EventKillTimer(); ObjectsDeleteAll(0,g_prefix); }
void OnTimer(){ Redraw(); }
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   return(rates_total);
}

//==================================================================//
void Redraw()
{
   string L[]; int n=0;
   datetime kstNow=ToKST(TimeCurrent(),InpServerToKST);
   ENUM_SESSION sess=CurrentSession();

   Push(L,n,"┌────────────────────────────────────────┐");
   Push(L,n,StringFormat("│ 체결 터미널 │ %-8s   %s KST",
             _Symbol, TimeToString(kstNow,TIME_MINUTES)));
   Push(L,n,StringFormat("│ 세션: %-8s  체결flag %s",
             SessionName(sess), (g_useFlag?"제공O":"추정")));
   Push(L,n,"├────────────────────────────────────────┤");

   Build4HSummary(L,n);
   Push(L,n,"├────────────────────────────────────────┤");
   BuildFrameBlock(L,n,"[2] "+TfName(InpEntryTF)+" 실시간 (진입)", InpEntryTF);
   Push(L,n,"├────────────────────────────────────────┤");
   BuildFrameBlock(L,n,"[3] "+TfName(InpZoneTF)+" 상세 대조 (자리)", InpZoneTF);

   Push(L,n,"└────────────────────────────────────────┘");
   RenderLabels(L,n);
}

void Build4HSummary(string &L[], int &n)
{
   Push(L,n,"│ [1] 최근 4H 체결 역학 요약");
   datetime to=TimeCurrent(), from=to-4*3600;
   TickStats st;
   bool ok=AggregateTicks(from,to,st,g_useFlag);
   double dom=st.Dominance();
   string side=(dom>0?"매수":(dom<0?"매도":"중립"));
   double open4h=OpenAtTime(from), price=CurrentPrice();
   double net=ToPips(price-open4h);
   int hh=iHighest(_Symbol,PERIOD_M5,MODE_HIGH,48,0);
   int ll=iLowest(_Symbol,PERIOD_M5,MODE_LOW,48,0);
   double hi=(hh>=0)?iHigh(_Symbol,PERIOD_M5,hh):0;
   double lo=(ll>=0)?iLow(_Symbol,PERIOD_M5,ll):0;
   double span=ToPips(hi-lo);
   if(!ok)
      Push(L,n,"│   (틱 데이터 없음 — 브로커 보관량 확인)");
   else
   {
      Push(L,n,StringFormat("│   4H 누적틱: %d ticks (왜곡 %d)",(int)st.total,(int)st.distort));
      Push(L,n,StringFormat("│   순 방향성: %s%% %s 우위 (↑%d/↓%d)",
                SignStr(dom,1),side,(int)st.up,(int)st.down));
   }
   Push(L,n,StringFormat("│   4H 순이동: %s핍 │ 고저폭: %s핍",
             SignStr(net,1), DoubleToString(span,1)));
}

void BuildFrameBlock(string &L[], int &n, const string title, const ENUM_TIMEFRAMES tf)
{
   Push(L,n,"│ "+title);
   Push(L,n,"│  ┌ 직전 완성봉 (-1)");
   BuildBarLines(L,n,tf,1,false);
   Push(L,n,"│  └ 현재 진행봉 (Ongoing)");
   BuildBarLines(L,n,tf,0,true);
}

void BuildBarLines(string &L[], int &n, const ENUM_TIMEFRAMES tf, const int shift, const bool ongoing)
{
   double o=iOpen(_Symbol,tf,shift), h=iHigh(_Symbol,tf,shift), l=iLow(_Symbol,tf,shift);
   double c=(shift==0)? CurrentPrice() : iClose(_Symbol,tf,shift);
   if(o<=0.0){ Push(L,n,"│     (데이터 준비중)"); return; }
   double move=ToPips(c-o), swing=ToPips(h-l);
   double eff=DirStrength(o,h,l,c,false,false);
   TickStats st; AggregateBarTicks(tf,shift,st,g_useFlag);
   double dom=st.Dominance();
   double perTick=(st.total>0)? move/(double)st.total : 0.0;
   if(ongoing)
   {
      datetime bt=iTime(_Symbol,tf,0);
      double el=ElapsedRatio(bt,TimeCurrent(),PeriodSeconds(tf));
      int esec=(int)(TimeCurrent()-bt);
      Push(L,n,StringFormat("│     경과 %dm%ds/%dm (%s%%)",
                esec/60,esec%60,PeriodSeconds(tf)/60,DoubleToString(el*100,0)));
   }
   Push(L,n,StringFormat("│     총틱 %d (왜곡 %d)",(int)st.total,(int)st.distort));
   Push(L,n,StringFormat("│     방향성 %s%% (↑%d/↓%d)",SignStr(dom,1),(int)st.up,(int)st.down));
   Push(L,n,StringFormat("│     실이동 %s (흔들림 %s │ 효율 %s)",
             SignStr(move,1),DoubleToString(swing,1),DoubleToString(eff,2)));
   Push(L,n,StringFormat("│     틱당 실이동 %s/tick",SignStr(perTick,3)));
}

void Push(string &arr[], int &n, const string s){ ArrayResize(arr,n+1); arr[n]=s; n++; }
void RenderLabels(string &L[], const int n)
{
   for(int i=0;i<n;i++)
   {
      string name=g_prefix+IntegerToString(i);
      if(ObjectFind(0,name)<0)
      {
         ObjectCreate(0,name,OBJ_LABEL,0,0,0);
         ObjectSetInteger(0,name,OBJPROP_CORNER,InpCorner);
         ObjectSetInteger(0,name,OBJPROP_XDISTANCE,InpX);
         ObjectSetInteger(0,name,OBJPROP_FONTSIZE,InpFontSize);
         ObjectSetString(0,name,OBJPROP_FONT,InpFontName);
         ObjectSetInteger(0,name,OBJPROP_COLOR,InpTextColor);
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,name,OBJPROP_BACK,false);
         ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      }
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,InpY+i*g_lineH);
      ObjectSetString(0,name,OBJPROP_TEXT,L[i]);
   }
   int idx=n;
   while(ObjectFind(0,g_prefix+IntegerToString(idx))>=0)
   {
      ObjectDelete(0,g_prefix+IntegerToString(idx));
      idx++;
   }
   ChartRedraw();
}
//+------------------------------------------------------------------+
