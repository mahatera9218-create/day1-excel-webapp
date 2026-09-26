//+------------------------------------------------------------------+
//|                                                        Ticks.mqh  |
//|         호가 틱 집계 라이브러리 (PRD §2 지표 B / 체결 우위)       |
//|                                                                  |
//|  CopyTicks() 로 [from, to] 범위의 틱을 받아                       |
//|   - 총틱 / Up틱(매수) / Down틱(매도) / 왜곡틱                     |
//|   - 체결 우위 = (Up-Down)/총틱×100                               |
//|  을 집계한다.                                                     |
//|                                                                  |
//|  PRD 주의: 일부 브로커는 TICK_FLAG_BUY/SELL 미제공 →             |
//|   그 경우 last 가 직전 ask 근접→매수, 직전 bid 근접→매도 로 추정  |
//+------------------------------------------------------------------+
#property strict
#ifndef ENGULF_TICKS_MQH
#define ENGULF_TICKS_MQH

//--- 틱 집계 결과 구조체
struct TickStats
{
   long   total;      // 총틱
   long   up;         // 매수 체결(Up)
   long   down;       // 매도 체결(Down)
   long   distort;    // 왜곡(비정상) 틱
   bool   valid;      // 집계 성공 여부

   void   Reset() { total = 0; up = 0; down = 0; distort = 0; valid = false; }
   double Dominance() const  // 체결 우위 % = (Up-Down)/총틱×100
   {
      if(total <= 0) return(0.0);
      return((double)(up - down) / (double)total * 100.0);
   }
};

//------------------------------------------------------------------//
//  [from, to] 서버시각 범위 틱 집계                                 |
//  useFlag=true  → TICK_FLAG_BUY/SELL 사용                          |
//  useFlag=false → bid/ask 근접 추정                                |
//------------------------------------------------------------------//
bool AggregateTicks(const datetime from, const datetime to,
                    TickStats &out, const bool useFlag = true)
{
   out.Reset();
   if(to < from)
      return(false);

   MqlTick ticks[];
   // ms 단위 요청 (CopyTicksRange 는 밀리초)
   ulong fromMsc = (ulong)from * 1000;
   ulong toMsc   = (ulong)to   * 1000 + 999;

   int got = CopyTicksRange(_Symbol, ticks, COPY_TICKS_ALL, fromMsc, toMsc);
   if(got <= 0)
      return(false);

   double prevBid = 0.0, prevAsk = 0.0;
   bool   havePrev = false;

   for(int i = 0; i < got; i++)
   {
      out.total++;
      uint fl = ticks[i].flags;

      //--- 왜곡: bid 또는 ask '한쪽만' 갱신된 틱 (스프레드 비정상 확대 근사)
      bool bidUpd = (fl & TICK_FLAG_BID) != 0;
      bool askUpd = (fl & TICK_FLAG_ASK) != 0;
      if(bidUpd != askUpd)   // 정확히 한쪽만 갱신
         out.distort++;

      //--- 매수/매도 판정
      bool counted = false;
      if(useFlag)
      {
         if((fl & TICK_FLAG_BUY) != 0)  { out.up++;   counted = true; }
         if((fl & TICK_FLAG_SELL) != 0) { out.down++; counted = true; }
      }
      if(!counted)  // flag 미제공 → last 근접 추정
      {
         double last = ticks[i].last;
         if(last <= 0.0) last = (ticks[i].bid + ticks[i].ask) / 2.0;
         if(havePrev)
         {
            double dAsk = MathAbs(last - prevAsk);
            double dBid = MathAbs(last - prevBid);
            if(dAsk < dBid)      out.up++;   // 애스크 근접 = 매수
            else if(dBid < dAsk) out.down++; // 비드 근접 = 매도
         }
      }

      if(ticks[i].bid > 0.0) { prevBid = ticks[i].bid; havePrev = true; }
      if(ticks[i].ask > 0.0) { prevAsk = ticks[i].ask; }
   }

   out.valid = true;
   return(true);
}

//------------------------------------------------------------------//
//  브로커가 BUY/SELL flag 를 제공하는지 자동 감지                   |
//  최근 틱을 조금 받아 flag 존재 여부 확인                          |
//------------------------------------------------------------------//
bool BrokerProvidesTradeFlags()
{
   MqlTick ticks[];
   int got = CopyTicks(_Symbol, ticks, COPY_TICKS_ALL, 0, 500);
   if(got <= 0)
      return(false);
   for(int i = 0; i < got; i++)
      if((ticks[i].flags & (TICK_FLAG_BUY | TICK_FLAG_SELL)) != 0)
         return(true);
   return(false);
}

//------------------------------------------------------------------//
//  특정 봉의 [시가시각, 종가시각] 범위 틱 집계                      |
//  shift=0(진행봉)이면 종가시각=현재. shift>=1 이면 다음 봉 시가까지.|
//------------------------------------------------------------------//
bool AggregateBarTicks(const ENUM_TIMEFRAMES tf, const int shift,
                       TickStats &out, const bool useFlag = true)
{
   datetime openT = iTime(_Symbol, tf, shift);
   if(openT == 0)
      return(false);
   datetime closeT;
   if(shift <= 0)
      closeT = TimeCurrent();
   else
      closeT = iTime(_Symbol, tf, shift - 1);  // 다음 봉 시가 = 이 봉 종가
   if(closeT <= openT)
      closeT = openT + PeriodSeconds(tf);
   return(AggregateTicks(openT, closeT - 1, out, useFlag));
}

#endif // ENGULF_TICKS_MQH
//+------------------------------------------------------------------+
