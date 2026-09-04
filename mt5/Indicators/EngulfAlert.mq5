//+------------------------------------------------------------------+
//|                                                   EngulfAlert.mq5 |
//|      인걸핑 발생 알림 + 리테스트 추적 + engulf_log.csv (PRD §2)   |
//|                                                                  |
//|  H1 인걸핑 감지 → 알림(Alert/푸시) + 품질점수 + CSV 기록          |
//|  리테스트: 확정 후 M15 4개 안에 존 재진입 확인                    |
//|                                                                  |
//|  ※ 지표는 '판단 재료'만 제공. 진입은 사람이 캔들에서 결정.        |
//+------------------------------------------------------------------+
#property copyright "Engulf Strategy Indicator Set"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots   0

#include <Engulf/Common.mqh>
#include <Engulf/Engulf.mqh>
#include <Engulf/Ticks.mqh>

//--- 입력 --------------------------------------------------------
input group "── 프레임/전략 ──"
input ENUM_TIMEFRAMES InpEngulfTF = PERIOD_H1;  // 인걸핑 감지 프레임
input ENUM_TIMEFRAMES InpRetestTF = PERIOD_M15; // 리테스트 프레임
input int    InpRetestBars   = 4;               // 리테스트 유효 봉 수
input int    InpMaxLegs      = 3;               // 멀티캔들 최대 leg
input bool   InpWickZone     = false;           // 존을 꼬리까지 확장
input int    InpServerToKST  = 7;               // 서버→KST 시차
input group "── 품질 점수 가중치 (초기: 균등=0 → 자동균등) ──"
input double InpW_Ratio      = 0;   // ① 삼킴비율
input double InpW_Candle     = 0;   // ② 캔들방향강도
input double InpW_Level      = 0;   // ③ 레벨근접
input double InpW_HTF        = 0;   // ④ 상위(H4)일치
input double InpW_Flow       = 0;   // ⑤ 체결일치
input group "── 알림 채널 ──"
input bool   InpAlertPopup   = true;   // 팝업 Alert
input bool   InpAlertPush    = true;   // 모바일 푸시(SendNotification)
input group "── 로그 ──"
input bool   InpWriteCsv     = true;
input string InpCsvFile      = "engulf_log.csv";
input bool   InpDemoTag      = true;   // 데모/실계좌 태그

//--- 리테스트 추적 상태 ------------------------------------------
struct RetestState
{
   bool         active;
   string       id;
   EngulfResult eng;
   datetime     startM15;   // 추적 시작(확정 직후) M15 봉시각
   int          barsSeen;   // 지나간 M15 봉 수
   bool         logged;     // 진입여부 로그 갱신됨?
};
RetestState g_rt;

datetime g_lastEngBar = 0;   // 마지막으로 검사한 인걸핑 프레임 봉
datetime g_lastM15Bar = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   g_rt.active = false;
   EventSetTimer(3);
   EnsureCsvHeader();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason) { EventKillTimer(); }

void OnTimer() { CheckEngulf(); TrackRetest(); }

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   CheckEngulf();
   TrackRetest();
   return(rates_total);
}

//==================================================================//
//  인걸핑 감지 (신규 완성봉에서만)                                  //
//==================================================================//
void CheckEngulf()
{
   datetime b1 = iTime(_Symbol, InpEngulfTF, 1);  // 직전 완성봉
   if(b1 == 0 || b1 == g_lastEngBar)
      return;
   g_lastEngBar = b1;

   EngulfResult r;
   if(!DetectEngulf(InpEngulfTF, 1, r, InpMaxLegs))
      return;

   //--- 품질 점수 재료 수집
   double prevBody = MathAbs(iClose(_Symbol, InpEngulfTF, 2) - iOpen(_Symbol, InpEngulfTF, 2));

   // H4 방향강도 방향 (완성봉)
   double h4dir = DirStrength(iOpen(_Symbol, PERIOD_H4, 1), iHigh(_Symbol, PERIOD_H4, 1),
                              iLow(_Symbol, PERIOD_H4, 1), iClose(_Symbol, PERIOD_H4, 1),
                              true, true);
   double htfSame = (h4dir * (double)r.dir > 0) ? +1 : (h4dir * (double)r.dir < 0 ? -1 : 0);

   // 체결 우위 (인걸핑 봉 범위 틱)
   bool useFlag = BrokerProvidesTradeFlags();
   TickStats ts; AggregateBarTicks(InpEngulfTF, 1, ts, useFlag);
   double dom = ts.Dominance();
   double flowSame = 0;
   if(ts.valid && ts.total > 0)
      flowSame = (dom * (double)r.dir > 0) ? +1 : (dom * (double)r.dir < 0 ? -1 : 0);

   // 레벨 근접도 (핍) — 전일/전주 고저, 당일 시가 중 최근접
   double levelDist = NearestLevelPips((r.zoneOpen + r.zoneClose) / 2.0);

   // RSI
   double rsi = GetRSI(InpEngulfTF, 14, 1);

   double w[5];
   w[0]=InpW_Ratio; w[1]=InpW_Candle; w[2]=InpW_Level; w[3]=InpW_HTF; w[4]=InpW_Flow;
   QualityScore q = ComputeQuality(r, prevBody, htfSame, flowSame, levelDist, rsi, w);

   //--- 위치(5일 범위%)
   double posPct = RangePosPct();
   double wkChg  = ToPips(CurrentPrice() - iOpen(_Symbol, PERIOD_W1, 0));

   //--- ID 생성
   string id = MakeEngulfId(r.time);

   //--- 알림
   datetime kstNow = ToKST(TimeCurrent(), InpServerToKST);
   ENUM_SESSION sess; datetime dm;
   sess = CurrentSession(TimeCurrent(), InpServerToKST, dm);
   string dirTxt = (r.dir == ENGULF_BULL ? "상승" : "하락");

   string msg = StringFormat(
      "🔔 [%s %s 인걸핑] %s %s\n점수 %.0f | RSI %.1f | 세션 %s\n존 %s~%s | H4일치 %s | 체결일치 %s | 위치 %.0f%%",
      TfName(InpEngulfTF), dirTxt, _Symbol, TimeToString(kstNow, TIME_MINUTES),
      q.score, rsi, SessionName(sess),
      DoubleToString(r.zoneOpen, _Digits), DoubleToString(r.zoneClose, _Digits),
      (htfSame > 0 ? "✓" : "✗"), (flowSame > 0 ? "✓" : (ts.valid ? "✗" : "-")), posPct);

   if(InpAlertPopup) Alert(msg);
   if(InpAlertPush)  SendNotification(msg);
   Print(msg);

   //--- CSV 기록 (진입 무관, 모든 신호)
   if(InpWriteCsv)
      LogEngulf(id, r, q, rsi, SessionName(sess), h4dir, posPct, wkChg, dom, ts.valid);

   //--- 리테스트 추적 시작
   g_rt.active   = true;
   g_rt.id       = id;
   g_rt.eng      = r;
   g_rt.startM15 = iTime(_Symbol, InpRetestTF, 0);
   g_rt.barsSeen = 0;
   g_rt.logged   = false;
}

//==================================================================//
//  리테스트 추적 (M15 4개 안에 존 재진입?)                          //
//==================================================================//
void TrackRetest()
{
   if(!g_rt.active)
      return;

   datetime m15 = iTime(_Symbol, InpRetestTF, 0);
   if(m15 != g_lastM15Bar)
   {
      g_lastM15Bar = m15;
      if(m15 > g_rt.startM15)         // 확정 이후 새 M15 봉
         g_rt.barsSeen++;
   }

   // 현재가 존 재진입 확인
   double price = CurrentPrice();
   if(PriceInZone(price, g_rt.eng, InpWickZone))
   {
      // 진입가 후보(얕은 되돌림=존 경계), 손절(존 시가 밖), 익절(2:1)
      double zTop = MathMax(g_rt.eng.zoneOpen, g_rt.eng.zoneClose);
      double zBot = MathMin(g_rt.eng.zoneOpen, g_rt.eng.zoneClose);
      double entry, sl, tp;
      if(g_rt.eng.dir == ENGULF_BULL)
      {
         entry = zBot + (zTop - zBot) * 0.5;   // 얕은 되돌림
         sl    = g_rt.eng.zoneOpen - OnePip() * 1; // 존 시가 밖
         tp    = entry + (entry - sl) * 2.0;       // 2:1
      }
      else
      {
         entry = zTop - (zTop - zBot) * 0.5;
         sl    = g_rt.eng.zoneOpen + OnePip() * 1;
         tp    = entry - (sl - entry) * 2.0;
      }
      string msg = StringFormat(
         "✅ [리테스트 도달 %d/%d] %s\n진입후보 %s | 손절 %s | 익절 %s (2:1)",
         g_rt.barsSeen + 1, InpRetestBars, g_rt.id,
         DoubleToString(entry, _Digits), DoubleToString(sl, _Digits),
         DoubleToString(tp, _Digits));
      if(InpAlertPopup) Alert(msg);
      if(InpAlertPush)  SendNotification(msg);
      Print(msg);

      UpdateEngulfRetest(g_rt.id, g_rt.barsSeen + 1);
      g_rt.active = false;   // 추적 종료
      return;
   }

   // 4개 초과 → 무효
   if(g_rt.barsSeen >= InpRetestBars)
   {
      Print(StringFormat("⛔ [리테스트 무효] %s — M15 %d개 안에 재진입 없음",
            g_rt.id, InpRetestBars));
      UpdateEngulfRetest(g_rt.id, -1);   // -1 = 무효
      g_rt.active = false;
   }
}

//==================================================================//
//  품질 점수 보조                                                   //
//==================================================================//
double NearestLevelPips(const double price)
{
   double lv[6]; int c = 0;
   lv[c++] = iHigh(_Symbol, PERIOD_D1, 1);   // 전일 고
   lv[c++] = iLow(_Symbol, PERIOD_D1, 1);    // 전일 저
   lv[c++] = iHigh(_Symbol, PERIOD_W1, 1);   // 전주 고
   lv[c++] = iLow(_Symbol, PERIOD_W1, 1);    // 전주 저
   lv[c++] = iOpen(_Symbol, PERIOD_D1, 0);   // 당일 시가
   lv[c++] = iOpen(_Symbol, PERIOD_W1, 0);   // 주간 시가
   double best = DBL_MAX;
   for(int i = 0; i < c; i++)
   {
      if(lv[i] <= 0.0) continue;
      double d = MathAbs(ToPips(price - lv[i]));
      if(d < best) best = d;
   }
   return(best == DBL_MAX ? 999.0 : best);
}

double RangePosPct()
{
   int hh = iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 120, 0);
   int ll = iLowest(_Symbol, PERIOD_H1, MODE_LOW, 120, 0);
   if(hh < 0 || ll < 0) return(0.0);
   double h = iHigh(_Symbol, PERIOD_H1, hh);
   double l = iLow(_Symbol, PERIOD_H1, ll);
   double p = CurrentPrice();
   return((h > l) ? (p - l) / (h - l) * 100.0 : 0.0);
}

double GetRSI(const ENUM_TIMEFRAMES tf, const int period, const int shift)
{
   int h = iRSI(_Symbol, tf, period, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return(0.0);
   double buf[];
   if(CopyBuffer(h, 0, shift, 1, buf) <= 0) { IndicatorRelease(h); return(0.0); }
   double v = buf[0];
   IndicatorRelease(h);
   return(v);
}

//==================================================================//
//  CSV 로깅 (engulf_log.csv)                                        //
//==================================================================//
void EnsureCsvHeader()
{
   if(!InpWriteCsv) return;
   if(FileIsExist(InpCsvFile)) return;
   int h = FileOpen(InpCsvFile, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE) { Print("CSV 헤더 생성 실패: ", GetLastError()); return; }
   FileWrite(h, "engulf_id","time_kst","symbol","dir","zone_open","zone_close",
             "score","q_ratio","q_candle","q_levelpip","q_htf","q_flow",
             "rsi","session","h4_dir","pos_pct","wk_chg_pip","flow_dom","account",
             "retest_bar","entered");
   FileClose(h);
}

void LogEngulf(const string id, const EngulfResult &r, const QualityScore &q,
               const double rsi, const string session, const double h4dir,
               const double posPct, const double wkChg, const double dom,
               const bool flowValid)
{
   int h = FileOpen(InpCsvFile, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE) { Print("CSV 열기 실패: ", GetLastError()); return; }
   FileSeek(h, 0, SEEK_END);
   datetime kst = ToKST(r.time, InpServerToKST);
   string acct = AccountTag();
   FileWrite(h, id, TimeToString(kst, TIME_DATE | TIME_MINUTES), _Symbol,
             (r.dir == ENGULF_BULL ? "상승" : "하락"),
             DoubleToString(r.zoneOpen, _Digits), DoubleToString(r.zoneClose, _Digits),
             DoubleToString(q.score, 1), DoubleToString(q.engulfRatio, 2),
             DoubleToString(q.candleStrength, 3), DoubleToString(q.levelProx, 1),
             DoubleToString(q.htfAlign, 0), DoubleToString(q.flowAlign, 0),
             DoubleToString(rsi, 1), session, DoubleToString(h4dir, 1),
             DoubleToString(posPct, 0), DoubleToString(wkChg, 1),
             (flowValid ? DoubleToString(dom, 1) : "NA"), acct,
             "", "N");   // retest_bar/entered 는 추후 갱신
   FileClose(h);
}

// 리테스트 결과를 마지막 행에 반영하는 대신, 별도 라인 append (단순화)
void UpdateEngulfRetest(const string id, const int retestBar)
{
   int h = FileOpen(InpCsvFile, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE) return;
   FileSeek(h, 0, SEEK_END);
   // 갱신 이벤트를 별도 행으로 남김 (조인/후처리로 매칭). entered 는 사용자가 확정.
   FileWrite(h, id, "RETEST_UPDATE", _Symbol, "", "", "", "", "", "", "", "", "",
             "", "", "", "", "", "", AccountTag(),
             (retestBar < 0 ? "무효" : IntegerToString(retestBar)), "");
   FileClose(h);
}

//==================================================================//
//  유틸                                                             //
//==================================================================//
string MakeEngulfId(const datetime engTime)
{
   datetime kst = ToKST(engTime, InpServerToKST);
   MqlDateTime t; TimeToStruct(kst, t);
   return(StringFormat("%s-%04d%02d%02d-%02d%02d", _Symbol,
          t.year, t.mon, t.day, t.hour, t.min));
}

string AccountTag()
{
   if(!InpDemoTag) return("");
   ENUM_ACCOUNT_TRADE_MODE m = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   switch(m)
   {
      case ACCOUNT_TRADE_MODE_DEMO:    return("DEMO");
      case ACCOUNT_TRADE_MODE_CONTEST: return("CONTEST");
      default:                         return("REAL");
   }
}

string TfName(const ENUM_TIMEFRAMES tf)
{
   string s = EnumToString(tf);
   if(StringFind(s, "PERIOD_") == 0) s = StringSubstr(s, 7);
   return(s);
}
//+------------------------------------------------------------------+
