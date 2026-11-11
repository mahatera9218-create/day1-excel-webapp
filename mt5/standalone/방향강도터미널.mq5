//+------------------------------------------------------------------+
//|                                        방향강도터미널.mq5         |
//|      지표 A — 방향강도 터미널 (한 파일 완결판, #include 없음)      |
//|                                                                  |
//|  세션 / 당일 일간 / 이번주 주간 / H4 국면 4개 층을               |
//|  차트에 상시 패널로 표시. 타이머(기본 5초)로 갱신.               |
//+------------------------------------------------------------------+
#property copyright "Engulf Strategy Indicator Set"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots   0

//--- 입력 파라미터 -------------------------------------------------
input int    InpServerToKST   = 7;      // 서버→KST 시차(시간) [KST=서버+n]
input bool   InpShowSession   = true;   // [1] 실시간 세션 표시
input bool   InpShowDaily      = true;  // [2] 당일 일간 표시
input bool   InpShowWeekly      = true; // [3] 이번주 주간 표시
input bool   InpShowH4          = true; // [4] H4 국면 표시
input bool   InpShowH1Pos       = true; // H1 위치(5일 범위%) 표시
input double InpLevelMid        = 0.5;  // 1차레벨 배율(시가±R×0.5)
input double InpLevelFull       = 1.0;  // 최종레벨 배율(시가±R×1.0)
input int    InpSessDays        = 5;    // 세션/일간 평균 일수
input int    InpWeekWeeks       = 4;    // 주간 평균 주수
input int    InpRefreshSec      = 5;    // 갱신 주기(초)
input color  InpTextColor       = clrGainsboro;
input int    InpFontSize        = 9;
input string InpFontName        = "Consolas";
input int    InpCorner          = 0;    // 0=좌상 1=우상 2=좌하 3=우하
input int    InpX               = 10;
input int    InpY               = 18;

//--- 전역 ----------------------------------------------------------
string   g_prefix = "DST_";
int      g_lineH  = 14;

//==================================================================//
//  공용 함수 (원래 부품 파일에 있던 것들을 여기 합침)              //
//==================================================================//
double OnePip()
{
   return((_Digits == 5 || _Digits == 3) ? _Point * 10.0 : _Point);
}
double ToPips(const double priceDiff)
{
   double p = OnePip();
   return(p > 0.0 ? priceDiff / p : 0.0);
}
// 방향강도(부호) / 효율(절댓값)
double DirStrength(const double open, const double high,
                   const double low,  const double close,
                   const bool keepSign = true, const bool asPercent = true)
{
   double range = high - low;
   if(range <= 0.0) return(0.0);
   double body = close - open;
   if(!keepSign) body = MathAbs(body);
   double v = body / range;
   return(asPercent ? v * 100.0 : v);
}
double ElapsedRatio(const datetime barOpenTime, const datetime now, const int periodSeconds)
{
   if(periodSeconds <= 0) return(0.0);
   double r = (double)(now - barOpenTime) / (double)periodSeconds;
   if(r < 0.0) r = 0.0; if(r > 1.0) r = 1.0;
   return(r);
}
double ReachPercent(const double price, const double baseOpen, const double level)
{
   double denom = level - baseOpen;
   if(MathAbs(denom) < _Point) return(0.0);
   return((price - baseOpen) / denom * 100.0);
}
datetime ToKST(const datetime serverTime, const int h)   { return(serverTime + (datetime)h * 3600); }
datetime ToServer(const datetime kstTime,  const int h)   { return(kstTime   - (datetime)h * 3600); }
int MinuteOfDay(const datetime kstTime)
{
   MqlDateTime t; TimeToStruct(kstTime, t);
   return(t.hour * 60 + t.min);
}

//--- 세션 ---------------------------------------------------------
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
   if(m >= 540  && m < 960)  return(SESSION_ASIA);
   if(m >= 960  && m < 1140) return(SESSION_LONDON);
   if(m >= 1140 && m < 1290) return(SESSION_TRANSIT);
   if(m >= 1290 || m < 30)   return(SESSION_NY1);
   if(m >= 30   && m < 360)  return(SESSION_NY2);
   return(SESSION_NONE);
}
int SessionStartMinute(const ENUM_SESSION s)
{
   switch(s)
   {
      case SESSION_ASIA:    return(540);
      case SESSION_LONDON:  return(960);
      case SESSION_TRANSIT: return(1140);
      case SESSION_NY1:     return(1290);
      case SESSION_NY2:     return(30);
      default:              return(360);
   }
}
int SessionEndMinute(const ENUM_SESSION s)
{
   switch(s)
   {
      case SESSION_ASIA:    return(960);
      case SESSION_LONDON:  return(1140);
      case SESSION_TRANSIT: return(1290);
      case SESSION_NY1:     return(30);
      case SESSION_NY2:     return(360);
      default:              return(540);
   }
}
ENUM_SESSION CurrentSession(const datetime serverNow, const int h, datetime &sessStartServer)
{
   datetime kstNow = ToKST(serverNow, h);
   int m = MinuteOfDay(kstNow);
   ENUM_SESSION s = SessionOfMinute(m);
   MqlDateTime kt; TimeToStruct(kstNow, kt);
   kt.hour=0; kt.min=0; kt.sec=0;
   datetime kstMidnight = StructToTime(kt);
   int startMin = SessionStartMinute(s);
   datetime kstStart = kstMidnight + (datetime)startMin * 60;
   if(s == SESSION_NY1 && m < 30) kstStart -= 86400;
   sessStartServer = ToServer(kstStart, h);
   return(s);
}

//--- 가격/포맷 헬퍼 ------------------------------------------------
double CurrentPrice()
{
   MqlTick t;
   if(SymbolInfoTick(_Symbol, t)) return((t.bid + t.ask) / 2.0);
   return(iClose(_Symbol, PERIOD_M1, 0));
}
double OpenAtTime(const datetime serverTime)
{
   int shift = iBarShift(_Symbol, PERIOD_M1, serverTime, false);
   if(shift < 0) return(0.0);
   return(iOpen(_Symbol, PERIOD_M1, shift));
}
string SignStr(const double v, const int digits = 1)
{
   string s = DoubleToString(v, digits);
   if(v > 0.0) s = "+" + s;
   return(s);
}
string PhaseStr(const double a, const double avg) { return(a > avg ? "추세" : "횡보"); }
string PhaseByRange(const double c, const double a){ return(c > a ? "추세" : "횡보"); }
string ArrowStr(const double v)
{
   if(v > 0.0) return("상승↑");
   if(v < 0.0) return("하락↓");
   return("─");
}
string BarStr(const double percent, const int cells = 10)
{
   int filled = (int)MathRound(percent / 100.0 * cells);
   if(filled < 0) filled = 0; if(filled > cells) filled = cells;
   string bar = "";
   for(int i = 0; i < cells; i++) bar += (i < filled ? "█" : "░");
   return(bar);
}

//--- 기간 평균 헬퍼 -----------------------------------------------
double AvgDirStrengthAbs(const ENUM_TIMEFRAMES tf, const int count, const int startShift = 1)
{
   double sum = 0.0; int used = 0;
   for(int i = 0; i < count; i++)
   {
      int sh = startShift + i;
      double o=iOpen(_Symbol,tf,sh), hh=iHigh(_Symbol,tf,sh), ll=iLow(_Symbol,tf,sh), c=iClose(_Symbol,tf,sh);
      if(o == 0.0) break;
      sum += MathAbs(DirStrength(o, hh, ll, c, true, true));
      used++;
   }
   return(used > 0 ? sum / used : 0.0);
}
double AvgRange(const ENUM_TIMEFRAMES tf, const int count, const int startShift = 1)
{
   double sum = 0.0; int used = 0;
   for(int i = 0; i < count; i++)
   {
      int sh = startShift + i;
      double hh=iHigh(_Symbol,tf,sh), ll=iLow(_Symbol,tf,sh);
      if(hh == 0.0) break;
      sum += (hh - ll); used++;
   }
   return(used > 0 ? sum / used : 0.0);
}
double AvgTickVolume(const ENUM_TIMEFRAMES tf, const int count, const int startShift = 1)
{
   long sum = 0; int used = 0;
   for(int i = 0; i < count; i++)
   {
      int sh = startShift + i;
      if(iTime(_Symbol,tf,sh) == 0) break;
      sum += iVolume(_Symbol,tf,sh); used++;
   }
   return(used > 0 ? (double)sum / used : 0.0);
}
void SessionHistAvg(const int startMinKST, const int endMinKST, const int h,
                    const int days, double &avgRange, double &avgTicks)
{
   avgRange = 0.0; avgTicks = 0.0; int used = 0;
   if(Bars(_Symbol, PERIOD_M5) <= 0) return;
   for(int d = 1; d <= days; d++)
   {
      double hi = -DBL_MAX, lo = DBL_MAX; long tv = 0; bool any = false;
      datetime kstNow = ToKST(TimeCurrent(), h);
      MqlDateTime kt; TimeToStruct(kstNow, kt);
      kt.hour=0; kt.min=0; kt.sec=0;
      datetime kstMidnight = StructToTime(kt) - (datetime)d * 86400;
      datetime kstStart = kstMidnight + (datetime)startMinKST * 60;
      datetime kstEnd = (endMinKST > startMinKST)
                        ? kstMidnight + (datetime)endMinKST * 60
                        : kstMidnight + 86400 + (datetime)endMinKST * 60;
      int shStart = iBarShift(_Symbol, PERIOD_M5, ToServer(kstStart,h), false);
      int shEnd   = iBarShift(_Symbol, PERIOD_M5, ToServer(kstEnd,h),   false);
      if(shStart < 0 || shEnd < 0) continue;
      for(int sh = shStart; sh >= shEnd; sh--)
      {
         double hh=iHigh(_Symbol,PERIOD_M5,sh), ll=iLow(_Symbol,PERIOD_M5,sh);
         if(hh == 0.0) continue;
         hi=MathMax(hi,hh); lo=MathMin(lo,ll); tv+=iVolume(_Symbol,PERIOD_M5,sh); any=true;
      }
      if(any && hi > lo) { avgRange += (hi-lo); avgTicks += (double)tv; used++; }
   }
   if(used > 0) { avgRange /= used; avgTicks /= used; }
}
void SessionCurrent(const datetime sessStartServer, double &hi, double &lo, long &tv)
{
   hi = -DBL_MAX; lo = DBL_MAX; tv = 0;
   int shStart = iBarShift(_Symbol, PERIOD_M5, sessStartServer, false);
   if(shStart < 0) { hi = 0; lo = 0; return; }
   for(int sh = shStart; sh >= 0; sh--)
   {
      double hh=iHigh(_Symbol,PERIOD_M5,sh), ll=iLow(_Symbol,PERIOD_M5,sh);
      if(hh == 0.0) continue;
      hi=MathMax(hi,hh); lo=MathMin(lo,ll); tv += iVolume(_Symbol,PERIOD_M5,sh);
   }
   if(hi < lo) { hi = 0; lo = 0; }
}

//==================================================================//
//  MT5 이벤트                                                       //
//==================================================================//
int OnInit()
{
   g_lineH = InpFontSize + 5;
   EventSetTimer((int)MathMax(1, InpRefreshSec));
   Redraw();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, g_prefix);
   Comment("");
}
void OnTimer() { Redraw(); }
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
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
   string lines[]; int n = 0;
   double price = CurrentPrice();
   datetime kstNow = ToKST(TimeCurrent(), InpServerToKST);
   datetime sessStart;
   ENUM_SESSION sess = CurrentSession(TimeCurrent(), InpServerToKST, sessStart);

   Push(lines, n, "┌────────────────────────────────────────┐");
   Push(lines, n, StringFormat("│ 방향강도 │ %-8s     %s KST",
                  _Symbol, TimeToString(kstNow, TIME_MINUTES)));
   Push(lines, n, StringFormat("│ 세션: %-8s │ 실시간가 %s",
                  SessionName(sess), DoubleToString(price, _Digits)));
   Push(lines, n, "├────────────────────────────────────────┤");

   if(InpShowSession) BuildSessionBlock(lines, n, sess, sessStart, price);
   if(InpShowDaily)   BuildPeriodBlock(lines, n, "[2] 당일 일간 (Daily)", PERIOD_D1, InpSessDays, price);
   if(InpShowWeekly)  BuildPeriodBlock(lines, n, "[3] 이번주 주간 (Weekly)", PERIOD_W1, InpWeekWeeks, price);
   if(InpShowH4)      BuildH4Block(lines, n, price);

   Push(lines, n, "└────────────────────────────────────────┘");
   RenderLabels(lines, n);
}

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
   double dir     = DirStrength(sOpen, hi, lo, price, true, true);
   double avgR, avgTk;
   SessionHistAvg(SessionStartMinute(sess), SessionEndMinute(sess), InpServerToKST, InpSessDays, avgR, avgTk);

   Push(L, n, StringFormat("│   세션시가 %s (시가대비 %s%%)",
                DoubleToString(sOpen, _Digits), SignStr(chgPct, 2)));
   Push(L, n, StringFormat("│   변동: 고저 %spt │ 시종 %spt",
                DoubleToString(rangePt, 1), SignStr(ocPt, 1)));
   Push(L, n, StringFormat("│         (방향강도 %s%% │ 국면 %s)",
                SignStr(dir, 1), (avgR > 0 ? PhaseByRange(hi-lo, avgR) : "-")));
   double tkPct = (avgTk > 0.0) ? (double)tv / avgTk * 100.0 : 0.0;
   Push(L, n, StringFormat("│   틱볼륨: %s%% (%d Ticks) %s",
                DoubleToString(tkPct, 0), (int)tv, BarStr(tkPct)));
   if(avgR > 0.0) BuildLevelLines(L, n, sOpen, avgR, price, true);
   Push(L, n, "├────────────────────────────────────────┤");
}

void BuildPeriodBlock(string &L[], int &n, const string title,
                      const ENUM_TIMEFRAMES tf, const int avgN, const double price)
{
   Push(L, n, "│ " + title);
   double pOpen=iOpen(_Symbol,tf,0), pHigh=iHigh(_Symbol,tf,0), pLow=iLow(_Symbol,tf,0);
   long   pTv = iVolume(_Symbol,tf,0);
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
   if(avgR > 0.0) BuildLevelLines(L, n, pOpen, avgR, price, false);
   Push(L, n, "├────────────────────────────────────────┤");
}

void BuildLevelLines(string &L[], int &n, const double base,
                     const double R, const double price, const bool withMid)
{
   if(withMid)
   {
      double up = base + R * InpLevelMid, dn = base - R * InpLevelMid;
      double reU = ReachPercent(price, base, up);
      Push(L, n, StringFormat("│   1차레벨(50%%): %s / %s",
                   DoubleToString(up, _Digits), DoubleToString(dn, _Digits)));
      Push(L, n, StringFormat("│     도달률 %s%% (%s %spt)", DoubleToString(reU, 0),
                   reU >= 100 ? "초과" : "잔여", DoubleToString(ToPips(MathAbs(up - price)), 0)));
   }
   double upF = base + R * InpLevelFull, dnF = base - R * InpLevelFull;
   double reF = ReachPercent(price, base, upF);
   Push(L, n, StringFormat("│   최종레벨(100%%): %s / %s",
                DoubleToString(upF, _Digits), DoubleToString(dnF, _Digits)));
   Push(L, n, StringFormat("│     도달률 %s%% (%s %spt)", DoubleToString(reF, 0),
                reF >= 100 ? "초과" : "잔여", DoubleToString(ToPips(MathAbs(upF - price)), 0)));
}

void BuildH4Block(string &L[], int &n, const double price)
{
   Push(L, n, "│ [4] H4 국면 (전략용)");
   double o1=iOpen(_Symbol,PERIOD_H4,1), h1=iHigh(_Symbol,PERIOD_H4,1),
          l1=iLow(_Symbol,PERIOD_H4,1),  c1=iClose(_Symbol,PERIOD_H4,1);
   double dirDone = DirStrength(o1, h1, l1, c1, true, true);
   double avgH4   = AvgDirStrengthAbs(PERIOD_H4, 30, 1);
   Push(L, n, StringFormat("│   H4완성 방향강도 %s%% (평균 %s) %s",
                SignStr(dirDone, 1), DoubleToString(avgH4, 0), PhaseStr(MathAbs(dirDone), avgH4)));

   double o0=iOpen(_Symbol,PERIOD_H4,0), h0=iHigh(_Symbol,PERIOD_H4,0), l0=iLow(_Symbol,PERIOD_H4,0);
   double dirNow = DirStrength(o0, h0, l0, price, true, true);
   datetime bt = iTime(_Symbol, PERIOD_H4, 0);
   double elapsed = ElapsedRatio(bt, TimeCurrent(), PeriodSeconds(PERIOD_H4));
   int emin = (int)((TimeCurrent() - bt) / 60);
   Push(L, n, StringFormat("│   H4진행 %s%% 경과 %dH%dm/4H (%s%%)",
                SignStr(dirNow, 1), emin/60, emin%60, DoubleToString(elapsed*100, 0)));
   Push(L, n, StringFormat("│   방향: %s", ArrowStr(dirDone)));

   if(InpShowH1Pos)
   {
      int hh = iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 120, 0);
      int ll = iLowest(_Symbol, PERIOD_H1, MODE_LOW, 120, 0);
      if(hh >= 0 && ll >= 0)
      {
         double d5h=iHigh(_Symbol,PERIOD_H1,hh), d5l=iLow(_Symbol,PERIOD_H1,ll);
         double rngPct = (d5h > d5l) ? (price - d5l) / (d5h - d5l) * 100.0 : 0.0;
         Push(L, n, StringFormat("│   H1위치: 5일범위 %s%% (저 %s ~ 고 %s)",
                      DoubleToString(rngPct, 0), DoubleToString(d5l, _Digits), DoubleToString(d5h, _Digits)));
      }
   }
}

void Push(string &arr[], int &n, const string s)
{
   ArrayResize(arr, n + 1);
   arr[n] = s; n++;
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
