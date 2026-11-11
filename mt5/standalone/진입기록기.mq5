//+------------------------------------------------------------------+
//|                                            진입기록기.mq5         |
//|   지표 C — 진입 스냅샷 자동 기록기 ★핵심 (EA, 한 파일 완결판)     |
//|                                                                  |
//|  ※ 이 EA 는 매매를 하지 않는다. 기록만 한다.                      |
//|  포지션이 열리는 순간(OnTradeTransaction) 모든 수치를 스냅샷 →    |
//|   trade_log.csv 한 줄. 청산되면 결과(승패/손익/R) 같은 행에 자동. |
//|  감정(emotion)만 사용자가 수동 기입.                             |
//+------------------------------------------------------------------+
#property copyright "Engulf Strategy Indicator Set"
#property version   "1.00"
#property strict

//--- 입력 --------------------------------------------------------
input int    InpServerToKST = 7;                 // 서버→KST 시차(시간)
input string InpCsvFile     = "trade_log.csv";   // 기록 파일
input int    InpSessDays    = 5;
input int    InpWeekWeeks   = 4;
input bool   InpDemoTag     = true;

#define COL_COUNT 34

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
double ReachPercent(const double price, const double baseOpen, const double level)
{
   double denom=level-baseOpen;
   if(MathAbs(denom)<_Point) return(0.0);
   return((price-baseOpen)/denom*100.0);
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
string PhaseStr(const double a, const double avg){ return(a>avg?"추세":"횡보"); }
string AccountTag()
{
   if(!InpDemoTag) return("");
   ENUM_ACCOUNT_TRADE_MODE m=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   switch(m){ case ACCOUNT_TRADE_MODE_DEMO:return("DEMO");
              case ACCOUNT_TRADE_MODE_CONTEST:return("CONTEST");
              default:return("REAL"); }
}

//==================================================================//
//  기간 평균                                                        //
//==================================================================//
double AvgDirStrengthAbs(const ENUM_TIMEFRAMES tf, const int count, const int startShift=1)
{
   double sum=0; int used=0;
   for(int i=0;i<count;i++)
   {
      int sh=startShift+i;
      double o=iOpen(_Symbol,tf,sh),h=iHigh(_Symbol,tf,sh),l=iLow(_Symbol,tf,sh),c=iClose(_Symbol,tf,sh);
      if(o==0.0) break;
      sum+=MathAbs(DirStrength(o,h,l,c,true,true)); used++;
   }
   return(used>0? sum/used : 0.0);
}
double AvgRange(const ENUM_TIMEFRAMES tf, const int count, const int startShift=1)
{
   double sum=0; int used=0;
   for(int i=0;i<count;i++)
   {
      int sh=startShift+i;
      double h=iHigh(_Symbol,tf,sh), l=iLow(_Symbol,tf,sh);
      if(h==0.0) break;
      sum+=(h-l); used++;
   }
   return(used>0? sum/used : 0.0);
}
double AvgTickVolume(const ENUM_TIMEFRAMES tf, const int count, const int startShift=1)
{
   long sum=0; int used=0;
   for(int i=0;i<count;i++)
   {
      int sh=startShift+i;
      if(iTime(_Symbol,tf,sh)==0) break;
      sum+=iVolume(_Symbol,tf,sh); used++;
   }
   return(used>0? (double)sum/used : 0.0);
}
double TickVolPct(const ENUM_TIMEFRAMES tf, const int avgN)
{
   long cur=iVolume(_Symbol,tf,0);
   double avg=AvgTickVolume(tf,avgN,1);
   return((avg>0)? (double)cur/avg*100.0 : 0.0);
}
double RangePosPct()
{
   int hh=iHighest(_Symbol,PERIOD_H1,MODE_HIGH,120,0);
   int ll=iLowest(_Symbol,PERIOD_H1,MODE_LOW,120,0);
   if(hh<0||ll<0) return(0.0);
   double h=iHigh(_Symbol,PERIOD_H1,hh), l=iLow(_Symbol,PERIOD_H1,ll), p=CurrentPrice();
   return((h>l)?(p-l)/(h-l)*100.0:0.0);
}
double NearestLevelPips(const double price)
{
   double lv[6]; int c=0;
   lv[c++]=iHigh(_Symbol,PERIOD_D1,1); lv[c++]=iLow(_Symbol,PERIOD_D1,1);
   lv[c++]=iHigh(_Symbol,PERIOD_W1,1); lv[c++]=iLow(_Symbol,PERIOD_W1,1);
   lv[c++]=iOpen(_Symbol,PERIOD_D1,0); lv[c++]=iOpen(_Symbol,PERIOD_W1,0);
   double best=DBL_MAX;
   for(int i=0;i<c;i++){ if(lv[i]<=0)continue; double d=MathAbs(ToPips(price-lv[i])); if(d<best)best=d; }
   return(best==DBL_MAX?999.0:best);
}
double GetRSI(const ENUM_TIMEFRAMES tf, const int period, const int shift)
{
   int h=iRSI(_Symbol,tf,period,PRICE_CLOSE);
   if(h==INVALID_HANDLE) return(0.0);
   double buf[];
   if(CopyBuffer(h,0,shift,1,buf)<=0){ IndicatorRelease(h); return(0.0); }
   double v=buf[0]; IndicatorRelease(h); return(v);
}

//==================================================================//
//  틱 집계 (체결 우위)                                              //
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
//  인걸핑 감지 + 품질 점수                                          //
//==================================================================//
enum ENUM_ENGULF_DIR { ENGULF_NONE=0, ENGULF_BULL=+1, ENGULF_BEAR=-1 };
struct EngulfResult
{
   ENUM_ENGULF_DIR dir;
   int    legs;
   double zoneOpen, zoneClose, engHigh, engLow;
   datetime time;
   void Reset(){ dir=ENGULF_NONE; legs=0; zoneOpen=zoneClose=engHigh=engLow=0.0; time=0; }
};
bool DetectEngulf(const ENUM_TIMEFRAMES tf, const int checkShift, EngulfResult &r, const int maxLegs)
{
   r.Reset();
   double cO=iOpen(_Symbol,tf,checkShift), cC=iClose(_Symbol,tf,checkShift);
   double cH=iHigh(_Symbol,tf,checkShift), cL=iLow(_Symbol,tf,checkShift);
   if(cO==0.0 || cC==0.0) return(false);
   int curDir=(cC>cO)?+1:(cC<cO?-1:0);
   if(curDir==0) return(false);
   double curTop=MathMax(cO,cC), curBot=MathMin(cO,cC);
   double pTop=-DBL_MAX, pBot=DBL_MAX, pHi=-DBL_MAX, pLo=DBL_MAX;
   for(int leg=1; leg<=maxLegs; leg++)
   {
      int sh=checkShift+leg;
      double pO=iOpen(_Symbol,tf,sh), pC=iClose(_Symbol,tf,sh);
      double pH=iHigh(_Symbol,tf,sh), pL=iLow(_Symbol,tf,sh);
      if(pO==0.0) break;
      int pDir=(pC>pO)?+1:(pC<pO?-1:0);
      if(leg>1 && pDir==curDir) break;
      pTop=MathMax(pTop,MathMax(pO,pC)); pBot=MathMin(pBot,MathMin(pO,pC));
      pHi=MathMax(pHi,pH); pLo=MathMin(pLo,pL);
      if(!(curTop>=pTop && curBot<=pBot)) continue;
      bool wickOK=(curDir>0)? (cH>=pHi) : (cL<=pLo);
      if(!wickOK) continue;
      r.dir=(curDir>0)?ENGULF_BULL:ENGULF_BEAR;
      r.legs=leg; r.zoneOpen=cO; r.zoneClose=cC; r.engHigh=cH; r.engLow=cL;
      r.time=iTime(_Symbol,tf,checkShift);
      return(true);
   }
   return(false);
}
struct QualityScore { double engulfRatio, candleStrength, levelProx, htfAlign, flowAlign, rsi, score; };
double Clamp01(double v){ if(v<0)v=0; if(v>1)v=1; return(v); }
double NormRatio(const double x){ return(Clamp01((x-1.0)/1.0)); }
double NormLevelProx(const double pips){ return(Clamp01((50.0-MathAbs(pips))/45.0)); }
double NormAlign(const double a){ return(Clamp01((a+1.0)/2.0)); }
QualityScore ComputeQuality(const EngulfResult &r, const double prevBody,
                            const double htfSame, const double flowSame,
                            const double levelPips, const double rsi, const double &w[])
{
   QualityScore q; q.rsi=rsi;
   double curBody=MathAbs(r.zoneClose-r.zoneOpen);
   q.engulfRatio=(prevBody>0.0)? curBody/prevBody : 1.0;
   q.candleStrength=DirStrength(r.zoneOpen,r.engHigh,r.engLow,r.zoneClose,false,false);
   q.levelProx=levelPips;
   q.htfAlign=(htfSame>0?+1.0:(htfSame<0?-1.0:0.0));
   q.flowAlign=flowSame;
   double n1=NormRatio(q.engulfRatio), n2=Clamp01(q.candleStrength),
          n3=NormLevelProx(q.levelProx), n4=NormAlign(q.htfAlign), n5=NormAlign(q.flowAlign);
   double ww[5], sum=0; int nn=ArraySize(w);
   for(int i=0;i<5;i++){ ww[i]=(i<nn)?w[i]:0.0; sum+=ww[i]; }
   if(sum<=0.0){ for(int i=0;i<5;i++) ww[i]=1.0; sum=5.0; }
   q.score=(n1*ww[0]+n2*ww[1]+n3*ww[2]+n4*ww[3]+n5*ww[4])/sum*100.0;
   return(q);
}

//==================================================================//
//  MT5 이벤트                                                       //
//==================================================================//
int OnInit()
{
   EnsureHeader();
   Print("진입기록기 시작 — 파일: ", InpCsvFile, "  (진입/청산 자동 기록, 매매 안 함)");
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason) {}
void OnTick() {}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong dealTicket=trans.deal;
   if(!HistoryDealSelect(dealTicket)) return;
   long entry=HistoryDealGetInteger(dealTicket,DEAL_ENTRY);
   long posId=HistoryDealGetInteger(dealTicket,DEAL_POSITION_ID);
   string sym=HistoryDealGetString(dealTicket,DEAL_SYMBOL);
   if(sym!=_Symbol) return;
   if(entry==DEAL_ENTRY_IN)
      OnPositionOpen(dealTicket,posId);
   else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY || entry==DEAL_ENTRY_INOUT)
      OnPositionClose(dealTicket,posId);
}

//------------------------------------------------------------------//
void OnPositionOpen(const ulong dealTicket, const long posId)
{
   double price=HistoryDealGetDouble(dealTicket,DEAL_PRICE);
   double lots=HistoryDealGetDouble(dealTicket,DEAL_VOLUME);
   long dtype=HistoryDealGetInteger(dealTicket,DEAL_TYPE);
   datetime dtime=(datetime)HistoryDealGetInteger(dealTicket,DEAL_TIME);
   string dir=(dtype==DEAL_TYPE_BUY)?"롱":"숏";

   double sl=0, tp=0;
   if(PositionSelectByTicket(posId))
   {
      sl=PositionGetDouble(POSITION_SL);
      tp=PositionGetDouble(POSITION_TP);
   }

   double h4dir=DirStrength(iOpen(_Symbol,PERIOD_H4,1),iHigh(_Symbol,PERIOD_H4,1),
                            iLow(_Symbol,PERIOD_H4,1),iClose(_Symbol,PERIOD_H4,1),true,true);
   double h4avg=AvgDirStrengthAbs(PERIOD_H4,30,1);
   string h4phase=PhaseStr(MathAbs(h4dir),h4avg);

   double dOpen=iOpen(_Symbol,PERIOD_D1,0);
   double dDir=DirStrength(dOpen,iHigh(_Symbol,PERIOD_D1,0),iLow(_Symbol,PERIOD_D1,0),price,true,true);
   double dAvg=AvgDirStrengthAbs(PERIOD_D1,InpSessDays,1);
   double wOpen=iOpen(_Symbol,PERIOD_W1,0);
   double wDir=DirStrength(wOpen,iHigh(_Symbol,PERIOD_W1,0),iLow(_Symbol,PERIOD_W1,0),price,true,true);
   double wAvg=AvgDirStrengthAbs(PERIOD_W1,InpWeekWeeks,1);

   double dR=AvgRange(PERIOD_D1,InpSessDays,1);
   double dReach=(dR>0)? ReachPercent(price,dOpen, dOpen+(price>=dOpen? dR : -dR)) : 0;
   double dRoom =(dR>0)? ToPips((dOpen+(price>=dOpen? dR : -dR))-price) : 0;

   double posPct=RangePosPct();
   double wkChg=ToPips(price-wOpen);
   double dTv=TickVolPct(PERIOD_D1,InpSessDays);
   double wTv=TickVolPct(PERIOD_W1,InpWeekWeeks);
   ENUM_SESSION sess=CurrentSession();

   EngulfResult er; string engId=""; double score=0,qr=0,qc=0,qlv=0,qhtf=0; double rsi=0;
   if(DetectEngulf(PERIOD_H1,1,er,3))
   {
      double prevBody=MathAbs(iClose(_Symbol,PERIOD_H1,2)-iOpen(_Symbol,PERIOD_H1,2));
      double htfSame=(h4dir*(double)er.dir>0)?+1:(h4dir*(double)er.dir<0?-1:0);
      double lvpip=NearestLevelPips((er.zoneOpen+er.zoneClose)/2.0);
      rsi=GetRSI(PERIOD_H1,14,1);
      double w[5]; ArrayInitialize(w,0);
      QualityScore q=ComputeQuality(er,prevBody,htfSame,0,lvpip,rsi,w);
      score=q.score; qr=q.engulfRatio; qc=q.candleStrength; qlv=q.levelProx; qhtf=q.htfAlign;
      MqlDateTime et; TimeToStruct(ToKST(er.time,InpServerToKST),et);
      engId=StringFormat("%s-%04d%02d%02d-%02d%02d",_Symbol,et.year,et.mon,et.day,et.hour,et.min);
   }

   bool useFlag=BrokerProvidesTradeFlags();
   TickStats ts; AggregateBarTicks(PERIOD_H1,0,ts,useFlag);
   double dom=ts.valid? ts.Dominance() : 0;

   datetime kst=ToKST(dtime,InpServerToKST);
   string row[COL_COUNT]; int i=0;
   row[i++]=IntegerToString(posId);
   row[i++]=TimeToString(kst,TIME_DATE|TIME_MINUTES);
   row[i++]=_Symbol;
   row[i++]=dir;
   row[i++]=DoubleToString(price,_Digits);
   row[i++]=DoubleToString(lots,2);
   row[i++]=DoubleToString(sl,_Digits);
   row[i++]=DoubleToString(tp,_Digits);
   row[i++]=DoubleToString(h4dir,1);
   row[i++]=DoubleToString(h4avg,0);
   row[i++]=h4phase;
   row[i++]=DoubleToString(dDir,1);
   row[i++]=DoubleToString(dAvg,0);
   row[i++]=DoubleToString(wDir,1);
   row[i++]=DoubleToString(wAvg,0);
   row[i++]=DoubleToString(dReach,0);
   row[i++]=DoubleToString(dRoom,0);
   row[i++]=DoubleToString(posPct,0);
   row[i++]=DoubleToString(wkChg,1);
   row[i++]=DoubleToString(dTv,0);
   row[i++]=DoubleToString(wTv,0);
   row[i++]=SessionName(sess);
   row[i++]=engId;
   row[i++]=DoubleToString(score,1);
   row[i++]=DoubleToString(qr,2);
   row[i++]=DoubleToString(qc,3);
   row[i++]=DoubleToString(qlv,1);
   row[i++]=DoubleToString(qhtf,0);
   row[i++]=DoubleToString(rsi,1);
   row[i++]=ts.valid? DoubleToString(dom,1) : "NA";
   row[i++]=AccountTag();
   row[i++]="";  // result       — 청산 시 자동
   row[i++]="";  // result_detail — 청산 시 자동
   row[i++]="";  // emotion       — 수동

   AppendRow(row, COL_COUNT);
   Print("📸 진입 스냅샷 기록 posId=", posId, " 점수=", DoubleToString(score,1));
}

//------------------------------------------------------------------//
void OnPositionClose(const ulong dealTicket, const long posId)
{
   double closePrice=HistoryDealGetDouble(dealTicket,DEAL_PRICE);
   datetime ctime=(datetime)HistoryDealGetInteger(dealTicket,DEAL_TIME);

   double entryPrice=0; datetime openTime=0; long dir=0; double totalProfit=0;
   if(HistorySelectByPosition(posId))
   {
      int deals=HistoryDealsTotal();
      for(int d=0; d<deals; d++)
      {
         ulong tk=HistoryDealGetTicket(d);
         long e=HistoryDealGetInteger(tk,DEAL_ENTRY);
         totalProfit+=HistoryDealGetDouble(tk,DEAL_PROFIT);
         if(e==DEAL_ENTRY_IN)
         {
            entryPrice=HistoryDealGetDouble(tk,DEAL_PRICE);
            openTime=(datetime)HistoryDealGetInteger(tk,DEAL_TIME);
            dir=HistoryDealGetInteger(tk,DEAL_TYPE);
         }
      }
   }
   double pips=(dir==DEAL_TYPE_BUY)? ToPips(closePrice-entryPrice) : ToPips(entryPrice-closePrice);
   string outcome=(totalProfit>0)?"승":(totalProfit<0?"패":"무");
   int holdMin=(openTime>0)? (int)((ctime-openTime)/60) : 0;
   double rMult=ComputeRMultiple(posId,entryPrice,closePrice,dir);
   datetime kst=ToKST(ctime,InpServerToKST);
   string detail=StringFormat("%s|청산 %s|손익 %.2f(%.1f핍)|보유 %dm|R %.2f",
      outcome, TimeToString(kst,TIME_MINUTES), totalProfit, pips, holdMin, rMult);
   FillResult(posId, outcome, detail);
   Print("🏁 청산 결과 기록 posId=", posId, " ", detail);
}

//==================================================================//
//  CSV 파일 조작                                                    //
//==================================================================//
void EnsureHeader()
{
   if(FileIsExist(InpCsvFile)) return;
   int h=FileOpen(InpCsvFile, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(h==INVALID_HANDLE){ Print("헤더 생성 실패 ",GetLastError()); return; }
   FileWrite(h,
     "position_id","entry_kst","symbol","dir","entry_price","lots","sl","tp",
     "h4_dir","h4_avg","h4_phase","daily_dir","daily_avg","weekly_dir","weekly_avg",
     "daily_reach%","daily_room_pip","pos_pct","wk_chg_pip","daily_tickvol%","weekly_tickvol%",
     "session","engulf_id","q_score","q_ratio","q_candle","q_levelpip","q_htf","rsi",
     "flow_dom","account","result","result_detail","emotion");
   FileClose(h);
}
void AppendRow(string &row[], const int cnt)
{
   int h=FileOpen(InpCsvFile, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE){ Print("append 실패 ",GetLastError()); return; }
   FileSeek(h,0,SEEK_END);
   string line="";
   for(int i=0;i<cnt;i++){ if(i>0) line+=","; line+=CsvEscape(row[i]); }
   FileWriteString(h, line+"\r\n");
   FileClose(h);
}
void FillResult(const long posId, const string outcome, const string detail)
{
   string lines[]; int n=ReadAllLines(lines);
   if(n<=0) return;
   string key=IntegerToString(posId);
   for(int i=1;i<n;i++)
   {
      string parts[];
      int c=SplitCsv(lines[i],parts);
      if(c>0 && parts[0]==key && (c<=31 || parts[31]==""))
      {
         if(c<COL_COUNT){ ArrayResize(parts,COL_COUNT); for(int k=c;k<COL_COUNT;k++) parts[k]=""; }
         parts[31]=outcome;   // result
         parts[32]=detail;    // result_detail (emotion=33 보존)
         lines[i]=JoinCsv(parts,COL_COUNT);
         break;
      }
   }
   WriteAllLines(lines,n);
}
double ComputeRMultiple(const long posId, const double entryPrice, const double closePrice, const long dir)
{
   string lines[]; int n=ReadAllLines(lines);
   double sl=0; string key=IntegerToString(posId);
   for(int i=1;i<n;i++)
   {
      string parts[]; int c=SplitCsv(lines[i],parts);
      if(c>6 && parts[0]==key){ sl=StringToDouble(parts[6]); break; }
   }
   double risk=MathAbs(entryPrice-sl);
   if(risk<=0.0) return(0.0);
   double reward=(dir==DEAL_TYPE_BUY)? (closePrice-entryPrice) : (entryPrice-closePrice);
   return(reward/risk);
}
int ReadAllLines(string &lines[])
{
   int h=FileOpen(InpCsvFile, FILE_READ|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE) return(0);
   int n=0;
   while(!FileIsEnding(h))
   {
      string s=FileReadString(h);
      ArrayResize(lines,n+1); lines[n]=s; n++;
   }
   FileClose(h);
   if(n>0 && StringLen(lines[n-1])==0) n--;
   return(n);
}
void WriteAllLines(string &lines[], const int n)
{
   int h=FileOpen(InpCsvFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE){ Print("재기록 실패 ",GetLastError()); return; }
   for(int i=0;i<n;i++) FileWriteString(h, lines[i]+"\r\n");
   FileClose(h);
}
string CsvEscape(const string s)
{
   if(StringFind(s,",")>=0 || StringFind(s,"\"")>=0 || StringFind(s,"|")>=0)
   {
      string t=s; StringReplace(t,"\"","\"\"");
      return("\""+t+"\"");
   }
   return(s);
}
int SplitCsv(const string line, string &parts[])
{
   int n=0; string cur=""; bool inQ=false;
   int len=StringLen(line);
   for(int i=0;i<len;i++)
   {
      ushort ch=StringGetCharacter(line,i);
      if(ch=='"'){ inQ=!inQ; continue; }
      if(ch==',' && !inQ){ ArrayResize(parts,n+1); parts[n]=cur; n++; cur=""; }
      else cur+=ShortToString(ch);
   }
   ArrayResize(parts,n+1); parts[n]=cur; n++;
   return(n);
}
string JoinCsv(string &parts[], const int cnt)
{
   string s="";
   for(int i=0;i<cnt;i++){ if(i>0)s+=","; s+=CsvEscape(parts[i]); }
   return(s);
}
//+------------------------------------------------------------------+
