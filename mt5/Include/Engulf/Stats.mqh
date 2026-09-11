//+------------------------------------------------------------------+
//|                                                        Stats.mqh  |
//|   기간별 고저폭 평균 / 방향강도 평균 / 틱볼륨 헬퍼 (PRD §2 A)     |
//+------------------------------------------------------------------+
#property strict
#ifndef ENGULF_STATS_MQH
#define ENGULF_STATS_MQH
#include <Engulf/Common.mqh>

//------------------------------------------------------------------//
//  최근 N개 완성봉의 |방향강도| 평균 (강도 비교 → 절댓값)          |
//  startShift=1 부터 N개 (직전 완성봉들)                            |
//------------------------------------------------------------------//
double AvgDirStrengthAbs(const ENUM_TIMEFRAMES tf, const int count,
                         const int startShift = 1)
{
   double sum = 0.0; int used = 0;
   for(int i = 0; i < count; i++)
   {
      int sh = startShift + i;
      double o = iOpen(_Symbol, tf, sh), h = iHigh(_Symbol, tf, sh);
      double l = iLow(_Symbol, tf, sh),  c = iClose(_Symbol, tf, sh);
      if(o == 0.0) break;
      sum += MathAbs(DirStrength(o, h, l, c, true, true));
      used++;
   }
   return(used > 0 ? sum / used : 0.0);
}

//------------------------------------------------------------------//
//  최근 N개 완성봉의 평균 고저폭(가격). startShift=1                |
//------------------------------------------------------------------//
double AvgRange(const ENUM_TIMEFRAMES tf, const int count, const int startShift = 1)
{
   double sum = 0.0; int used = 0;
   for(int i = 0; i < count; i++)
   {
      int sh = startShift + i;
      double h = iHigh(_Symbol, tf, sh), l = iLow(_Symbol, tf, sh);
      if(h == 0.0) break;
      sum += (h - l);
      used++;
   }
   return(used > 0 ? sum / used : 0.0);
}

//------------------------------------------------------------------//
//  최근 N개 완성봉의 평균 틱볼륨. startShift=1                      |
//------------------------------------------------------------------//
double AvgTickVolume(const ENUM_TIMEFRAMES tf, const int count, const int startShift = 1)
{
   long sum = 0; int used = 0;
   for(int i = 0; i < count; i++)
   {
      int sh = startShift + i;
      long v = iVolume(_Symbol, tf, sh);   // tick volume
      datetime t = iTime(_Symbol, tf, sh);
      if(t == 0) break;
      sum += v;
      used++;
   }
   return(used > 0 ? (double)sum / used : 0.0);
}

//------------------------------------------------------------------//
//  세션 창 [startMinKST, endMinKST] 를 최근 N일 스캔하여            |
//  하루별 (고저폭, 틱볼륨) 을 구해 평균. M5 봉 기반.                |
//  endMin < startMin 이면 자정 넘김(뉴욕전반).                      |
//------------------------------------------------------------------//
void SessionHistAvg(const int startMinKST, const int endMinKST,
                    const int serverToKSTHours, const int days,
                    double &avgRange, double &avgTicks)
{
   avgRange = 0.0; avgTicks = 0.0;
   int used = 0;

   int totalM5 = Bars(_Symbol, PERIOD_M5);
   if(totalM5 <= 0) return;

   // 하루별 누적 버킷 (day offset 0 = 오늘 이전 완성 세션들)
   for(int d = 1; d <= days; d++)
   {
      double hi = -DBL_MAX, lo = DBL_MAX;
      long   tv = 0;
      bool   any = false;

      // 대상 KST 날짜 = 오늘 - d 일
      datetime kstNow = ToKST(TimeCurrent(), serverToKSTHours);
      MqlDateTime kt; TimeToStruct(kstNow, kt);
      kt.hour = 0; kt.min = 0; kt.sec = 0;
      datetime kstMidnight = StructToTime(kt) - (datetime)d * 86400;

      datetime kstStart = kstMidnight + (datetime)startMinKST * 60;
      datetime kstEnd;
      if(endMinKST > startMinKST)
         kstEnd = kstMidnight + (datetime)endMinKST * 60;
      else
         kstEnd = kstMidnight + 86400 + (datetime)endMinKST * 60;  // 자정 넘김

      datetime srvStart = ToServer(kstStart, serverToKSTHours);
      datetime srvEnd   = ToServer(kstEnd,   serverToKSTHours);

      int shStart = iBarShift(_Symbol, PERIOD_M5, srvStart, false);
      int shEnd   = iBarShift(_Symbol, PERIOD_M5, srvEnd,   false);
      if(shStart < 0 || shEnd < 0) continue;

      for(int sh = shStart; sh >= shEnd; sh--)
      {
         double h = iHigh(_Symbol, PERIOD_M5, sh);
         double l = iLow(_Symbol, PERIOD_M5, sh);
         long   v = iVolume(_Symbol, PERIOD_M5, sh);
         if(h == 0.0) continue;
         hi = MathMax(hi, h); lo = MathMin(lo, l); tv += v; any = true;
      }
      if(any && hi > lo)
      {
         avgRange += (hi - lo);
         avgTicks += (double)tv;
         used++;
      }
   }
   if(used > 0) { avgRange /= used; avgTicks /= used; }
}

//------------------------------------------------------------------//
//  현재 세션 누적 고저 / 틱볼륨 (세션 시작 서버시각부터 지금까지)   |
//------------------------------------------------------------------//
void SessionCurrent(const datetime sessStartServer,
                    double &hi, double &lo, long &tv)
{
   hi = -DBL_MAX; lo = DBL_MAX; tv = 0;
   int shStart = iBarShift(_Symbol, PERIOD_M5, sessStartServer, false);
   if(shStart < 0) { hi = 0; lo = 0; return; }
   for(int sh = shStart; sh >= 0; sh--)
   {
      double h = iHigh(_Symbol, PERIOD_M5, sh);
      double l = iLow(_Symbol, PERIOD_M5, sh);
      if(h == 0.0) continue;
      hi = MathMax(hi, h); lo = MathMin(lo, l);
      tv += iVolume(_Symbol, PERIOD_M5, sh);
   }
   if(hi < lo) { hi = 0; lo = 0; }
}

#endif // ENGULF_STATS_MQH
//+------------------------------------------------------------------+
