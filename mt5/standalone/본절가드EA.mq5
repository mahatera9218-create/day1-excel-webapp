//+------------------------------------------------------------------+
//|                                              본절가드EA.mq5       |
//|   수동 진입 포지션의 3단계 자동 관리 (주문은 넣지 않음)          |
//|   ① 진입→TP1 의 지정% 도달 → SL 을 진입 ± 버퍼로 이동 (본절)     |
//|   ② TP1 직전 도달 → 지정 비율만 남기고 부분청산                  |
//|   ③ 그때 남은 러너만 TP2(=진입+TP1거리×배수)로, SL 은 본절       |
//|   ※ 전량 포지션의 TP 는 절대 안 옮김. 브로커 TP=TP1 그대로 유지.  |
//|   ※ 75% 청산 후 남은 25% 러너에만 TP2 를 설정.                    |
//|   ※ 50% 도달 전엔 TP 자유 수정 가능(TP1 확정은 50% 도달 시).      |
//|   ※ Algo Trading(자동매매) 켜져 있어야 동작.                     |
//+------------------------------------------------------------------+
#property copyright "PIPxLOT — Position Guard"
#property version   "1.30"
#property strict

//--- 입력 --------------------------------------------------------
input double InpTriggerRatio   = 0.5;   // 본절 발동 비율 (진입→TP1의 몇 지점)
input double InpBEProfitPt     = 5.0;   // 본절 버퍼 (진입 ± 이만큼, 금 pt=$1 → 5=$5)
input bool   InpUseRunner      = true;  // 러너 사용 (TP1 부분청산 + TP2 보유)
input double InpRunnerPct      = 25.0;  // TP1에서 남길 러너 비율(%)
input double InpTP2Mult        = 2.0;   // TP2 = 진입 + (TP1거리 × 이 배수)
input double InpTP1LeadPt      = 0.3;   // TP1 이만큼 앞에서 부분청산(레이스 방지, 금 pt=$1)
input bool   InpThisSymbolOnly = true;  // 이 차트 심볼만 관리
input long   InpMagic          = -1;    // 관리할 매직넘버 (-1=전체, 수동 포함)
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
   PrintFormat("본절가드EA v1.30 — 본절 %.0f%%·버퍼 %.2f | 러너 %s(%.0f%%,TP2×%.1f) | 대상 %s",
      InpTriggerRatio*100, InpBEProfitPt*g_ptSize,
      (InpUseRunner?"ON":"OFF"), InpRunnerPct, InpTP2Mult,
      (InpThisSymbolOnly? _Symbol : "전체"));
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){ EventKillTimer(); Comment(""); }
void OnTick(){ ManageAll(); }
void OnTimer(){ ManageAll(); }

//--- 로트 정규화 -------------------------------------------------
double NormLot(const string sym,double v)
{
   double step=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP); if(step<=0)step=0.01;
   double mx  =SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX);
   v=MathFloor(v/step+1e-8)*step;
   if(v>mx)v=mx;
   int ld=(int)MathMax(0,MathCeil(-MathLog10(step)));
   return(NormalizeDouble(v,ld));
}
//--- SL/TP 수정 (SL·TP 동시 지정, 기존 값 유지하려면 그대로 전달) --
bool ModifySLTP(const ulong ticket,const string sym,const double sl,const double tp)
{
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action=TRADE_ACTION_SLTP; req.position=ticket; req.symbol=sym; req.sl=sl; req.tp=tp;
   if(!OrderSend(req,res)) return(false);
   return(res.retcode==TRADE_RETCODE_DONE || res.retcode==TRADE_RETCODE_PLACED
       || res.retcode==TRADE_RETCODE_DONE_PARTIAL);
}
//--- 부분청산 ---------------------------------------------------
bool ClosePartial(const ulong ticket,const string sym,const long type,const double vol)
{
   MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
   req.action=TRADE_ACTION_DEAL; req.position=ticket; req.symbol=sym; req.volume=vol; req.deviation=30;
   req.type =(type==POSITION_TYPE_BUY)? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.price=(type==POSITION_TYPE_BUY)? SymbolInfoDouble(sym,SYMBOL_BID) : SymbolInfoDouble(sym,SYMBOL_ASK);
   int fm=(int)SymbolInfoInteger(sym,SYMBOL_FILLING_MODE);
   req.type_filling=((fm&SYMBOL_FILLING_IOC)!=0)? ORDER_FILLING_IOC
                   :(((fm&SYMBOL_FILLING_FOK)!=0)? ORDER_FILLING_FOK : ORDER_FILLING_RETURN);
   if(!OrderSend(req,res)) return(false);
   return(res.retcode==TRADE_RETCODE_DONE || res.retcode==TRADE_RETCODE_DONE_PARTIAL || res.retcode==TRADE_RETCODE_PLACED);
}
void Msg(const string m){ if(InpAlertOn)Alert(m); if(InpPushOn)SendNotification(m); Print(m); }

//--- 전체 포지션 순회 --------------------------------------------
void ManageAll()
{
   double bufPrice = InpBEProfitPt * g_ptSize;
   bool tradeOK = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)
               && (bool)MQLInfoInteger(MQL_TRADE_ALLOWED);
   string info = StringFormat("포지션관리 | 본절 %.0f%%·버퍼 %s | 러너 %s | 자동매매 %s\n",
      InpTriggerRatio*100, DoubleToString(bufPrice,_Digits),
      (InpUseRunner?StringFormat("ON %.0f%%·TP2×%.1f",InpRunnerPct,InpTP2Mult):"OFF"),
      (tradeOK?"ON":"OFF ⚠ 켜세요"));

   int managed=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk = PositionGetTicket(i); if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      if(InpThisSymbolOnly && sym!=_Symbol) continue;
      if(InpMagic>=0 && PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      managed++;

      long   type  = PositionGetInteger(POSITION_TYPE);
      bool   isBuy = (type==POSITION_TYPE_BUY);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double vol   = PositionGetDouble(POSITION_VOLUME);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double pt      = SymbolInfoDouble(sym,SYMBOL_POINT);
      double minDist = (double)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL)*pt;
      double cur     = isBuy? SymbolInfoDouble(sym,SYMBOL_BID) : SymbolInfoDouble(sym,SYMBOL_ASK);

      string kT="BEG_"+(string)tk+"_TP1", kR="BEG_"+(string)tk+"_RUN", kP="BEG_"+(string)tk+"_PART";

      // ── 무장(arm) 전: 50% 도달 전까지는 아무것도 안 건드림 → TP 자유 수정 가능 ──
      if(!GlobalVariableCheck(kT))
      {
         if(tp<=0.0){ info+="• "+sym+" #"+(string)tk+" ("+(isBuy?"매수":"매도")+") : TP 미설정 → 대기\n"; continue; }
         double beTrigL = isBuy? entry+(tp-entry)*InpTriggerRatio : entry-(entry-tp)*InpTriggerRatio;
         bool reachedL  = isBuy? (cur>=beTrigL) : (cur<=beTrigL);
         if(!reachedL)
         {
            info += "• "+sym+" #"+(string)tk+" "+(isBuy?"매수":"매도")+" "+DoubleToString(vol,2)+"lot"
                  + " | 진입 "+DoubleToString(entry,_Digits)
                  + " · TP1(예정) "+DoubleToString(tp,_Digits)
                  + " · 발동 "+DoubleToString(beTrigL,_Digits)
                  + " · 현재 "+DoubleToString(cur,_Digits)
                  + " | 50% 전 — TP 조정 가능\n";
            continue;
         }
         if(!tradeOK){ info+="• "+sym+" #"+(string)tk+" : 50% 도달했으나 자동매매 OFF → 대기\n"; continue; }
         // ── TP1 확정(arm): 브로커 TP 는 안 건드림(TP1 유지). 러너 가능여부만 판단 ──
         double tp1c=tp; GlobalVariableSet(kT,tp1c);
         bool run=false;
         if(InpUseRunner)
         {
            double closeVol=NormLot(sym, vol*(1.0-InpRunnerPct/100.0));
            double runVol  =NormLot(sym, vol-closeVol);
            double mn      =SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
            run = (closeVol>=mn-1e-8 && runVol>=mn-1e-8 && closeVol>0.0);
         }
         GlobalVariableSet(kR, run?1.0:0.0);
         GlobalVariableSet(kP, 0.0);
         Print(sym," #",(string)tk," TP1 확정 ",DoubleToString(tp1c,_Digits),(run?" · 러너 대기(TP1 직전 부분청산 예정)":" · 러너 불가(단일랏)"));
      }

      // ── 무장(arm) 후: 저장된 TP1 기준으로 관리 ──
      double tp1    = GlobalVariableGet(kT);
      bool   runner = (GlobalVariableGet(kR)>0.5);
      bool   parted = (GlobalVariableGet(kP)>0.5);
      string stage="";

      // ── ① 본절: SL 을 진입 ± 버퍼로 (아직 아니면 이동, idempotent) ──
      double newSL  = NormalizeDouble(isBuy? entry+bufPrice : entry-bufPrice, _Digits);
      bool beBetter = isBuy? (sl==0.0||newSL>sl+pt/2.0) : (sl==0.0||newSL<sl-pt/2.0);
      if(beBetter)
      {
         bool room = isBuy? (newSL<=cur-minDist) : (newSL>=cur+minDist);
         if(!room)         stage="본절 스킵(버퍼 큼) ";
         else if(!tradeOK) stage="본절 대기(자동매매 OFF) ";
         else if(ModifySLTP(tk,sym,newSL,tp)){ stage="✅본절 "+DoubleToString(newSL,_Digits)+" ";
            Msg(sym+" 본절 이동 → SL "+DoubleToString(newSL,_Digits)); sl=newSL; }
         else stage="본절 실패 err"+(string)GetLastError()+" ";
      }

      // ── ② TP1 직전 부분청산 → 남은 러너에만 TP2 설정 (러너 모드) ──
      if(runner && !parted)
      {
         double lead = InpTP1LeadPt*g_ptSize;
         bool tp1near = isBuy? (cur>=tp1-lead) : (cur<=tp1+lead);
         if(tp1near)
         {
            if(!tradeOK) stage+="부분청산 대기(자동매매 OFF)";
            else{
               double closeVol=NormLot(sym, vol*(1.0-InpRunnerPct/100.0));
               if(closeVol>0.0 && ClosePartial(tk,sym,type,closeVol)){
                  GlobalVariableSet(kP,1.0);
                  double tp2=NormalizeDouble(isBuy? entry+(tp1-entry)*InpTP2Mult : entry-(entry-tp1)*InpTP2Mult, _Digits);
                  double rsl=sl; if(PositionSelectByTicket(tk)) rsl=PositionGetDouble(POSITION_SL);
                  if(ModifySLTP(tk,sym,rsl,tp2)) tp=tp2;
                  stage+="✅TP1 "+DoubleToString(closeVol,2)+"lot 청산 → 러너 TP2 "+DoubleToString(tp2,_Digits);
                  Msg(sym+" TP1 도달 → "+DoubleToString(closeVol,2)+"lot 청산, 러너 TP2 "+DoubleToString(tp2,_Digits));
               } else stage+="부분청산 실패 err"+(string)GetLastError();
            }
         }
      }

      if(stage=="") stage = (runner? (parted?"러너 보유중(TP2 대기)":"본절 완료·TP1 대기") : "본절 완료·TP1 대기");

      info += "• "+sym+" #"+(string)tk+" "+(isBuy?"매수":"매도")+" "+DoubleToString(vol,2)+"lot"
            + " | 진입 "+DoubleToString(entry,_Digits)
            + " · TP1 "+DoubleToString(tp1,_Digits)
            + (parted? " · TP2 "+DoubleToString(tp,_Digits) : "")
            + " · 현재 "+DoubleToString(cur,_Digits)
            + " | SL "+(sl>0?DoubleToString(sl,_Digits):"없음")
            + " | "+stage+"\n";
   }
   if(managed==0) info += "• 관리 대상 포지션 없음\n";

   // ── 닫힌 포지션의 글로벌 변수 정리 ──
   for(int g=GlobalVariablesTotal()-1; g>=0; g--)
   {
      string nm=GlobalVariableName(g);
      if(StringFind(nm,"BEG_")!=0) continue;
      string parts[]; if(StringSplit(nm,'_',parts)<2) continue;
      ulong t=(ulong)StringToInteger(parts[1]);
      if(!PositionSelectByTicket(t)) GlobalVariableDel(nm);
   }

   if(InpShowComment) Comment(info);
}
//+------------------------------------------------------------------+
