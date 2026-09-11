//+------------------------------------------------------------------+
//|                                                       Common.mqh  |
//|            인걸핑 전략 지원 지표 세트 — 공용 함수 라이브러리       |
//|                                                                  |
//|  PRD 2/4장 공통 규약 구현:                                        |
//|   - 핍 환산(_Digits 기반 자동)                                    |
//|   - 방향강도(부호 유지) / 효율(절댓값) — 하나의 공용 함수         |
//|   - 경과율(모든 Ongoing 공통 공식)                                |
//|   - 세션 판정(KST 고정, 서버-KST 시차 파라미터 보정)              |
//|   - 시가/고저/도달률/평균 계산 헬퍼                               |
//+------------------------------------------------------------------+
#property strict
#ifndef ENGULF_COMMON_MQH
#define ENGULF_COMMON_MQH

//==================================================================//
//  핍(pip) 환산                                                     //
//  PRD §2: _Digits가 5 또는 3이면 _Point*10 이 1핍, 그 외 _Point    //
//==================================================================//
double OnePip()
{
   return((_Digits == 5 || _Digits == 3) ? _Point * 10.0 : _Point);
}

// 가격차 → 핍
double ToPips(const double priceDiff)
{
   double p = OnePip();
   return(p > 0.0 ? priceDiff / p : 0.0);
}

//==================================================================//
//  방향강도 / 효율 — 형제 계산 (PRD §1 인걸핑 품질 ②, §2 A/B)      //
//    방향강도 = (종가-시가)/(고가-저가)×100  [부호 유지]           |
//    효율     = |종가-시가|/(고가-저가)       [절댓값, 0~1]         |
//  keepSign=true → 방향강도, false → 효율(강도만)                  //
//  (고가-저가)=0 이면 0 처리 (0 나눗셈 방지)                        //
//==================================================================//
double DirStrength(const double open, const double high,
                   const double low,  const double close,
                   const bool keepSign = true, const bool asPercent = true)
{
   double range = high - low;
   if(range <= 0.0)
      return(0.0);
   double body = close - open;
   if(!keepSign)
      body = MathAbs(body);
   double v = body / range;
   return(asPercent ? v * 100.0 : v);
}

//==================================================================//
//  경과율 — 모든 Ongoing 공통 공식 (PRD §2)                        //
//    경과율 = (현재시각 - 봉 시가시각) / 봉주기                     //
//  periodSeconds = PeriodSeconds(tf)                               //
//==================================================================//
double ElapsedRatio(const datetime barOpenTime, const datetime now,
                    const int periodSeconds)
{
   if(periodSeconds <= 0)
      return(0.0);
   double r = (double)(now - barOpenTime) / (double)periodSeconds;
   if(r < 0.0) r = 0.0;
   if(r > 1.0) r = 1.0;
   return(r);
}

//==================================================================//
//  도달률 % (PRD §2 지표 A)                                        //
//    도달률 = (현재가 - 시가) / (레벨 - 시가) × 100                |
//    100 미만 = 미도달(여력) / 100 초과 = 돌파                     //
//==================================================================//
double ReachPercent(const double price, const double baseOpen, const double level)
{
   double denom = level - baseOpen;
   if(MathAbs(denom) < _Point)
      return(0.0);
   return((price - baseOpen) / denom * 100.0);
}

//==================================================================//
//  KST 변환 & 세션 판정 (PRD §2 지표 A / §4)                       //
//    MT5 서버시간은 브로커마다 다름 → serverToKSTHours 로 보정      |
//    KST = 서버시간 + serverToKSTHours 시간                        |
//==================================================================//
datetime ToKST(const datetime serverTime, const int serverToKSTHours)
{
   return(serverTime + (datetime)serverToKSTHours * 3600);
}

datetime ToServer(const datetime kstTime, const int serverToKSTHours)
{
   return(kstTime - (datetime)serverToKSTHours * 3600);
}

// KST datetime → 자정 이후 분(0~1439)
int MinuteOfDay(const datetime kstTime)
{
   MqlDateTime t;
   TimeToStruct(kstTime, t);
   return(t.hour * 60 + t.min);
}

//------------------------------------------------------------------//
//  세션 정의 (KST 고정) — PRD §2 지표 A                            //
//    아시아   09:00~16:00                                          |
//    런던전반 16:00~19:00                                          |
//    전환     19:00~21:30                                          |
//    뉴욕전반 21:30~00:30 (자정 넘김)                              |
//    뉴욕후반 00:30~06:00                                          |
//    그 외    (06:00~09:00) 휴장/대기                              |
//------------------------------------------------------------------//
enum ENUM_SESSION
{
   SESSION_NONE = 0,   // 휴장/대기
   SESSION_ASIA,       // 아시아
   SESSION_LONDON,     // 런던전반
   SESSION_TRANSIT,    // 전환
   SESSION_NY1,        // 뉴욕전반
   SESSION_NY2         // 뉴욕후반
};

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

// 분(0~1439) → 세션
ENUM_SESSION SessionOfMinute(const int m)
{
   if(m >= 540  && m < 960)  return(SESSION_ASIA);    // 09:00~16:00
   if(m >= 960  && m < 1140) return(SESSION_LONDON);  // 16:00~19:00
   if(m >= 1140 && m < 1290) return(SESSION_TRANSIT); // 19:00~21:30
   if(m >= 1290 || m < 30)   return(SESSION_NY1);     // 21:30~00:30
   if(m >= 30   && m < 360)  return(SESSION_NY2);     // 00:30~06:00
   return(SESSION_NONE);                              // 06:00~09:00
}

// 세션 시작 분(KST). 뉴욕전반은 1290(21:30), 자정 넘김 주의.
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

//------------------------------------------------------------------//
//  현재 세션 판정 + 세션 시작 서버시각 계산                        |
//  반환: 세션, 그리고 sessStartServer(세션 시가 봉 탐색용)         |
//------------------------------------------------------------------//
ENUM_SESSION CurrentSession(const datetime serverNow, const int serverToKSTHours,
                            datetime &sessStartServer)
{
   datetime kstNow = ToKST(serverNow, serverToKSTHours);
   int m = MinuteOfDay(kstNow);
   ENUM_SESSION s = SessionOfMinute(m);

   // KST 자정 시각(서버 기준 계산용)
   MqlDateTime kt;
   TimeToStruct(kstNow, kt);
   kt.hour = 0; kt.min = 0; kt.sec = 0;
   datetime kstMidnight = StructToTime(kt);

   int startMin = SessionStartMinute(s);
   datetime kstStart = kstMidnight + (datetime)startMin * 60;
   // 뉴욕전반(21:30 시작)이 자정을 넘겨 지금이 00:00~00:30 이면 시작은 '어제'
   if(s == SESSION_NY1 && m < 30)
      kstStart -= 86400;

   sessStartServer = ToServer(kstStart, serverToKSTHours);
   return(s);
}

//==================================================================//
//  가격 조회 헬퍼                                                   //
//==================================================================//
double CurrentPrice()
{
   MqlTick t;
   if(SymbolInfoTick(_Symbol, t))
      return((t.bid + t.ask) / 2.0);
   return(iClose(_Symbol, PERIOD_M1, 0));
}

// 지정 서버시각의 시가 근사: 해당 시각 이후 첫 M1 봉의 시가
double OpenAtTime(const datetime serverTime)
{
   int shift = iBarShift(_Symbol, PERIOD_M1, serverTime, false);
   if(shift < 0)
      return(0.0);
   return(iOpen(_Symbol, PERIOD_M1, shift));
}

//==================================================================//
//  표시 포맷 헬퍼                                                   //
//==================================================================//
string SignStr(const double v, const int digits = 1)
{
   string s = DoubleToString(v, digits);
   if(v > 0.0) s = "+" + s;
   return(s);
}

string PhaseStr(const double dirStrengthAbs, const double avgAbs)
{
   return(dirStrengthAbs > avgAbs ? "추세" : "횡보");
}

string ArrowStr(const double signedVal)
{
   if(signedVal > 0.0) return("상승↑");
   if(signedVal < 0.0) return("하락↓");
   return("─");
}

// 0~100% → 간이 막대(10칸)
string BarStr(const double percent, const int cells = 10)
{
   int filled = (int)MathRound(percent / 100.0 * cells);
   if(filled < 0) filled = 0;
   if(filled > cells) filled = cells;
   string bar = "";
   for(int i = 0; i < cells; i++)
      bar += (i < filled ? "█" : "░");
   return(bar);
}

#endif // ENGULF_COMMON_MQH
//+------------------------------------------------------------------+
