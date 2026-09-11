//+------------------------------------------------------------------+
//|                                            ExecutionTerminal.mq5  |
//|              지표 B — 체결 터미널 (PRD §2, 우선순위 3)           |
//|                                                                  |
//|  CopyTicks() 로 호가 틱을 받아 매수/매도 체결을 집계.            |
//|   [1] 최근 4H 체결 역학 요약                                      |
//|   [2] 5M 완성봉 vs 진행봉 대조                                    |
//|   [3] 1H 완성봉 vs 진행봉 대조                                    |
//+------------------------------------------------------------------+
#property copyright "Engulf Strategy Indicator Set"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots   0

#include <Engulf/Common.mqh>
#include <Engulf/Ticks.mqh>

//--- 입력 --------------------------------------------------------
input group "── 프레임 (조정 가능) ──"
input ENUM_TIMEFRAMES InpEntryTF = PERIOD_M5;   // 진입 프레임
input ENUM_TIMEFRAMES InpZoneTF  = PERIOD_H1;   // 자리 프레임
input int    InpServerToKST      = 7;           // 서버→KST 시차(시간)
input group "── 표시/갱신 ──"
input int    InpRefreshSec       = 5;           // 갱신 주기(초)
input color  InpTextColor        = clrKhaki;
input int    InpFontSize         = 9;
input string InpFontName         = "Consolas";
input int    InpCorner           = 1;           // 0좌상 1우상 2좌하 3우하
input int    InpX                = 10;
input int    InpY                = 18;

//--- 전역 --------------------------------------------------------
string g_prefix = "EXT_";
int    g_lineH  = 14;
bool   g_useFlag = true;   // 브로커 BUY/SELL flag 제공 여부

//+------------------------------------------------------------------+
int OnInit()
{
   g_lineH = InpFontSize + 5;
   g_useFlag = BrokerProvidesTradeFlags();  // PRD §4: flag 제공 여부 먼저 확인
   EventSetTimer((int)MathMax(1, InpRefreshSec));
   Redraw();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, g_prefix);
}
void OnTimer() { Redraw(); }
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
   string L[]; int n = 0;
   datetime kstNow = ToKST(TimeCurrent(), InpServerToKST);
   datetime dummy; ENUM_SESSION sess = CurrentSession(TimeCurrent(), InpServerToKST, dummy);

   Push(L, n, "┌────────────────────────────────────────┐");
   Push(L, n, StringFormat("│ 체결 터미널 │ %-8s   %s KST",
                _Symbol, TimeToString(kstNow, TIME_MINUTES)));
   Push(L, n, StringFormat("│ 세션: %-8s  체결flag %s",
                SessionName(sess), (g_useFlag ? "제공O" : "추정")));
   Push(L, n, "├────────────────────────────────────────┤");

   Build4HSummary(L, n);
   Push(L, n, "├────────────────────────────────────────┤");
   BuildFrameBlock(L, n, "[2] " + TfName(InpEntryTF) + " 실시간 (진입)", InpEntryTF);
   Push(L, n, "├────────────────────────────────────────┤");
   BuildFrameBlock(L, n, "[3] " + TfName(InpZoneTF) + " 상세 대조 (자리)", InpZoneTF);

   Push(L, n, "└────────────────────────────────────────┘");
   RenderLabels(L, n);
}

//------------------------------------------------------------------//
//  [1] 최근 4H 체결 역학 요약                                       |
//------------------------------------------------------------------//
void Build4HSummary(string &L[], int &n)
{
   Push(L, n, "│ [1] 최근 4H 체결 역학 요약");

   datetime to   = TimeCurrent();
   datetime from = to - 4 * 3600;
   TickStats st;
   bool ok = AggregateTicks(from, to, st, g_useFlag);

   double dom = st.Dominance();
   string side = (dom > 0 ? "매수" : (dom < 0 ? "매도" : "중립"));

   // 4H 순이동 / 고저폭 (H4 진행봉 기준 근사: 최근 4시간)
   double open4h = OpenAtTime(from);
   double price  = CurrentPrice();
   double net    = ToPips(price - open4h);

   int hh = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 48, 0); // 4H = M5 48개
   int ll = iLowest(_Symbol, PERIOD_M5, MODE_LOW, 48, 0);
   double hi = (hh >= 0) ? iHigh(_Symbol, PERIOD_M5, hh) : 0;
   double lo = (ll >= 0) ? iLow(_Symbol, PERIOD_M5, ll) : 0;
   double span = ToPips(hi - lo);

   if(!ok)
      Push(L, n, "│   (틱 데이터 없음 — 브로커 보관량 확인)");
   else
   {
      Push(L, n, StringFormat("│   4H 누적틱: %d ticks (왜곡 %d)", (int)st.total, (int)st.distort));
      Push(L, n, StringFormat("│   순 방향성: %s%% %s 우위 (↑%d/↓%d)",
                   SignStr(dom, 1), side, (int)st.up, (int)st.down));
   }
   Push(L, n, StringFormat("│   4H 순이동: %s핍 │ 고저폭: %s핍",
                SignStr(net, 1), DoubleToString(span, 1)));
}

//------------------------------------------------------------------//
//  [2]/[3] 프레임 완성봉 vs 진행봉 대조                             |
//------------------------------------------------------------------//
void BuildFrameBlock(string &L[], int &n, const string title,
                     const ENUM_TIMEFRAMES tf)
{
   Push(L, n, "│ " + title);
   //--- 직전 완성봉 (shift=1)
   Push(L, n, "│  ┌ 직전 완성봉 (-1)");
   BuildBarLines(L, n, tf, 1, false);
   //--- 현재 진행봉 (shift=0)
   Push(L, n, "│  └ 현재 진행봉 (Ongoing)");
   BuildBarLines(L, n, tf, 0, true);
}

//------------------------------------------------------------------//
//  한 봉의 체결 항목 라인                                           |
//------------------------------------------------------------------//
void BuildBarLines(string &L[], int &n, const ENUM_TIMEFRAMES tf,
                   const int shift, const bool ongoing)
{
   double o = iOpen(_Symbol, tf, shift);
   double h = iHigh(_Symbol, tf, shift);
   double l = iLow(_Symbol, tf, shift);
   double c = (shift == 0) ? CurrentPrice() : iClose(_Symbol, tf, shift);
   if(o <= 0.0) { Push(L, n, "│     (데이터 준비중)"); return; }

   double move  = ToPips(c - o);          // 실이동 = 종가-시가
   double swing = ToPips(h - l);          // 흔들림 = 고가-저가
   double eff   = DirStrength(o, h, l, c, false, false); // 효율 |실이동|/흔들림

   TickStats st;
   AggregateBarTicks(tf, shift, st, g_useFlag);
   double dom = st.Dominance();
   double perTick = (st.total > 0) ? move / (double)st.total : 0.0;

   if(ongoing)
   {
      datetime bt = iTime(_Symbol, tf, 0);
      double el = ElapsedRatio(bt, TimeCurrent(), PeriodSeconds(tf));
      int esec = (int)(TimeCurrent() - bt);
      Push(L, n, StringFormat("│     경과 %dm%ds/%dm (%s%%)",
                   esec / 60, esec % 60, PeriodSeconds(tf) / 60,
                   DoubleToString(el * 100, 0)));
   }
   Push(L, n, StringFormat("│     총틱 %d (왜곡 %d)", (int)st.total, (int)st.distort));
   Push(L, n, StringFormat("│     방향성 %s%% (↑%d/↓%d)",
                SignStr(dom, 1), (int)st.up, (int)st.down));
   Push(L, n, StringFormat("│     실이동 %s (흔들림 %s │ 효율 %s)",
                SignStr(move, 1), DoubleToString(swing, 1), DoubleToString(eff, 2)));
   Push(L, n, StringFormat("│     틱당 실이동 %s/tick", SignStr(perTick, 3)));
}

//==================================================================//
string TfName(const ENUM_TIMEFRAMES tf)
{
   string s = EnumToString(tf);          // "PERIOD_M5"
   int p = StringFind(s, "PERIOD_");
   if(p == 0) s = StringSubstr(s, 7);
   return(s);
}

void Push(string &arr[], int &n, const string s)
{
   ArrayResize(arr, n + 1);
   arr[n] = s;
   n++;
}

void RenderLabels(string &L[], const int n)
{
   for(int i = 0; i < n; i++)
   {
      string name = g_prefix + IntegerToString(i);
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, InpCorner);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpX);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
         ObjectSetString(0, name, OBJPROP_FONT, InpFontName);
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpTextColor);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpY + i * g_lineH);
      ObjectSetString(0, name, OBJPROP_TEXT, L[i]);
   }
   int idx = n;
   while(ObjectFind(0, g_prefix + IntegerToString(idx)) >= 0)
   {
      ObjectDelete(0, g_prefix + IntegerToString(idx));
      idx++;
   }
   ChartRedraw();
}
//+------------------------------------------------------------------+
