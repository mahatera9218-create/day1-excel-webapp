//+------------------------------------------------------------------+
//|                                                       Engulf.mqh  |
//|      인걸핑 감지 + 품질 점수 라이브러리 (PRD §1)                  |
//|                                                                  |
//|  인걸핑 정의 (Inthebox 방식):                                     |
//|   조건1(필수): 현재 몸통이 직전 몸통을 완전히 삼킴               |
//|   조건2(필수): 진입방향 쪽 꼬리도 직전 꼬리를 삼킴              |
//|     상승 → 윗꼬리가 직전 윗꼬리 넘음 / 하락 → 아래꼬리가 직전 넘음|
//|   멀티캔들: 1캔들에 못 삼켜도 2~3캔들이 모여 삼키면 인정         |
//|                                                                  |
//|  인걸핑 존 = 인걸핑 캔들 몸통 범위(시가~종가), 옵션: 꼬리까지     |
//+------------------------------------------------------------------+
#property strict
#ifndef ENGULF_ENGULF_MQH
#define ENGULF_ENGULF_MQH
#include <Engulf/Common.mqh>

enum ENUM_ENGULF_DIR { ENGULF_NONE = 0, ENGULF_BULL = +1, ENGULF_BEAR = -1 };

//--- 인걸핑 감지 결과
struct EngulfResult
{
   ENUM_ENGULF_DIR dir;        // 방향
   int             legs;       // 몇 캔들이 모여 삼켰나 (멀티캔들)
   double          zoneOpen;   // 존 시가
   double          zoneClose;  // 존 종가
   double          engHigh;    // 인걸핑(합성) 고가
   double          engLow;     // 인걸핑(합성) 저가
   datetime        time;       // 인걸핑 확정 봉(직전 완성봉) 시각
   void Reset()
   {
      dir = ENGULF_NONE; legs = 0;
      zoneOpen = zoneClose = engHigh = engLow = 0.0; time = 0;
   }
};

//------------------------------------------------------------------//
//  인걸핑 감지 — 완성봉 기준 (checkShift = 1 권장)                  |
//  현재 캔들(checkShift)이 직전 1~maxLegs 캔들을 삼키는지 검사      |
//------------------------------------------------------------------//
bool DetectEngulf(const ENUM_TIMEFRAMES tf, const int checkShift,
                  EngulfResult &r, const int maxLegs = 3)
{
   r.Reset();

   double cOpen  = iOpen (_Symbol, tf, checkShift);
   double cClose = iClose(_Symbol, tf, checkShift);
   double cHigh  = iHigh (_Symbol, tf, checkShift);
   double cLow   = iLow  (_Symbol, tf, checkShift);
   if(cOpen == 0.0 || cClose == 0.0)
      return(false);

   int curDir = (cClose > cOpen) ? +1 : (cClose < cOpen ? -1 : 0);
   if(curDir == 0)
      return(false);   // 도지 → 방향 없음

   double curBodyTop = MathMax(cOpen, cClose);
   double curBodyBot = MathMin(cOpen, cClose);

   // 직전 1~maxLegs 캔들을 누적하며 "완전히 삼켰는가" 확인
   double prevBodyTop = -DBL_MAX, prevBodyBot = DBL_MAX;
   double prevHigh    = -DBL_MAX, prevLow     = DBL_MAX;

   for(int leg = 1; leg <= maxLegs; leg++)
   {
      int sh = checkShift + leg;
      double pO = iOpen (_Symbol, tf, sh);
      double pC = iClose(_Symbol, tf, sh);
      double pH = iHigh (_Symbol, tf, sh);
      double pL = iLow  (_Symbol, tf, sh);
      if(pO == 0.0)
         break;

      // 반대색 캔들만 피(被)인걸핑 대상으로 누적 (같은 방향이 나오면 중단)
      int pDir = (pC > pO) ? +1 : (pC < pO ? -1 : 0);
      if(leg > 1 && pDir == curDir)
         break;

      prevBodyTop = MathMax(prevBodyTop, MathMax(pO, pC));
      prevBodyBot = MathMin(prevBodyBot, MathMin(pO, pC));
      prevHigh    = MathMax(prevHigh, pH);
      prevLow     = MathMin(prevLow,  pL);

      // 조건1: 몸통 완전 삼킴
      bool bodyEngulf = (curBodyTop >= prevBodyTop && curBodyBot <= prevBodyBot);
      if(!bodyEngulf)
         continue;

      // 조건2: 진입방향 쪽 꼬리도 직전 꼬리 삼킴
      bool wickOK;
      if(curDir > 0)  wickOK = (cHigh >= prevHigh);   // 상승 → 윗꼬리
      else            wickOK = (cLow  <= prevLow);    // 하락 → 아래꼬리
      if(!wickOK)
         continue;

      // 확정
      r.dir       = (curDir > 0) ? ENGULF_BULL : ENGULF_BEAR;
      r.legs      = leg;
      r.zoneOpen  = cOpen;
      r.zoneClose = cClose;
      r.engHigh   = cHigh;
      r.engLow    = cLow;
      r.time      = iTime(_Symbol, tf, checkShift);
      return(true);
   }
   return(false);
}

//------------------------------------------------------------------//
//  가격이 인걸핑 존 안에 있는가 (리테스트 판정용)                   |
//  wickZone=true 면 존을 고저(꼬리)까지 확장                        |
//------------------------------------------------------------------//
bool PriceInZone(const double price, const EngulfResult &r, const bool wickZone = false)
{
   double top, bot;
   if(wickZone)
   {
      top = r.engHigh; bot = r.engLow;
   }
   else
   {
      top = MathMax(r.zoneOpen, r.zoneClose);
      bot = MathMin(r.zoneOpen, r.zoneClose);
   }
   return(price <= top && price >= bot);
}

//==================================================================//
//  품질 점수 (PRD §1 인걸핑 품질 점수)                             //
//  [1단계] 각 항목 정규화(0~1) 후 가중합 → 0~100                    |
//  ⚠️ 가중치는 '감'이 아니라 데이터로 → 초기: 균등 가중치           |
//  항목별 값도 함께 반환하여 CSV 기록/상관분석에 사용               |
//==================================================================//
struct QualityScore
{
   double engulfRatio;   // ① 삼킴 비율 = 현재몸통/직전몸통
   double candleStrength;// ② 캔들 방향강도(효율) = |종가-시가|/(고저)
   double levelProx;     // ③ 레벨 근접도 (핍) — 가까울수록 강
   double htfAlign;      // ④ 상위(H4) 방향 일치 (+1/-1)
   double flowAlign;     // ⑤ 체결 일치 (+1/-1/0), 없으면 0
   double rsi;           // ⑥ (선택) RSI 값
   double score;         // 최종 0~100
};

//--- 각 항목 0~1 정규화
double NormRatio(const double ratio)   // ① 1.0~2.0+ → 0~1 (2.0 이상 포화)
{
   double v = (ratio - 1.0) / 1.0;     // 1.0→0, 2.0→1
   if(v < 0.0) v = 0.0; if(v > 1.0) v = 1.0;
   return(v);
}
double NormStrength(const double effAbs01)  // ② 0~1 그대로 (효율)
{
   double v = effAbs01;
   if(v < 0.0) v = 0.0; if(v > 1.0) v = 1.0;
   return(v);
}
double NormLevelProx(const double pips)      // ③ 5핍이내=1, 50핍밖=0 (선형)
{
   double v = (50.0 - MathAbs(pips)) / 45.0; // 5→1, 50→0
   if(v < 0.0) v = 0.0; if(v > 1.0) v = 1.0;
   return(v);
}
double NormAlign(const double alignSigned)   // ④⑤ -1~+1 → 0~1
{
   double v = (alignSigned + 1.0) / 2.0;
   if(v < 0.0) v = 0.0; if(v > 1.0) v = 1.0;
   return(v);
}

//------------------------------------------------------------------//
//  품질 점수 계산                                                   |
//  w[] : 가중치 배열 (①~⑤). 합이 0이면 균등 처리.                  |
//  htfSameDir  : 상위(H4) 방향강도 부호와 인걸핑 방향 일치 여부      |
//  flowSameDir : 체결 우위 방향 일치 (0 = 미사용)                    |
//  levelDistPips: 가장 가까운 주요 레벨과의 거리(핍)                 |
//------------------------------------------------------------------//
QualityScore ComputeQuality(const EngulfResult &r,
                            const double prevBodySize,
                            const double htfSameDir,
                            const double flowSameDir,
                            const double levelDistPips,
                            const double rsiValue,
                            const double &w[])
{
   QualityScore q;
   q.rsi = rsiValue;

   // ① 삼킴 비율
   double curBody = MathAbs(r.zoneClose - r.zoneOpen);
   q.engulfRatio = (prevBodySize > 0.0) ? curBody / prevBodySize : 1.0;

   // ② 캔들 방향강도(효율, 0~1)
   q.candleStrength = DirStrength(r.zoneOpen, r.engHigh, r.engLow, r.zoneClose,
                                  false /*abs*/, false /*0~1*/);

   // ③ 레벨 근접도
   q.levelProx = levelDistPips;

   // ④ 상위 방향 일치
   q.htfAlign = (htfSameDir > 0 ? +1.0 : (htfSameDir < 0 ? -1.0 : 0.0));

   // ⑤ 체결 일치
   q.flowAlign = flowSameDir;

   // 정규화
   double n1 = NormRatio(q.engulfRatio);
   double n2 = NormStrength(q.candleStrength);
   double n3 = NormLevelProx(q.levelProx);
   double n4 = NormAlign(q.htfAlign);
   double n5 = NormAlign(q.flowAlign);

   // 가중치 (균등 fallback)
   double ww[5];
   double sum = 0.0;
   int n = ArraySize(w);
   for(int i = 0; i < 5; i++)
   {
      ww[i] = (i < n) ? w[i] : 0.0;
      sum += ww[i];
   }
   if(sum <= 0.0)  // 균등 가중치 (PRD: 편견 없이 시작)
   {
      for(int i = 0; i < 5; i++) ww[i] = 1.0;
      sum = 5.0;
   }

   double weighted = n1*ww[0] + n2*ww[1] + n3*ww[2] + n4*ww[3] + n5*ww[4];
   q.score = weighted / sum * 100.0;
   return(q);
}

#endif // ENGULF_ENGULF_MQH
//+------------------------------------------------------------------+
