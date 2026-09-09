//+------------------------------------------------------------------+
//|                                              본절가드EA.mq5       |
//|   수동으로 넣은 포지션의 SL을 자동으로 '본절+버퍼'로 이동         |
//|   조건: 가격이 [진입 → TP]의 지정 비율(기본 50%) 지점 도달 시     |
//|   동작: SL 을 진입가 ± 버퍼(기본 $5) 로 이동 (수익 잠금)          |
//|   ※ 주문은 넣지 않음. 기존 포지션의 SL 만 수정.                   |
//|   ※ Algo Trading(자동매매) 켜져 있어야 SL 수정 가능.             |
//+------------------------------------------------------------------+
#property copyright "PIPxLOT — BreakEven Guard"
#property version   "1.00"
#property strict

//--- 입력 --------------------------------------------------------
input double InpTriggerRatio   = 0.5;   // 발동 비율 (진입→TP의 몇 지점, 0.5=50%)
input double InpBEProfitPt     = 5.0;   // 본절 버퍼 (진입 ± 이만큼, 금 pt=$1 → 5=$5)
input bool   InpThisSymbolOnly = true;  // 이 차트 심볼만 관리
input long   InpMagic          = -1;    // 관리할 매직넘버 (-1=전체, 수동 주문 포함)
input bool   InpAlertOn        = true;  // 발동 시 MT5 팝업
input bool   InpPushOn         = false; // 발동 시 모바일 푸시
input bool   InpShowComment    = true;  // 차트에 상태 표시

//--- 단위(기존 알림EA와 동일 규칙: 금 1pt=$1, FX 1pt=1핍) ---------
double g_ptSize=0.0001;
double OnePip(){ return((_Digits==5 || _Digits==3)? _Point*10.0 : _Point); }
void   InitUnit(){ bool metal=(_Digits<=2); g_ptSize = metal? 1.0 : OnePip(); }

//+------------------------------------------------------------------+
int OnInit()
{
   InitUnit();
   EventSetTimer(1);
   PrintFormat("본절가드EA v1.00 시작 — 발동 %.0f%% · 버퍼 %.2f(%s) · 대상 %s",
      InpTriggerRatio*100, InpBEProfitPt*g_ptSize, (_Digits<=2?"$":"핍"),
      (InpThisSymbolOnly? _Symbol : "전체 심볼"));
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){ EventKillTimer(); Comment(""); }
void OnTick(){ ManageAll(); }
void OnTimer(){ ManageAll(); }

//--- SL/TP 수정 (기존 TP 유지, SL 만 교체) ------------------------
bool ModifySL(const ulong ticket,const string sym,const double sl,const double tp)
{
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action   = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol   = sym;
   req.sl       = sl;
   req.tp       = tp;
   if(!OrderSend(req,res)) return(false);
   return(res.retcode==TRADE_RETCODE_DONE || res.retcode==TRADE_RETCODE_PLACED
       || res.retcode==TRADE_RETCODE_DONE_PARTIAL);
}

//--- 전체 포지션 순회 --------------------------------------------
void ManageAll()
{
   double bufPrice = InpBEProfitPt * g_ptSize;
   bool tradeOK = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)
               && (bool)MQLInfoInteger(MQL_TRADE_ALLOWED);
   string info = StringFormat("본절가드 | 발동 %.0f%% · 버퍼 %s | 자동매매 %s\n",
      InpTriggerRatio*100, DoubleToString(bufPrice,_Digits), (tradeOK?"ON":"OFF ⚠ 켜세요"));

   int managed=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk = PositionGetTicket(i); if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      if(InpThisSymbolOnly && sym!=_Symbol) continue;
      long mg = PositionGetInteger(POSITION_MAGIC);
      if(InpMagic>=0 && mg!=InpMagic) continue;

      long   type  = PositionGetInteger(POSITION_TYPE);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      bool   isBuy = (type==POSITION_TYPE_BUY);
      managed++;

      if(tp<=0.0){ info += "• "+sym+" #"+(string)tk+" ("+(isBuy?"매수":"매도")+") : TP 미설정 → 대기\n"; continue; }

      double pt      = SymbolInfoDouble(sym,SYMBOL_POINT);
      double minDist = (double)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL)*pt;
      double cur     = isBuy? SymbolInfoDouble(sym,SYMBOL_BID) : SymbolInfoDouble(sym,SYMBOL_ASK);
      double trig    = isBuy? entry+(tp-entry)*InpTriggerRatio : entry-(entry-tp)*InpTriggerRatio;
      double newSL   = NormalizeDouble(isBuy? entry+bufPrice : entry-bufPrice, _Digits);

      bool reached = isBuy? (cur>=trig) : (cur<=trig);
      bool better  = isBuy? (sl==0.0 || newSL>sl+pt/2.0) : (sl==0.0 || newSL<sl-pt/2.0);

      string st;
      if(!reached)        st = "도달 전";
      else if(!better)    st = "이미 본절+ (유지)";
      else {
         bool room = isBuy? (newSL <= cur-minDist) : (newSL >= cur+minDist);
         if(!room)        st = "스탑레벨 제약 → 스킵 (버퍼가 너무 큼)";
         else if(!tradeOK)st = "자동매매 OFF → 이동 불가";
         else if(ModifySL(tk,sym,newSL,tp)){
            st = "✅ 본절 이동 "+DoubleToString(newSL,_Digits);
            string m = sym+" 본절가드 발동 → SL "+DoubleToString(newSL,_Digits);
            if(InpAlertOn) Alert(m);
            if(InpPushOn)  SendNotification(m);
            Print(m," (진입 ",DoubleToString(entry,_Digits)," #",(string)tk,")");
         } else st = "이동 실패 오류 "+(string)GetLastError();
      }

      info += "• "+sym+" #"+(string)tk+" "+(isBuy?"매수":"매도")
            + " | 진입 "+DoubleToString(entry,_Digits)
            + " · 발동 "+DoubleToString(trig,_Digits)
            + " · 현재 "+DoubleToString(cur,_Digits)
            + " | SL "+(sl>0?DoubleToString(sl,_Digits):"없음")
            + " | "+st+"\n";
   }
   if(managed==0) info += "• 관리 대상 포지션 없음\n";
   if(InpShowComment) Comment(info);
}
//+------------------------------------------------------------------+
