//+------------------------------------------------------------------+
//|                                              매매일지EA.mq5       |
//|   포지션 진입/청산 순간의 터미널 값(힘+자리)을 CSV 로 스냅샷 저장 |
//|   조합 #2: 힘(체결·M30전환) + 자리(세션레벨·도달률)              |
//|   ※ 매매는 하지 않음. 체결 이벤트를 감지해 기록만.               |
//|   ※ 저장 위치: 데이터폴더\MQL5\Files\trade_journal.csv           |
//|   ※ getpantry/telegram 불필요. WebRequest 안 씀.                 |
//+------------------------------------------------------------------+
#property copyright "PIPxLOT — Trade Journal"
#property version   "1.00"
#property strict

//--- 입력 --------------------------------------------------------
input string InpCsvFile        = "trade_journal.csv"; // 저장 파일명 (MQL5\Files 안)
input int    InpServerToKST    = 6;     // 서버→KST 시차(시간)
input int    InpSessDays       = 5;     // 세션 평균 일수(자리 계산)
input bool   InpThisSymbolOnly = true;  // 이 차트 심볼만 기록
input long   InpMagic          = -1;    // 기록할 매직넘버(-1=전체, 수동 포함)
input bool   InpAlertOn        = false; // 기록 시 팝업

//--- 단위 --------------------------------------------------------
bool   g_metal=false; double g_ptSize=0.0001; string g_unit="핍";
double OnePip(){ return((_Digits==5 || _Digits==3)? _Point*10.0 : _Point); }
void   InitUnit(){ g_metal=(_Digits<=2); g_ptSize=g_metal?1.0:OnePip(); g_unit=g_metal?"$":"핍"; }
double ToPt(const double d){ return(g_ptSize>0? d/g_ptSize : 0); }
double DirStrength(const double o,const double h,const double l,const double c){ double r=h-l; if(r<=0)return(0); return((c-o)/r*100.0); }
double CurrentPrice(){ MqlTick t; if(SymbolInfoTick(_Symbol,t))return(t.bid); return(iClose(_Symbol,PERIOD_M1,0)); }
datetime ToKST(const datetime t,const int h){ return(t+(datetime)h*3600); }
datetime ToServer(const datetime k,const int h){ return(k-(datetime)h*3600); }
int MinuteOfDay(const datetime k){ MqlDateTime t; TimeToStruct(k,t); return(t.hour*60+t.min); }

//--- 세션 -------------------------------------------------------
enum ENUM_SESSION { SESSION_NONE=0,SESSION_ASIA,SESSION_LONDON,SESSION_TRANSIT,SESSION_NY1,SESSION_NY2 };
string SessionName(const ENUM_SESSION s){ switch(s){case SESSION_ASIA:return("아시아");case SESSION_LONDON:return("런던");
   case SESSION_TRANSIT:return("전환");case SESSION_NY1:return("뉴욕전");case SESSION_NY2:return("뉴욕후");default:return("휴장");} }
ENUM_SESSION SessionOfMinute(const int m){ if(m>=540&&m<960)return(SESSION_ASIA); if(m>=960&&m<1140)return(SESSION_LONDON);
   if(m>=1140&&m<1290)return(SESSION_TRANSIT); if(m>=1290||m<30)return(SESSION_NY1); if(m>=30&&m<360)return(SESSION_NY2); return(SESSION_NONE); }
int SessionStartMinute(const ENUM_SESSION s){ switch(s){case SESSION_ASIA:return(540);case SESSION_LONDON:return(960);case SESSION_TRANSIT:return(1140);case SESSION_NY1:return(1290);case SESSION_NY2:return(30);default:return(360);} }
int SessionEndMinute(const ENUM_SESSION s){ switch(s){case SESSION_ASIA:return(960);case SESSION_LONDON:return(1140);case SESSION_TRANSIT:return(1290);case SESSION_NY1:return(30);case SESSION_NY2:return(360);default:return(540);} }
ENUM_SESSION CurrentSession(){ return(SessionOfMinute(MinuteOfDay(ToKST(TimeCurrent(),InpServerToKST)))); }
ENUM_SESSION CurrentSessionStart(datetime &sessStartServer)
{
   datetime kstNow=ToKST(TimeCurrent(),InpServerToKST); int m=MinuteOfDay(kstNow); ENUM_SESSION s=SessionOfMinute(m);
   MqlDateTime kt; TimeToStruct(kstNow,kt); kt.hour=0;kt.min=0;kt.sec=0;
   datetime kstStart=StructToTime(kt)+(datetime)SessionStartMinute(s)*60;
   if(s==SESSION_NY1 && m<30) kstStart-=86400;
   sessStartServer=ToServer(kstStart,InpServerToKST); return(s);
}

//--- 틱 집계 ----------------------------------------------------
struct TickStats{ long total,up,down; bool valid; void Reset(){total=0;up=0;down=0;valid=false;}
   double Dom() const { return(total>0?(double)(up-down)/(double)total*100.0:0.0); } };
bool AggTicks(const datetime from,const datetime to,TickStats &o,const bool useFlag)
{
   o.Reset(); if(to<from)return(false); MqlTick tk[]; int got=CopyTicksRange(_Symbol,tk,COPY_TICKS_ALL,(ulong)from*1000,(ulong)to*1000+999);
   if(got<=0)return(false); double pb=0,pa=0; bool hp=false;
   for(int i=0;i<got;i++){ o.total++; uint fl=tk[i].flags; bool c=false;
      if(useFlag){ if((fl&TICK_FLAG_BUY)!=0){o.up++;c=true;} if((fl&TICK_FLAG_SELL)!=0){o.down++;c=true;} }
      if(!c){ double l=tk[i].last; if(l<=0)l=(tk[i].bid+tk[i].ask)/2.0; if(hp){ double da=MathAbs(l-pa),db=MathAbs(l-pb); if(da<db)o.up++; else if(db<da)o.down++; } }
      if(tk[i].bid>0){pb=tk[i].bid;hp=true;} if(tk[i].ask>0)pa=tk[i].ask; }
   o.valid=true; return(true);
}
bool UseFlag(){ MqlTick tk[]; int g=CopyTicks(_Symbol,tk,COPY_TICKS_ALL,0,500); if(g<=0)return(false);
   for(int i=0;i<g;i++) if((tk[i].flags&(TICK_FLAG_BUY|TICK_FLAG_SELL))!=0)return(true); return(false); }
double BarDom(const ENUM_TIMEFRAMES tf,const int shift,const bool uf)
{
   datetime ot=iTime(_Symbol,tf,shift); if(ot==0)return(0); datetime ct=(shift<=0)?TimeCurrent():iTime(_Symbol,tf,shift-1);
   if(ct<=ot)ct=ot+PeriodSeconds(tf); TickStats st; AggTicks(ot,ct-1,st,uf); return(st.Dom());
}
double BarMove(const ENUM_TIMEFRAMES tf,const int shift)
{
   double o=iOpen(_Symbol,tf,shift); double c=(shift==0)?CurrentPrice():iClose(_Symbol,tf,shift);
   return(g_metal?(c-o):(c-o)/OnePip());
}

//--- 세션 누적/히스토리 (자리 계산용) ----------------------------
void SessionCurrent(const datetime st,double &op){ op=0; int s0=iBarShift(_Symbol,PERIOD_M5,st,false); if(s0<0)return; op=iOpen(_Symbol,PERIOD_M5,s0); }
void SessionHist(const int sm,const int em,const int days,double &avgUp,double &avgDn)
{
   avgUp=0;avgDn=0; int used=0; if(Bars(_Symbol,PERIOD_M5)<=0)return;
   for(int d=1;d<=days;d++){ double hi=-DBL_MAX,lo=DBL_MAX,op=0; bool any=false;
      datetime kstNow=ToKST(TimeCurrent(),InpServerToKST); MqlDateTime kt; TimeToStruct(kstNow,kt); kt.hour=0;kt.min=0;kt.sec=0;
      datetime mid=StructToTime(kt)-(datetime)d*86400;
      datetime ks=mid+(datetime)sm*60, ke=(em>sm)?mid+(datetime)em*60:mid+86400+(datetime)em*60;
      int shS=iBarShift(_Symbol,PERIOD_M5,ToServer(ks,InpServerToKST),false), shE=iBarShift(_Symbol,PERIOD_M5,ToServer(ke,InpServerToKST),false);
      if(shS<0||shE<0)continue; op=iOpen(_Symbol,PERIOD_M5,shS);
      for(int sh=shS;sh>=shE;sh--){ double h=iHigh(_Symbol,PERIOD_M5,sh),l=iLow(_Symbol,PERIOD_M5,sh); if(h==0)continue; hi=MathMax(hi,h); lo=MathMin(lo,l); any=true; }
      if(any&&hi>lo){ avgUp+=(hi-op); avgDn+=(op-lo); used++; } }
   if(used>0){ avgUp/=used; avgDn/=used; }
}
double RangePosPct(){ int hh=iHighest(_Symbol,PERIOD_H1,MODE_HIGH,120,0),ll=iLowest(_Symbol,PERIOD_H1,MODE_LOW,120,0);
   if(hh<0||ll<0)return(0); double h=iHigh(_Symbol,PERIOD_H1,hh),l=iLow(_Symbol,PERIOD_H1,ll),p=CurrentPrice(); return((h>l)?(p-l)/(h-l)*100.0:0); }

//--- CSV 헤더 ---------------------------------------------------
void EnsureHeader()
{
   if(FileIsExist(InpCsvFile))return;
   int h=FileOpen(InpCsvFile,FILE_WRITE|FILE_CSV|FILE_ANSI,','); if(h==INVALID_HANDLE){Print("CSV 헤더 실패 ",GetLastError());return;}
   FileWrite(h,"time_kst","event","ticket","symbol","dir","volume","price","sl","tp","profit",
      "f_dom4h","f_net4h","f_h1done_dom","f_h1now_dom","f_m30done_dom","f_m30now_dom","f_m30flip",
      "z_reach","z_gapup_pt","z_gapdn_pt","z_h1pos","session");
   FileClose(h);
}

//--- 스냅샷 기록 -------------------------------------------------
void LogSnapshot(const string event,const ulong ticket,const string sym,const bool isBuy,
                 const double vol,const double price,const double sl,const double tp,const double profit)
{
   InitUnit();
   bool uf=UseFlag();
   datetime now=TimeCurrent();

   // ── 힘(체결) ──
   TickStats t4; AggTicks(now-4*3600,now,t4,uf); double dom4=t4.Dom();
   double o4=0; { int sh=iBarShift(_Symbol,PERIOD_M1,now-4*3600,false); if(sh>=0)o4=iOpen(_Symbol,PERIOD_M1,sh); }
   double net4 = g_metal?(price-o4):(price-o4)/OnePip();
   double h1done=BarDom(PERIOD_H1,1,uf), h1now=BarDom(PERIOD_H1,0,uf);
   double m30done=BarDom(PERIOD_M30,1,uf), m30now=BarDom(PERIOD_M30,0,uf);
   // 하위(M30 진행)가 상위(H1 완성)와 방향 반대 = 전환 조짐(1)
   int m30flip = (MathAbs(m30now)>=0.5 && MathAbs(h1done)>=0.5 && (m30now>0)!=(h1done>0)) ? 1 : 0;

   // ── 자리(세션 레벨/도달률) ──
   double reach=0,gapUp=0,gapDn=0;
   datetime sessStart; ENUM_SESSION sess=CurrentSessionStart(sessStart);
   double op=0; SessionCurrent(sessStart,op);
   double avgUp=0,avgDn=0; SessionHist(SessionStartMinute(sess),SessionEndMinute(sess),InpSessDays,avgUp,avgDn);
   if(op>0 && (avgUp>0||avgDn>0)){
      double finalUp=op+avgUp, finalDn=op-avgDn;
      bool upside=(price>=op); double lvl=upside?finalUp:finalDn; double den=lvl-op;
      reach=(MathAbs(den)<_Point)?0:(price-op)/den*100.0;
      gapUp=ToPt(finalUp-price); gapDn=ToPt(price-finalDn);
   }
   double h1pos=RangePosPct();

   int h=FileOpen(InpCsvFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI,','); if(h==INVALID_HANDLE){Print("CSV 열기 실패 ",GetLastError());return;}
   FileSeek(h,0,SEEK_END);
   FileWrite(h,
      TimeToString(ToKST(now,InpServerToKST),TIME_DATE|TIME_MINUTES), event, (string)ticket, sym, (isBuy?"매수":"매도"),
      DoubleToString(vol,2), DoubleToString(price,_Digits),
      (sl>0?DoubleToString(sl,_Digits):""), (tp>0?DoubleToString(tp,_Digits):""),
      DoubleToString(profit,2),
      DoubleToString(dom4,1), DoubleToString(net4,1),
      DoubleToString(h1done,1), DoubleToString(h1now,1),
      DoubleToString(m30done,1), DoubleToString(m30now,1), IntegerToString(m30flip),
      DoubleToString(reach,1), DoubleToString(gapUp,1), DoubleToString(gapDn,1),
      DoubleToString(h1pos,0), SessionName(sess));
   FileClose(h);
   if(InpAlertOn) Alert(sym+" 매매일지 "+event+" 기록");
   Print("[매매일지] ",event," #",(string)ticket," ",sym," ",(isBuy?"매수":"매도")," @",DoubleToString(price,_Digits));
}

//+------------------------------------------------------------------+
int OnInit(){ InitUnit(); EnsureHeader(); Print("매매일지EA v1.00 — 힘+자리 스냅샷 | 파일 ",InpCsvFile); return(INIT_SUCCEEDED); }
void OnDeinit(const int reason){}

//--- 체결 이벤트 감지 -------------------------------------------
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   ulong deal=trans.deal; if(deal==0) return;
   if(!HistoryDealSelect(deal)){ if(!HistorySelect(TimeCurrent()-3600,TimeCurrent()+60) || !HistoryDealSelect(deal)) return; }

   string sym = HistoryDealGetString(deal,DEAL_SYMBOL);
   if(InpThisSymbolOnly && sym!=_Symbol) return;
   if(InpMagic>=0 && HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic) return;

   long   entry = HistoryDealGetInteger(deal,DEAL_ENTRY);
   long   dtype = HistoryDealGetInteger(deal,DEAL_TYPE);
   if(dtype!=DEAL_TYPE_BUY && dtype!=DEAL_TYPE_SELL) return;   // 잔고/수수료 딜 제외
   ulong  posId = (ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   double price = HistoryDealGetDouble(deal,DEAL_PRICE);
   double vol   = HistoryDealGetDouble(deal,DEAL_VOLUME);
   double profit= HistoryDealGetDouble(deal,DEAL_PROFIT);

   string ev; bool isBuy;
   if(entry==DEAL_ENTRY_IN){ ev="ENTRY"; isBuy=(dtype==DEAL_TYPE_BUY); }
   else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY){ ev="EXIT"; isBuy=(dtype==DEAL_TYPE_SELL); } // 매수를 닫는 딜은 SELL
   else { ev="REVERSE"; isBuy=(dtype==DEAL_TYPE_BUY); }

   // SL/TP: 진입 시점엔 포지션이 열려 있으므로 읽음(청산 시엔 공란)
   double sl=0,tp=0;
   if(ev=="ENTRY" && PositionSelectByTicket(posId)){ sl=PositionGetDouble(POSITION_SL); tp=PositionGetDouble(POSITION_TP); }

   LogSnapshot(ev,posId,sym,isBuy,vol,price,sl,tp,profit);
}
//+------------------------------------------------------------------+
