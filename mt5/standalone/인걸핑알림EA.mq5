//+------------------------------------------------------------------+
//|                                          인걸핑알림EA.mq5         |
//|   인걸핑 알림 + 리테스트 + 텔레그램 전송 (EA, 한 파일 완결판)     |
//|                                                                  |
//|  ※ EA 지만 매매는 하지 않는다. 감시/알림/기록만 한다.            |
//|  텔레그램 전송은 WebRequest 사용 → EA 에서만 가능(지표 불가).      |
//|  도구>옵션>전문가 자문에서 https://api.telegram.org 허용 필요.    |
//+------------------------------------------------------------------+
#property copyright "Engulf Strategy Indicator Set"
#property version   "1.10"
#property strict

//--- 전략 입력 ---------------------------------------------------
input ENUM_TIMEFRAMES InpEngulfTF = PERIOD_H1;  // 인걸핑 감지 프레임
input ENUM_TIMEFRAMES InpRetestTF = PERIOD_M15; // 리테스트 프레임
input int    InpRetestBars   = 4;               // 리테스트 유효 봉 수
input int    InpMaxLegs      = 3;               // 멀티캔들 최대 leg
input bool   InpWickZone     = false;           // 존을 꼬리까지 확장
input int    InpServerToKST  = 7;               // 서버→KST 시차(시간)
input double InpMinScore     = 0;               // 이 점수 미만은 알림 안 함(0=전부)
//--- 알림 채널 ---------------------------------------------------
input bool   InpAlertPopup   = true;   // MT5 팝업 Alert
input bool   InpAlertPush    = false;  // MetaQuotes 모바일 푸시
//--- 텔레그램 ----------------------------------------------------
input bool   InpTgEnable     = false;  // 텔레그램 전송 사용
input string InpTgToken      = "";     // 봇 토큰 (BotFather)
input string InpTgChatId     = "";     // chat_id (getUpdates)
//--- 로그 --------------------------------------------------------
input bool   InpWriteCsv     = true;
input string InpCsvFile      = "engulf_log.csv";
input bool   InpDemoTag      = true;

//==================================================================//
//  공용 함수                                                        //
//==================================================================//
double OnePip(){ return((_Digits==5 || _Digits==3)? _Point*10.0 : _Point); }
double ToPips(const double d){ double p=OnePip(); return(p>0.0? d/p : 0.0); }
double DirStrength(const double open, const double high, const double low,
                   const double close, const bool keepSign=true, const bool asPercent=true)
{
   double range=high-low;
   if(range<=0.0) return(0.0);
   double body=close-open;
   if(!keepSign) body=MathAbs(body);
   double v=body/range;
   return(asPercent? v*100.0 : v);
}
datetime ToKST(const datetime t, const int h){ return(t+(datetime)h*3600); }
int MinuteOfDay(const datetime kst){ MqlDateTime t; TimeToStruct(kst,t); return(t.hour*60+t.min); }

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
   if(m>=540 && m<960)   return(SESSION_ASIA);
   if(m>=960 && m<1140)  return(SESSION_LONDON);
   if(m>=1140 && m<1290) return(SESSION_TRANSIT);
   if(m>=1290 || m<30)   return(SESSION_NY1);
   if(m>=30 && m<360)    return(SESSION_NY2);
   return(SESSION_NONE);
}
ENUM_SESSION CurrentSession(){ return(SessionOfMinute(MinuteOfDay(ToKST(TimeCurrent(),InpServerToKST)))); }
double CurrentPrice()
{
   MqlTick t;
   if(SymbolInfoTick(_Symbol,t)) return((t.bid+t.ask)/2.0);
   return(iClose(_Symbol,PERIOD_M1,0));
}
string TfName(const ENUM_TIMEFRAMES tf)
{
   string s=EnumToString(tf);
   if(StringFind(s,"PERIOD_")==0) s=StringSubstr(s,7);
   return(s);
}
string AccountTag()
{
   if(!InpDemoTag) return("");
   ENUM_ACCOUNT_TRADE_MODE m=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   switch(m){ case ACCOUNT_TRADE_MODE_DEMO:return("DEMO");
              case ACCOUNT_TRADE_MODE_CONTEST:return("CONTEST");
              default:return("REAL"); }
}

//==================================================================//
//  텔레그램 전송 (WebRequest, EA 전용)                              //
//==================================================================//
string JsonEscape(string s)
{
   StringReplace(s,"\\","\\\\");
   StringReplace(s,"\"","\\\"");
   StringReplace(s,"\r","");
   StringReplace(s,"\n","\\n");
   return(s);
}
void SendTelegram(const string text)
{
   if(!InpTgEnable) return;
   if(InpTgToken=="" || InpTgChatId=="")
   {
      Print("텔레그램: 토큰 또는 chat_id 가 비어있음");
      return;
   }
   string url="https://api.telegram.org/bot"+InpTgToken+"/sendMessage";
   string body="{\"chat_id\":\""+InpTgChatId+"\",\"text\":\""+JsonEscape(text)+"\",\"disable_web_page_preview\":true}";
   char post[]; char result[]; string resHeaders;
   int total=StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
   if(total>0) ArrayResize(post, total-1);   // 마지막 널문자 제거
   ResetLastError();
   int res=WebRequest("POST", url, "Content-Type: application/json\r\n", 5000, post, result, resHeaders);
   if(res==-1)
      Print("텔레그램 전송 실패: 오류 ", GetLastError(),
            " — 도구>옵션>전문가 자문에서 https://api.telegram.org 허용을 확인하세요");
   else if(res!=200)
      Print("텔레그램 응답 코드 ", res, ": ", CharArrayToString(result,0,WHOLE_ARRAY,CP_UTF8));
}
// 모든 채널로 한 번에 발송
void Notify(const string text)
{
   if(InpAlertPopup) Alert(text);
   if(InpAlertPush)  SendNotification(text);
   SendTelegram(text);
   Print(text);
}

//==================================================================//
//  틱 집계 (체결 우위)                                              //
//==================================================================//
struct TickStats
{
   long total, up, down, distort;
   bool valid;
   void Reset(){ total=0; up=0; down=0; distort=0; valid=false; }
   double Dominance() const { return(total>0? (double)(up-down)/(double)total*100.0 : 0.0); }
};
bool AggregateTicks(const datetime from, const datetime to, TickStats &out, const bool useFlag)
{
   out.Reset();
   if(to<from) return(false);
   MqlTick ticks[];
   int got=CopyTicksRange(_Symbol,ticks,COPY_TICKS_ALL,(ulong)from*1000,(ulong)to*1000+999);
   if(got<=0) return(false);
   double prevBid=0, prevAsk=0; bool havePrev=false;
   for(int i=0;i<got;i++)
   {
      out.total++;
      uint fl=ticks[i].flags;
      bool bidUpd=(fl&TICK_FLAG_BID)!=0, askUpd=(fl&TICK_FLAG_ASK)!=0;
      if(bidUpd!=askUpd) out.distort++;
      bool counted=false;
      if(useFlag)
      {
         if((fl&TICK_FLAG_BUY)!=0){ out.up++; counted=true; }
         if((fl&TICK_FLAG_SELL)!=0){ out.down++; counted=true; }
      }
      if(!counted)
      {
         double last=ticks[i].last;
         if(last<=0.0) last=(ticks[i].bid+ticks[i].ask)/2.0;
         if(havePrev)
         {
            double dAsk=MathAbs(last-prevAsk), dBid=MathAbs(last-prevBid);
            if(dAsk<dBid) out.up++; else if(dBid<dAsk) out.down++;
         }
      }
      if(ticks[i].bid>0.0){ prevBid=ticks[i].bid; havePrev=true; }
      if(ticks[i].ask>0.0){ prevAsk=ticks[i].ask; }
   }
   out.valid=true;
   return(true);
}
bool BrokerProvidesTradeFlags()
{
   MqlTick ticks[];
   int got=CopyTicks(_Symbol,ticks,COPY_TICKS_ALL,0,500);
   if(got<=0) return(false);
   for(int i=0;i<got;i++)
      if((ticks[i].flags&(TICK_FLAG_BUY|TICK_FLAG_SELL))!=0) return(true);
   return(false);
}
bool AggregateBarTicks(const ENUM_TIMEFRAMES tf, const int shift, TickStats &out, const bool useFlag)
{
   datetime openT=iTime(_Symbol,tf,shift);
   if(openT==0) return(false);
   datetime closeT=(shift<=0)? TimeCurrent() : iTime(_Symbol,tf,shift-1);
   if(closeT<=openT) closeT=openT+PeriodSeconds(tf);
   return(AggregateTicks(openT, closeT-1, out, useFlag));
}

//==================================================================//
//  인걸핑 감지 + 품질 점수                                          //
//==================================================================//
enum ENUM_ENGULF_DIR { ENGULF_NONE=0, ENGULF_BULL=+1, ENGULF_BEAR=-1 };
struct EngulfResult
{
   ENUM_ENGULF_DIR dir;
   int    legs;
   double zoneOpen, zoneClose, engHigh, engLow;
   datetime time;
   void Reset(){ dir=ENGULF_NONE; legs=0; zoneOpen=zoneClose=engHigh=engLow=0.0; time=0; }
};
bool DetectEngulf(const ENUM_TIMEFRAMES tf, const int checkShift, EngulfResult &r, const int maxLegs)
{
   r.Reset();
   double cO=iOpen(_Symbol,tf,checkShift), cC=iClose(_Symbol,tf,checkShift);
   double cH=iHigh(_Symbol,tf,checkShift), cL=iLow(_Symbol,tf,checkShift);
   if(cO==0.0 || cC==0.0) return(false);
   int curDir=(cC>cO)?+1:(cC<cO?-1:0);
   if(curDir==0) return(false);
   double curTop=MathMax(cO,cC), curBot=MathMin(cO,cC);
   double pTop=-DBL_MAX, pBot=DBL_MAX, pHi=-DBL_MAX, pLo=DBL_MAX;
   for(int leg=1; leg<=maxLegs; leg++)
   {
      int sh=checkShift+leg;
      double pO=iOpen(_Symbol,tf,sh), pC=iClose(_Symbol,tf,sh);
      double pH=iHigh(_Symbol,tf,sh), pL=iLow(_Symbol,tf,sh);
      if(pO==0.0) break;
      int pDir=(pC>pO)?+1:(pC<pO?-1:0);
      if(leg>1 && pDir==curDir) break;
      pTop=MathMax(pTop,MathMax(pO,pC)); pBot=MathMin(pBot,MathMin(pO,pC));
      pHi=MathMax(pHi,pH); pLo=MathMin(pLo,pL);
      if(!(curTop>=pTop && curBot<=pBot)) continue;
      bool wickOK=(curDir>0)? (cH>=pHi) : (cL<=pLo);
      if(!wickOK) continue;
      r.dir=(curDir>0)?ENGULF_BULL:ENGULF_BEAR;
      r.legs=leg; r.zoneOpen=cO; r.zoneClose=cC; r.engHigh=cH; r.engLow=cL;
      r.time=iTime(_Symbol,tf,checkShift);
      return(true);
   }
   return(false);
}
bool PriceInZone(const double price, const EngulfResult &r, const bool wickZone)
{
   double top = wickZone? r.engHigh : MathMax(r.zoneOpen,r.zoneClose);
   double bot = wickZone? r.engLow  : MathMin(r.zoneOpen,r.zoneClose);
   return(price<=top && price>=bot);
}
struct QualityScore { double engulfRatio, candleStrength, levelProx, htfAlign, flowAlign, rsi, score; };
double Clamp01(double v){ if(v<0)v=0; if(v>1)v=1; return(v); }
double NormRatio(const double x){ return(Clamp01((x-1.0)/1.0)); }
double NormLevelProx(const double pips){ return(Clamp01((50.0-MathAbs(pips))/45.0)); }
double NormAlign(const double a){ return(Clamp01((a+1.0)/2.0)); }
QualityScore ComputeQuality(const EngulfResult &r, const double prevBody,
                            const double htfSame, const double flowSame,
                            const double levelPips, const double rsi, const double &w[])
{
   QualityScore q; q.rsi=rsi;
   double curBody=MathAbs(r.zoneClose-r.zoneOpen);
   q.engulfRatio=(prevBody>0.0)? curBody/prevBody : 1.0;
   q.candleStrength=DirStrength(r.zoneOpen,r.engHigh,r.engLow,r.zoneClose,false,false);
   q.levelProx=levelPips;
   q.htfAlign=(htfSame>0?+1.0:(htfSame<0?-1.0:0.0));
   q.flowAlign=flowSame;
   double n1=NormRatio(q.engulfRatio), n2=Clamp01(q.candleStrength),
          n3=NormLevelProx(q.levelProx), n4=NormAlign(q.htfAlign), n5=NormAlign(q.flowAlign);
   double ww[5], sum=0; int nn=ArraySize(w);
   for(int i=0;i<5;i++){ ww[i]=(i<nn)?w[i]:0.0; sum+=ww[i]; }
   if(sum<=0.0){ for(int i=0;i<5;i++) ww[i]=1.0; sum=5.0; }
   q.score=(n1*ww[0]+n2*ww[1]+n3*ww[2]+n4*ww[3]+n5*ww[4])/sum*100.0;
   return(q);
}

//==================================================================//
//  보조                                                             //
//==================================================================//
double GetRSI(const ENUM_TIMEFRAMES tf, const int period, const int shift)
{
   int h=iRSI(_Symbol,tf,period,PRICE_CLOSE);
   if(h==INVALID_HANDLE) return(0.0);
   double buf[];
   if(CopyBuffer(h,0,shift,1,buf)<=0){ IndicatorRelease(h); return(0.0); }
   double v=buf[0]; IndicatorRelease(h); return(v);
}
double NearestLevelPips(const double price)
{
   double lv[6]; int c=0;
   lv[c++]=iHigh(_Symbol,PERIOD_D1,1); lv[c++]=iLow(_Symbol,PERIOD_D1,1);
   lv[c++]=iHigh(_Symbol,PERIOD_W1,1); lv[c++]=iLow(_Symbol,PERIOD_W1,1);
   lv[c++]=iOpen(_Symbol,PERIOD_D1,0); lv[c++]=iOpen(_Symbol,PERIOD_W1,0);
   double best=DBL_MAX;
   for(int i=0;i<c;i++){ if(lv[i]<=0)continue; double d=MathAbs(ToPips(price-lv[i])); if(d<best)best=d; }
   return(best==DBL_MAX?999.0:best);
}
double RangePosPct()
{
   int hh=iHighest(_Symbol,PERIOD_H1,MODE_HIGH,120,0);
   int ll=iLowest(_Symbol,PERIOD_H1,MODE_LOW,120,0);
   if(hh<0||ll<0) return(0.0);
   double h=iHigh(_Symbol,PERIOD_H1,hh), l=iLow(_Symbol,PERIOD_H1,ll), p=CurrentPrice();
   return((h>l)?(p-l)/(h-l)*100.0:0.0);
}
string MakeEngulfId(const datetime engTime)
{
   MqlDateTime t; TimeToStruct(ToKST(engTime,InpServerToKST),t);
   return(StringFormat("%s-%04d%02d%02d-%02d%02d",_Symbol,t.year,t.mon,t.day,t.hour,t.min));
}

//==================================================================//
//  상태                                                             //
//==================================================================//
bool     g_rtActive=false;
string   g_rtId="";
EngulfResult g_rtEng;
datetime g_rtStartM15=0;
int      g_rtBars=0;
datetime g_lastEngBar=0;
datetime g_lastM15Bar=0;

//==================================================================//
//  MT5 이벤트 (EA)                                                  //
//==================================================================//
int OnInit()
{
   EventSetTimer(3);
   EnsureCsvHeader();
   Print("인걸핑알림EA 시작 — 텔레그램 ", (InpTgEnable?"ON":"OFF"),
         " / 매매는 하지 않음");
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason) { EventKillTimer(); }
void OnTimer() { CheckEngulf(); TrackRetest(); }
void OnTick()  { CheckEngulf(); TrackRetest(); }

//==================================================================//
//  인걸핑 감지                                                      //
//==================================================================//
void CheckEngulf()
{
   datetime b1=iTime(_Symbol,InpEngulfTF,1);
   if(b1==0 || b1==g_lastEngBar) return;
   g_lastEngBar=b1;

   EngulfResult r;
   if(!DetectEngulf(InpEngulfTF,1,r,InpMaxLegs)) return;

   double prevBody=MathAbs(iClose(_Symbol,InpEngulfTF,2)-iOpen(_Symbol,InpEngulfTF,2));
   double h4dir=DirStrength(iOpen(_Symbol,PERIOD_H4,1),iHigh(_Symbol,PERIOD_H4,1),
                            iLow(_Symbol,PERIOD_H4,1),iClose(_Symbol,PERIOD_H4,1),true,true);
   double htfSame=(h4dir*(double)r.dir>0)?+1:(h4dir*(double)r.dir<0?-1:0);

   bool useFlag=BrokerProvidesTradeFlags();
   TickStats ts; AggregateBarTicks(InpEngulfTF,1,ts,useFlag);
   double dom=ts.Dominance();
   double flowSame=0;
   if(ts.valid && ts.total>0)
      flowSame=(dom*(double)r.dir>0)?+1:(dom*(double)r.dir<0?-1:0);

   double levelDist=NearestLevelPips((r.zoneOpen+r.zoneClose)/2.0);
   double rsi=GetRSI(InpEngulfTF,14,1);
   double w[5]; ArrayInitialize(w,0);   // 균등 가중치
   QualityScore q=ComputeQuality(r,prevBody,htfSame,flowSame,levelDist,rsi,w);

   double posPct=RangePosPct();
   double wkChg=ToPips(CurrentPrice()-iOpen(_Symbol,PERIOD_W1,0));
   string id=MakeEngulfId(r.time);

   // CSV 는 점수 무관하게 항상 기록 (신호 분석용)
   if(InpWriteCsv)
      LogEngulf(id,r,q,rsi,SessionName(CurrentSession()),h4dir,posPct,wkChg,dom,ts.valid);

   // 알림은 최소 점수 이상만
   if(q.score < InpMinScore)
   {
      g_rtActive=true; g_rtId=id; g_rtEng=r;
      g_rtStartM15=iTime(_Symbol,InpRetestTF,0); g_rtBars=0;
      return;
   }

   datetime kstNow=ToKST(TimeCurrent(),InpServerToKST);
   string dirIcon=(r.dir==ENGULF_BULL?"🟢 상승(롱)":"🔴 하락(숏)");

   // 가독성 좋은 여러 줄 메시지
   string msg=StringFormat(
      "🔔 %s 인걸핑 발생\n"
      "━━━━━━━━━━━━━\n"
      "방향   : %s\n"
      "시각   : %s KST (%s)\n"
      "품질점수: %.0f 점\n"
      "RSI    : %.1f\n"
      "존(진입범위): %s ~ %s\n"
      "H4방향 일치 : %s\n"
      "체결 우위 일치: %s\n"
      "5일 위치: %.0f%%\n"
      "━━━━━━━━━━━━━\n"
      "→ M15 %d개 안에 존으로 되돌아오면 리테스트 알림",
      _Symbol, dirIcon,
      TimeToString(kstNow, TIME_MINUTES), SessionName(CurrentSession()),
      q.score, rsi,
      DoubleToString(r.zoneOpen,_Digits), DoubleToString(r.zoneClose,_Digits),
      (htfSame>0?"✅":"❌"),
      (flowSame>0?"✅":(ts.valid?"❌":"—")),
      posPct, InpRetestBars);

   Notify(msg);

   g_rtActive=true; g_rtId=id; g_rtEng=r;
   g_rtStartM15=iTime(_Symbol,InpRetestTF,0); g_rtBars=0;
}

//==================================================================//
//  리테스트 추적                                                    //
//==================================================================//
void TrackRetest()
{
   if(!g_rtActive) return;
   datetime m15=iTime(_Symbol,InpRetestTF,0);
   if(m15!=g_lastM15Bar)
   {
      g_lastM15Bar=m15;
      if(m15>g_rtStartM15) g_rtBars++;
   }
   double price=CurrentPrice();
   if(PriceInZone(price,g_rtEng,InpWickZone))
   {
      double zTop=MathMax(g_rtEng.zoneOpen,g_rtEng.zoneClose);
      double zBot=MathMin(g_rtEng.zoneOpen,g_rtEng.zoneClose);
      double entry,sl,tp;
      if(g_rtEng.dir==ENGULF_BULL)
      {
         entry=zBot+(zTop-zBot)*0.5; sl=g_rtEng.zoneOpen-OnePip(); tp=entry+(entry-sl)*2.0;
      }
      else
      {
         entry=zTop-(zTop-zBot)*0.5; sl=g_rtEng.zoneOpen+OnePip(); tp=entry-(sl-entry)*2.0;
      }
      string dirIcon=(g_rtEng.dir==ENGULF_BULL?"🟢 상승(롱)":"🔴 하락(숏)");
      string msg=StringFormat(
         "✅ 리테스트 도달 (%d/%d)\n"
         "━━━━━━━━━━━━━\n"
         "%s %s\n"
         "진입 후보: %s\n"
         "손절     : %s\n"
         "익절     : %s  (손익비 2:1)\n"
         "━━━━━━━━━━━━━\n"
         "※ 진입은 캔들 보고 직접 판단",
         g_rtBars+1, InpRetestBars, _Symbol, dirIcon,
         DoubleToString(entry,_Digits), DoubleToString(sl,_Digits), DoubleToString(tp,_Digits));
      Notify(msg);
      UpdateEngulfRetest(g_rtId, g_rtBars+1);
      g_rtActive=false;
      return;
   }
   if(g_rtBars>=InpRetestBars)
   {
      Print(StringFormat("⛔ [리테스트 무효] %s — M15 %d개 안에 재진입 없음", g_rtId, InpRetestBars));
      UpdateEngulfRetest(g_rtId, -1);
      g_rtActive=false;
   }
}

//==================================================================//
//  CSV 기록                                                         //
//==================================================================//
void EnsureCsvHeader()
{
   if(!InpWriteCsv) return;
   if(FileIsExist(InpCsvFile)) return;
   int h=FileOpen(InpCsvFile, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(h==INVALID_HANDLE){ Print("CSV 헤더 생성 실패: ",GetLastError()); return; }
   FileWrite(h,"engulf_id","time_kst","symbol","dir","zone_open","zone_close",
             "score","q_ratio","q_candle","q_levelpip","q_htf","q_flow",
             "rsi","session","h4_dir","pos_pct","wk_chg_pip","flow_dom","account",
             "retest_bar","entered");
   FileClose(h);
}
void LogEngulf(const string id, const EngulfResult &r, const QualityScore &q,
               const double rsi, const string session, const double h4dir,
               const double posPct, const double wkChg, const double dom, const bool flowValid)
{
   int h=FileOpen(InpCsvFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(h==INVALID_HANDLE){ Print("CSV 열기 실패: ",GetLastError()); return; }
   FileSeek(h,0,SEEK_END);
   datetime kst=ToKST(r.time,InpServerToKST);
   FileWrite(h, id, TimeToString(kst,TIME_DATE|TIME_MINUTES), _Symbol,
             (r.dir==ENGULF_BULL?"상승":"하락"),
             DoubleToString(r.zoneOpen,_Digits), DoubleToString(r.zoneClose,_Digits),
             DoubleToString(q.score,1), DoubleToString(q.engulfRatio,2),
             DoubleToString(q.candleStrength,3), DoubleToString(q.levelProx,1),
             DoubleToString(q.htfAlign,0), DoubleToString(q.flowAlign,0),
             DoubleToString(rsi,1), session, DoubleToString(h4dir,1),
             DoubleToString(posPct,0), DoubleToString(wkChg,1),
             (flowValid?DoubleToString(dom,1):"NA"), AccountTag(), "", "N");
   FileClose(h);
}
void UpdateEngulfRetest(const string id, const int retestBar)
{
   if(!InpWriteCsv) return;
   int h=FileOpen(InpCsvFile, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWrite(h, id, "RETEST_UPDATE", _Symbol, "", "", "", "", "", "", "", "", "",
             "", "", "", "", "", "", AccountTag(),
             (retestBar<0?"무효":IntegerToString(retestBar)), "");
   FileClose(h);
}
//+------------------------------------------------------------------+
