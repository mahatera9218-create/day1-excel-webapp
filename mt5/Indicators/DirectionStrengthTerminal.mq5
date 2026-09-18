//+------------------------------------------------------------------+
//|                                     DirectionStrengthTerminal.mq5 |
//|              지표 A — 방향강도 터미널 (PRD §2, 우선순위 1)        |
//|                                                                  |
//|  세션 / 당일 일간 / 이번주 주간 / H4 국면 4개 층을               |
//|  차트에 상시 패널로 표시. 타이머(5~10초)로 갱신.                  |
//|                                                                  |
//|  ※ 가격(캔들)이 메인, 지표는 보조 — 지금 '어떤 맥락'인가만 제공.  |
//+------------------------------------------------------------------+
#property copyright "Engulf Strategy Indicator Set"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots   0

#include <Engulf/Common.mqh>
#include <Engulf/Stats.mqh>

//--- 입력 파라미터 -------------------------------------------------
input group "── 시간대 보정 ──"
input int    InpServerToKST   = 7;      // 서버→KST 시차(시간) [KST=서버+n]
input group "── 표시 층 on/off ──"
input bool   InpShowSession   = true;   // [1] 실시간 세션
input bool   InpShowDaily      = true;  // [2] 당일 일간
input bool   InpShowWeekly      = true; // [3] 이번주 주간
input bool   InpShowH4          = true; // [4] H4 국면
input bool   InpShowH1Pos       = true; // H1 위치(5일 범위%)를 H4블록에 표시
input group "── 레벨 배율 (PRD §2) ──"
input double InpLevelMid        = 0.5;  // 1차레벨 배율(시가±R×0.5)
input double InpLevelFull       = 1.0;  // 최종레벨 배율(시가±R×1.0)
input group "── 평균 표본 수 ──"
input int    InpSessDays        = 5;    // 세션/일간 평균 일수
input int    InpWeekWeeks       = 4;    // 주간 평균 주수
input group "── 표시/갱신 ──"
input int    InpRefreshSec      = 5;    // 갱신 주기(초)
input color  InpTextColor       = clrGainsboro;
input int    InpFontSize        = 9;
input string InpFontName        = "Consolas";
input int    InpCorner          = 0;    // 0=좌상 1=우상 2=좌하 3=우하
input int    InpX               = 10;   // X 여백
input int    InpY               = 18;   // Y 여백

//--- 전역 ----------------------------------------------------------
string   g_prefix = "DST_";
int      g_lineH  = 14;

//+------------------------------------------------------------------+
int OnInit()
{
   g_lineH = InpFontSize + 5;
   EventSetTimer((int)MathMax(1, InpRefreshSec));
   Redraw();
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, g_prefix);
   Comment("");
}
//+------------------------------------------------------------------+
void OnTimer() { Redraw(); }
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   // 신규 봉에서만 즉시 갱신 (매 틱 재계산 방지 — PRD §4 성능)
   static datetime lastBar = 0;
   datetime cur = (rates_total > 0) ? time[rates_total - 1] : 0;
   if(cur != lastBar) { lastBar = cur; Redraw(); }
   return(rates_total);
}

//==================================================================//
//  패널 렌더링                                                      //
//==================================================================//
void Redraw()
{
   string lines[];
   int n = 0;
   double price = CurrentPrice();
   datetime kstNow = ToKST(TimeCurrent(), InpServerToKST);

   datetime sessStart;
   ENUM_SESSION sess = CurrentSession(TimeCurrent(), InpServerToKST, sessStart);

   //--- 헤더
   Push(lines, n, "┌────────────────────────────────────────┐");
   Push(lines, n, StringFormat("│ 방향강도 │ %-8s     %s KST",
                  _Symbol, TimeToString(kstNow, TIME_MINUTES)));
   Push(lines, n, StringFormat("│ 세션: %-8s │ 실시간가 %s",
                  SessionName(sess), DoubleToString(price, _Digits)));
   Push(lines, n, "├────────────────────────────────────────┤");

   //--- [1] 세션
   if(InpShowSession)
      BuildSessionBlock(lines, n, sess, sessStart, price);

   //--- [2] 일간
   if(InpShowDaily)
      BuildPeriodBlock(lines, n, "[2] 당일 일간 (Daily)", PERIOD_D1,
                       InpSessDays, price);

   //--- [3] 주간
   if(InpShowWeekly)
      BuildPeriodBlock(lines, n, "[3] 이번주 주간 (Weekly)", PERIOD_W1,
                       InpWeekWeeks, price);

   //--- [4] H4 국면
   if(InpShowH4)
      BuildH4Block(lines, n, price);

   Push(lines, n, "└────────────────────────────────────────┘");

   RenderLabels(lines, n);
}

//------------------------------------------------------------------//
//  [1] 실시간 세션 블록                                             |
//------------------------------------------------------------------//
void BuildSessionBlock(string &L[], int &n, const ENUM_SESSION sess,
                       const datetime sessStart, const double price)
{
   Push(L, n, "│ [1] 실시간 세션 (Session)");
   if(sess == SESSION_NONE)
   {
      Push(L, n, "│   (휴장/대기 구간 — 세션 미형성)");
      Push(L, n, "├────────────────────────────────────────┤");
      return;
   }

   double sOpen = OpenAtTime(sessStart);
   double hi, lo; long tv;
   SessionCurrent(sessStart, hi, lo, tv);
   if(sOpen <= 0.0 || hi <= 0.0) { Push(L, n, "│   (세션 데이터 준비중)");
      Push(L, n, "├────────────────────────────────────────┤"); return; }

   double chgPct  = (sOpen > 0.0) ? (price - sOpen) / sOpen * 100.0 : 0.0;
   double rangePt = ToPips(hi - lo);
   double ocPt    = ToPips(price - sOpen);
   double dir     = DirStrength(sOpen, hi, lo, price, true, true); // 시종/고저

   // 세션 히스토리 평균 (고저폭 R, 틱볼륨)
   int sm = SessionStartMinute(sess);
   int em = SessionEndMinute(sess);
   double avgR, avgTk;
   SessionHistAvg(sm, em, InpServerToKST, InpSessDays, avgR, avgTk);

   Push(L, n, StringFormat("│   세션시가 %s (시가대비 %s%%)",
                DoubleToString(sOpen, _Digits), SignStr(chgPct, 2)));
   Push(L, n, StringFormat("│   변동: 고저 %spt │ 시종 %spt",
                DoubleToString(rangePt, 1), SignStr(ocPt, 1)));
   Push(L, n, StringFormat("│         (방향강도 %s%% │ 국면 %s)",
                SignStr(dir, 1), (avgR > 0 ? PhaseByRange(hi-lo, avgR) : "-")));

   double tkPct = (avgTk > 0.0) ? (double)tv / avgTk * 100.0 : 0.0;
   Push(L, n, StringFormat("│   틱볼륨: %s%% (%d Ticks) %s",
                DoubleToString(tkPct, 0), (int)tv, BarStr(tkPct)));

   // 레벨 (시가 ± R×배율)
   if(avgR > 0.0)
      BuildLevelLines(L, n, sOpen, avgR, price, true);

   Push(L, n, "├────────────────────────────────────────┤");
}

//------------------------------------------------------------------//
//  [2]/[3] 일간·주간 공통 블록                                      |
//------------------------------------------------------------------//
void BuildPeriodBlock(string &L[], int &n, const string title,
                      const ENUM_TIMEFRAMES tf, const int avgN,
                      const double price)
{
   Push(L, n, "│ " + title);
   double pOpen = iOpen(_Symbol, tf, 0);
   double pHigh = iHigh(_Symbol, tf, 0);
   double pLow  = iLow(_Symbol, tf, 0);
   long   pTv   = iVolume(_Symbol, tf, 0);
   if(pOpen <= 0.0) { Push(L, n, "│   (데이터 준비중)");
      Push(L, n, "├────────────────────────────────────────┤"); return; }

   double chgPct  = (price - pOpen) / pOpen * 100.0;
   double rangePt = ToPips(pHigh - pLow);
   double ocPt    = ToPips(price - pOpen);
   double dir     = DirStrength(pOpen, pHigh, pLow, price, true, true);

   double avgDirAbs = AvgDirStrengthAbs(tf, avgN, 1);
   double avgR      = AvgRange(tf, avgN, 1);
   double avgTk     = AvgTickVolume(tf, avgN, 1);

   Push(L, n, StringFormat("│   시가 %s (시가대비 %s%%)",
                DoubleToString(pOpen, _Digits), SignStr(chgPct, 2)));
   Push(L, n, StringFormat("│   변동: 고저 %spt │ 시종 %spt",
                DoubleToString(rangePt, 1), SignStr(ocPt, 1)));
   Push(L, n, StringFormat("│         (방향강도 %s%% │ %d평균 %s%% │ %s)",
                SignStr(dir, 1), avgN, DoubleToString(avgDirAbs, 0),
                PhaseStr(MathAbs(dir), avgDirAbs)));

   double tkPct = (avgTk > 0.0) ? (double)pTv / avgTk * 100.0 : 0.0;
   Push(L, n, StringFormat("│   틱볼륨: %s%% (%d Ticks) %s",
                DoubleToString(tkPct, 0), (int)pTv, BarStr(tkPct)));

   if(avgR > 0.0)
      BuildLevelLines(L, n, pOpen, avgR, price, false);

   Push(L, n, "├────────────────────────────────────────┤");
}

//------------------------------------------------------------------//
//  레벨 + 도달률 라인 (PRD §2)                                      |
//  withMid=true → 1차(0.5)/최종(1.0) 둘 다, false → 최종만          |
//------------------------------------------------------------------//
void BuildLevelLines(string &L[], int &n, const double base,
                     const double R, const double price, const bool withMid)
{
   if(withMid)
   {
      double up = base + R * InpLevelMid;
      double dn = base - R * InpLevelMid;
      double reU = ReachPercent(price, base, up);
      Push(L, n, StringFormat("│   1차레벨(50%%): %s / %s",
                   DoubleToString(up, _Digits), DoubleToString(dn, _Digits)));
      Push(L, n, StringFormat("│     도달률 %s%% (%s %spt)",
                   DoubleToString(reU, 0),
                   reU >= 100 ? "초과" : "잔여",
                   DoubleToString(ToPips(MathAbs(up - price)), 0)));
   }
   double upF = base + R * InpLevelFull;
   double dnF = base - R * InpLevelFull;
   double reF = ReachPercent(price, base, upF);
   Push(L, n, StringFormat("│   최종레벨(100%%): %s / %s",
                DoubleToString(upF, _Digits), DoubleToString(dnF, _Digits)));
   Push(L, n, StringFormat("│     도달률 %s%% (%s %spt)",
                DoubleToString(reF, 0),
                reF >= 100 ? "초과" : "잔여",
                DoubleToString(ToPips(MathAbs(upF - price)), 0)));
}

//------------------------------------------------------------------//
//  [4] H4 국면 블록 (전략용)                                        |
//------------------------------------------------------------------//
void BuildH4Block(string &L[], int &n, const double price)
{
   Push(L, n, "│ [4] H4 국면 (전략용)");

   // 완성봉(shift=1)
   double o1 = iOpen(_Symbol, PERIOD_H4, 1), h1 = iHigh(_Symbol, PERIOD_H4, 1);
   double l1 = iLow(_Symbol, PERIOD_H4, 1),  c1 = iClose(_Symbol, PERIOD_H4, 1);
   double dirDone = DirStrength(o1, h1, l1, c1, true, true);
   double avgH4   = AvgDirStrengthAbs(PERIOD_H4, 30, 1);  // 최근 5일(H4 30개)

   Push(L, n, StringFormat("│   H4완성 방향강도 %s%% (평균 %s) %s",
                SignStr(dirDone, 1), DoubleToString(avgH4, 0),
                PhaseStr(MathAbs(dirDone), avgH4)));

   // 진행봉(shift=0) — 현재까지 방향강도 + 경과율
   double o0 = iOpen(_Symbol, PERIOD_H4, 0), h0 = iHigh(_Symbol, PERIOD_H4, 0);
   double l0 = iLow(_Symbol, PERIOD_H4, 0);
   double dirNow = DirStrength(o0, h0, l0, price, true, true);
   datetime bt = iTime(_Symbol, PERIOD_H4, 0);
   double elapsed = ElapsedRatio(bt, TimeCurrent(), PeriodSeconds(PERIOD_H4));
   int emin = (int)((TimeCurrent() - bt) / 60);
   Push(L, n, StringFormat("│   H4진행 %s%% 경과 %dH%dm/4H (%s%%)",
                SignStr(dirNow, 1), emin / 60, emin % 60,
                DoubleToString(elapsed * 100, 0)));
   Push(L, n, StringFormat("│   방향: %s", ArrowStr(dirDone)));

   // H1 위치 (5일 범위 %) — PRD: 여기 배치 권장 (중복 방지)
   if(InpShowH1Pos)
   {
      int hh = iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 120, 0);
      int ll = iLowest(_Symbol, PERIOD_H1, MODE_LOW, 120, 0);
      if(hh >= 0 && ll >= 0)
      {
         double d5h = iHigh(_Symbol, PERIOD_H1, hh);
         double d5l = iLow(_Symbol, PERIOD_H1, ll);
         double rngPct = (d5h > d5l) ? (price - d5l) / (d5h - d5l) * 100.0 : 0.0;
         Push(L, n, StringFormat("│   H1위치: 5일범위 %s%% (저 %s ~ 고 %s)",
                      DoubleToString(rngPct, 0),
                      DoubleToString(d5l, _Digits), DoubleToString(d5h, _Digits)));
      }
   }
}

//==================================================================//
//  보조 함수                                                        //
//==================================================================//
int SessionEndMinute(const ENUM_SESSION s)
{
   switch(s)
   {
      case SESSION_ASIA:    return(960);   // 16:00
      case SESSION_LONDON:  return(1140);  // 19:00
      case SESSION_TRANSIT: return(1290);  // 21:30
      case SESSION_NY1:     return(30);    // 00:30 (자정 넘김)
      case SESSION_NY2:     return(360);   // 06:00
      default:              return(540);
   }
}

string PhaseByRange(const double curRange, const double avgRange)
{
   return(curRange > avgRange ? "추세" : "횡보");
}

void Push(string &arr[], int &n, const string s)
{
   ArrayResize(arr, n + 1);
   arr[n] = s;
   n++;
}

//------------------------------------------------------------------//
//  OBJ_LABEL 로 각 줄 렌더링 (모노스페이스 폰트 권장)              |
//------------------------------------------------------------------//
void RenderLabels(string &L[], const int n)
{
   // 기존 라벨 수 관리
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
   // 남는 라벨 삭제
   int idx = n;
   while(ObjectFind(0, g_prefix + IntegerToString(idx)) >= 0)
   {
      ObjectDelete(0, g_prefix + IntegerToString(idx));
      idx++;
   }
   ChartRedraw();
}
//+------------------------------------------------------------------+
