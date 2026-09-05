//+------------------------------------------------------------------+
//|                                          인걸핑알림EA.mq5         |
//|   PIPxLOT 현황(방향강도+체결) + 인걸핑 알림 + 리테스트           |
//|   → 텔레그램 전송(고정폭 표) + 웹 대시보드용 JSON 전송(Pantry)   |
//|   ※ EA 지만 매매는 하지 않는다. 감시/알림/기록만.                |
//|   WebRequest 사용 → 도구>옵션>전문가 자문에서 아래 허용 필요:     |
//|     https://api.telegram.org , https://getpantry.cloud           |
//+------------------------------------------------------------------+
#property copyright "Engulf Strategy Indicator Set"
#property version   "2.10"
#property strict

//--- 전략 입력 ---------------------------------------------------
input ENUM_TIMEFRAMES InpEngulfTF = PERIOD_H1;  // 인걸핑 감지 프레임
input ENUM_TIMEFRAMES InpRetestTF = PERIOD_M15; // 리테스트 프레임
input int    InpRetestBars   = 4;               // 리테스트 유효 봉 수
input int    InpMaxLegs      = 3;               // 멀티캔들 최대 leg
input bool   InpWickZone     = false;           // 존을 꼬리까지 확장
input int    InpServerToKST  = 7;               // 서버→KST 시차(시간)
input double InpMinScore     = 0;               // 이 점수 미만은 알림 안 함
//--- 단위 --------------------------------------------------------
input double InpPtOverride   = 0;               // pt 크기 수동(0=자동: 금 1.0 / FX 1핍)
//--- 레벨/평균 ---------------------------------------------------
input int    InpSessDays     = 5;               // 세션/일간 평균 일수
input int    InpWeekWeeks     = 4;              // 주간 평균 주수
input double InpLevelMid       = 0.5;           // 세션 1차레벨 배율
input double InpLevelFull      = 1.0;           // 세션 최종레벨 배율
input ENUM_TIMEFRAMES InpFlowEntryTF = PERIOD_M5;  // 체결 진입 프레임
input ENUM_TIMEFRAMES InpFlowZoneTF  = PERIOD_H1;  // 체결 자리 프레임
input int    InpZoneBars      = 3;              // 자리 프레임 시계열 과거 봉 수
//--- 알림 채널 ---------------------------------------------------
input bool   InpAlertPopup   = true;            // MT5 팝업
input bool   InpAlertPush    = false;           // MetaQuotes 모바일 푸시
//--- 텔레그램 ----------------------------------------------------
input bool   InpTgEnable     = false;
input string InpTgToken      = "";
input string InpTgChatId     = "";
//--- 현황 전송 주기 ---------------------------------------------
input bool   InpStatusEnable = true;            // 현황 전송 사용
input int    InpStatusMin    = 60;              // 텔레그램 현황 주기(분)
//--- 웹 대시보드 (Pantry JSON) ---------------------------------
input bool   InpDashEnable   = false;           // 대시보드 JSON 전송 사용
input string InpDashUrl      = "";              // Pantry basket URL(POST)
input int    InpDashSec      = 30;              // 대시보드 갱신 주기(초)
//--- 로그 --------------------------------------------------------
input bool   InpWriteCsv     = true;
input string InpCsvFile      = "engulf_log.csv";
input bool   InpDemoTag      = true;

//--- 전역(단위) --------------------------------------------------
bool   g_metal=false;
double g_ptSize=0.0001;
string g_cur="";
string g_unit="핍";

//==================================================================//
//  공용                                                             //
//==================================================================//
double OnePip(){ return((_Digits==5 || _Digits==3)? _Point*10.0 : _Point); }
void   InitUnit()
{
   g_metal = (_Digits<=2);
   g_ptSize = (InpPtOverride>0)? InpPtOverride : (g_metal? 1.0 : OnePip());
   g_cur  = g_metal? "$" : "";
   g_unit = g_metal? "$" : "핍";
}
double ToPt(const double diff){ return(g_ptSize>0? diff/g_ptSize : 0); }
double DirStrength(const double open,const double high,const double low,const double close,
                   const bool keepSign=true,const bool asPercent=true)
{
   double range=high-low; if(range<=0.0) return(0.0);
   double body=close-open; if(!keepSign) body=MathAbs(body);
   double v=body/range; return(asPercent? v*100.0 : v);
}
datetime ToKST(const datetime t,const int h){ return(t+(datetime)h*3600); }
datetime ToServer(const datetime k,const int h){ return(k-(datetime)h*3600); }
int MinuteOfDay(const datetime kst){ MqlDateTime t; TimeToStruct(kst,t); return(t.hour*60+t.min); }
double ElapsedRatio(const datetime bo,const datetime now,const int ps){ if(ps<=0)return(0.0); double r=(double)(now-bo)/(double)ps; if(r<0)r=0; if(r>1)r=1; return(r); }
double CurrentPrice(){ MqlTick t; if(SymbolInfoTick(_Symbol,t)) return((t.bid+t.ask)/2.0); return(iClose(_Symbol,PERIOD_M1,0)); }

enum ENUM_SESSION { SESSION_NONE=0, SESSION_ASIA, SESSION_LONDON, SESSION_TRANSIT, SESSION_NY1, SESSION_NY2 };
string SessionName(const ENUM_SESSION s)
{
   switch(s){ case SESSION_ASIA:return("아시아"); case SESSION_LONDON:return("런던 본장");
              case SESSION_TRANSIT:return("전환"); case SESSION_NY1:return("뉴욕 전반");
              case SESSION_NY2:return("뉴욕 후반"); default:return("휴장/대기"); }
}
ENUM_SESSION SessionOfMinute(const int m)
{
   if(m>=540 && m<960) return(SESSION_ASIA);
   if(m>=960 && m<1140) return(SESSION_LONDON);
   if(m>=1140 && m<1290) return(SESSION_TRANSIT);
   if(m>=1290 || m<30) return(SESSION_NY1);
   if(m>=30 && m<360) return(SESSION_NY2);
   return(SESSION_NONE);
}
int SessionStartMinute(const ENUM_SESSION s){ switch(s){case SESSION_ASIA:return(540);case SESSION_LONDON:return(960);case SESSION_TRANSIT:return(1140);case SESSION_NY1:return(1290);case SESSION_NY2:return(30);default:return(360);} }
int SessionEndMinute(const ENUM_SESSION s){ switch(s){case SESSION_ASIA:return(960);case SESSION_LONDON:return(1140);case SESSION_TRANSIT:return(1290);case SESSION_NY1:return(30);case SESSION_NY2:return(360);default:return(540);} }
ENUM_SESSION CurrentSession(){ return(SessionOfMinute(MinuteOfDay(ToKST(TimeCurrent(),InpServerToKST)))); }
ENUM_SESSION CurrentSessionStart(datetime &sessStartServer)
{
   datetime kstNow=ToKST(TimeCurrent(),InpServerToKST);
   int m=MinuteOfDay(kstNow); ENUM_SESSION s=SessionOfMinute(m);
   MqlDateTime kt; TimeToStruct(kstNow,kt); kt.hour=0;kt.min=0;kt.sec=0;
   datetime kstStart=StructToTime(kt)+(datetime)SessionStartMinute(s)*60;
   if(s==SESSION_NY1 && m<30) kstStart-=86400;
   sessStartServer=ToServer(kstStart,InpServerToKST);
   return(s);
}
string TfName(const ENUM_TIMEFRAMES tf){ string s=EnumToString(tf); if(StringFind(s,"PERIOD_")==0) s=StringSubstr(s,7); return(s); }
string AccountTag(){ if(!InpDemoTag)return(""); ENUM_ACCOUNT_TRADE_MODE m=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   switch(m){case ACCOUNT_TRADE_MODE_DEMO:return("DEMO");case ACCOUNT_TRADE_MODE_CONTEST:return("CONTEST");default:return("REAL");} }

//--- 표시 포맷
string SignStr(const double v,const int d=1){ string s=DoubleToString(v,d); if(v>0.0)s="+"+s; return(s); }
string PhaseStr(const double a,const double avg){ return(a>avg?"추세":"횡보"); }
string FmtPrice(const double p){ return(g_cur+DoubleToString(p,_Digits)); }
string FmtPtAbs(const double diff,const int d=1){ return(DoubleToString(MathAbs(ToPt(diff)),d)+" pt"); }
string FmtPtSgn(const double diff,const int d=1){ return(SignStr(ToPt(diff),d)+" pt"); }
string FmtMove(const double diff,const int d=2)   // 실이동/흔들림
{
   if(g_metal) return((diff<0?"-":"+")+g_cur+DoubleToString(MathAbs(diff),d));
   return(SignStr(diff/OnePip(),1)+"핍");
}
string FmtPerTick(const double raw,const int d=5)  // 틱당 실이동
{
   if(g_metal) return((raw<0?"-":"+")+g_cur+DoubleToString(MathAbs(raw),d));
   return(SignStr(raw/OnePip(),3)+"핍");
}
string Bar10(const double pct)
{
   int n=(int)MathRound(MathMax(0,MathMin(100,pct))/10.0); string s="";
   for(int i=0;i<10;i++) s+=(i<n?"■":"□"); return("["+s+"]");
}

//==================================================================//
//  틱 집계                                                          //
//==================================================================//
struct TickStats{ long total,up,down,distort; bool valid;
   void Reset(){total=0;up=0;down=0;distort=0;valid=false;}
   double Dominance() const { return(total>0? (double)(up-down)/(double)total*100.0:0.0); } };
bool AggregateTicks(const datetime from,const datetime to,TickStats &o,const bool useFlag)
{
   o.Reset(); if(to<from) return(false);
   MqlTick tk[]; int got=CopyTicksRange(_Symbol,tk,COPY_TICKS_ALL,(ulong)from*1000,(ulong)to*1000+999);
   if(got<=0) return(false);
   double pb=0,pa=0; bool hp=false;
   for(int i=0;i<got;i++){
      o.total++; uint fl=tk[i].flags;
      bool bu=(fl&TICK_FLAG_BID)!=0, au=(fl&TICK_FLAG_ASK)!=0; if(bu!=au) o.distort++;
      bool c=false;
      if(useFlag){ if((fl&TICK_FLAG_BUY)!=0){o.up++;c=true;} if((fl&TICK_FLAG_SELL)!=0){o.down++;c=true;} }
      if(!c){ double l=tk[i].last; if(l<=0.0)l=(tk[i].bid+tk[i].ask)/2.0;
         if(hp){ double da=MathAbs(l-pa),db=MathAbs(l-pb); if(da<db)o.up++; else if(db<da)o.down++; } }
      if(tk[i].bid>0.0){pb=tk[i].bid;hp=true;} if(tk[i].ask>0.0)pa=tk[i].ask;
   }
   o.valid=true; return(true);
}
bool BrokerProvidesTradeFlags(){ MqlTick tk[]; int g=CopyTicks(_Symbol,tk,COPY_TICKS_ALL,0,500);
   if(g<=0)return(false); for(int i=0;i<g;i++) if((tk[i].flags&(TICK_FLAG_BUY|TICK_FLAG_SELL))!=0)return(true); return(false); }
bool AggregateBarTicks(const ENUM_TIMEFRAMES tf,const int shift,TickStats &o,const bool useFlag)
{
   datetime ot=iTime(_Symbol,tf,shift); if(ot==0)return(false);
   datetime ct=(shift<=0)?TimeCurrent():iTime(_Symbol,tf,shift-1); if(ct<=ot)ct=ot+PeriodSeconds(tf);
   return(AggregateTicks(ot,ct-1,o,useFlag));
}

//==================================================================//
//  인걸핑 + 품질                                                    //
//==================================================================//
enum ENUM_ENGULF_DIR { ENGULF_NONE=0, ENGULF_BULL=+1, ENGULF_BEAR=-1 };
struct EngulfResult{ ENUM_ENGULF_DIR dir; int legs; double zoneOpen,zoneClose,engHigh,engLow; datetime time;
   void Reset(){dir=ENGULF_NONE;legs=0;zoneOpen=zoneClose=engHigh=engLow=0.0;time=0;} };
bool DetectEngulf(const ENUM_TIMEFRAMES tf,const int cs,EngulfResult &r,const int maxLegs)
{
   r.Reset();
   double cO=iOpen(_Symbol,tf,cs),cC=iClose(_Symbol,tf,cs),cH=iHigh(_Symbol,tf,cs),cL=iLow(_Symbol,tf,cs);
   if(cO==0.0||cC==0.0)return(false);
   int cur=(cC>cO)?+1:(cC<cO?-1:0); if(cur==0)return(false);
   double cT=MathMax(cO,cC),cB=MathMin(cO,cC),pT=-DBL_MAX,pB=DBL_MAX,pH=-DBL_MAX,pL=DBL_MAX;
   for(int leg=1;leg<=maxLegs;leg++){
      int sh=cs+leg; double pO=iOpen(_Symbol,tf,sh),pC=iClose(_Symbol,tf,sh),ph=iHigh(_Symbol,tf,sh),pl=iLow(_Symbol,tf,sh);
      if(pO==0.0)break; int pd=(pC>pO)?+1:(pC<pO?-1:0); if(leg>1&&pd==cur)break;
      pT=MathMax(pT,MathMax(pO,pC));pB=MathMin(pB,MathMin(pO,pC));pH=MathMax(pH,ph);pL=MathMin(pL,pl);
      if(!(cT>=pT&&cB<=pB))continue;
      bool wick=(cur>0)?(cH>=pH):(cL<=pL); if(!wick)continue;
      r.dir=(cur>0)?ENGULF_BULL:ENGULF_BEAR; r.legs=leg; r.zoneOpen=cO; r.zoneClose=cC; r.engHigh=cH; r.engLow=cL;
      r.time=iTime(_Symbol,tf,cs); return(true);
   }
   return(false);
}
bool PriceInZone(const double p,const EngulfResult &r,const bool wick)
{ double top=wick?r.engHigh:MathMax(r.zoneOpen,r.zoneClose); double bot=wick?r.engLow:MathMin(r.zoneOpen,r.zoneClose);
  return(p<=top&&p>=bot); }
struct QualityScore{ double engulfRatio,candleStrength,levelProx,htfAlign,flowAlign,rsi,score; };
double Clamp01(double v){ if(v<0)v=0; if(v>1)v=1; return(v); }
double NormRatio(const double x){ return(Clamp01((x-1.0)/1.0)); }
double NormLevelProx(const double p){ return(Clamp01((50.0-MathAbs(p))/45.0)); }
double NormAlign(const double a){ return(Clamp01((a+1.0)/2.0)); }
QualityScore ComputeQuality(const EngulfResult &r,const double prevBody,const double htf,const double flow,
                            const double lvpip,const double rsi,const double &w[])
{
   QualityScore q; q.rsi=rsi;
   double cb=MathAbs(r.zoneClose-r.zoneOpen); q.engulfRatio=(prevBody>0.0)?cb/prevBody:1.0;
   q.candleStrength=DirStrength(r.zoneOpen,r.engHigh,r.engLow,r.zoneClose,false,false);
   q.levelProx=lvpip; q.htfAlign=(htf>0?1:(htf<0?-1:0)); q.flowAlign=flow;
   double n1=NormRatio(q.engulfRatio),n2=Clamp01(q.candleStrength),n3=NormLevelProx(q.levelProx),n4=NormAlign(q.htfAlign),n5=NormAlign(q.flowAlign);
   double ww[5],sum=0; int nn=ArraySize(w); for(int i=0;i<5;i++){ww[i]=(i<nn)?w[i]:0.0;sum+=ww[i];}
   if(sum<=0.0){for(int i=0;i<5;i++)ww[i]=1.0;sum=5.0;}
   q.score=(n1*ww[0]+n2*ww[1]+n3*ww[2]+n4*ww[3]+n5*ww[4])/sum*100.0; return(q);
}
double GetRSI(const ENUM_TIMEFRAMES tf,const int per,const int sh){ int h=iRSI(_Symbol,tf,per,PRICE_CLOSE);
   if(h==INVALID_HANDLE)return(0.0); double b[]; if(CopyBuffer(h,0,sh,1,b)<=0){IndicatorRelease(h);return(0.0);} double v=b[0];IndicatorRelease(h);return(v); }
double NearestLevelPips(const double p){ double lv[6]; int c=0;
   lv[c++]=iHigh(_Symbol,PERIOD_D1,1);lv[c++]=iLow(_Symbol,PERIOD_D1,1);lv[c++]=iHigh(_Symbol,PERIOD_W1,1);lv[c++]=iLow(_Symbol,PERIOD_W1,1);
   lv[c++]=iOpen(_Symbol,PERIOD_D1,0);lv[c++]=iOpen(_Symbol,PERIOD_W1,0); double best=DBL_MAX;
   for(int i=0;i<c;i++){ if(lv[i]<=0)continue; double d=MathAbs(ToPt(p-lv[i])); if(d<best)best=d; } return(best==DBL_MAX?999.0:best); }
double RangePosPct(){ int hh=iHighest(_Symbol,PERIOD_H1,MODE_HIGH,120,0),ll=iLowest(_Symbol,PERIOD_H1,MODE_LOW,120,0);
   if(hh<0||ll<0)return(0.0); double h=iHigh(_Symbol,PERIOD_H1,hh),l=iLow(_Symbol,PERIOD_H1,ll),p=CurrentPrice();
   return((h>l)?(p-l)/(h-l)*100.0:0.0); }
string MakeEngulfId(const datetime et){ MqlDateTime t; TimeToStruct(ToKST(et,InpServerToKST),t);
   return(StringFormat("%s-%04d%02d%02d-%02d%02d",_Symbol,t.year,t.mon,t.day,t.hour,t.min)); }

//==================================================================//
//  기간 통계 (추세율평균 / 상방·하방 평균폭 / 틱볼륨평균)          //
//==================================================================//
double AvgTrend(const ENUM_TIMEFRAMES tf,const int count)   // |방향강도| 평균
{ double s=0; int u=0; for(int i=1;i<=count;i++){ double o=iOpen(_Symbol,tf,i),h=iHigh(_Symbol,tf,i),l=iLow(_Symbol,tf,i),c=iClose(_Symbol,tf,i);
   if(o==0.0)break; s+=MathAbs(DirStrength(o,h,l,c,true,true)); u++; } return(u>0?s/u:0.0); }
void AvgUpDn(const ENUM_TIMEFRAMES tf,const int count,double &avgUp,double &avgDn)  // 상방·하방 평균폭(가격)
{ double su=0,sd=0; int u=0; for(int i=1;i<=count;i++){ double o=iOpen(_Symbol,tf,i),h=iHigh(_Symbol,tf,i),l=iLow(_Symbol,tf,i);
   if(o==0.0)break; su+=(h-o); sd+=(o-l); u++; } avgUp=(u>0?su/u:0.0); avgDn=(u>0?sd/u:0.0); }
double AvgTickVol(const ENUM_TIMEFRAMES tf,const int count)
{ long s=0; int u=0; for(int i=1;i<=count;i++){ if(iTime(_Symbol,tf,i)==0)break; s+=iVolume(_Symbol,tf,i); u++; } return(u>0?(double)s/u:0.0); }

// 현재 세션 누적 (M5)
void SessionCurrent(const datetime st,double &hi,double &lo,double &op,long &tv)
{ hi=-DBL_MAX; lo=DBL_MAX; tv=0; op=0;
  int s0=iBarShift(_Symbol,PERIOD_M5,st,false); if(s0<0){hi=0;lo=0;return;}
  op=iOpen(_Symbol,PERIOD_M5,s0);
  for(int sh=s0; sh>=0; sh--){ double h=iHigh(_Symbol,PERIOD_M5,sh),l=iLow(_Symbol,PERIOD_M5,sh); if(h==0.0)continue;
     hi=MathMax(hi,h); lo=MathMin(lo,l); tv+=iVolume(_Symbol,PERIOD_M5,sh); }
  if(hi<lo){hi=0;lo=0;} }
// 세션 히스토리 평균 (추세율/상방/하방/틱)
void SessionHist(const int sm,const int em,const int days,
                 double &avgTrend,double &avgUp,double &avgDn,double &avgTick)
{ avgTrend=0;avgUp=0;avgDn=0;avgTick=0; int used=0;
  if(Bars(_Symbol,PERIOD_M5)<=0) return;
  for(int d=1; d<=days; d++){
     double hi=-DBL_MAX,lo=DBL_MAX,op=0,cl=0; long tv=0; bool any=false;
     datetime kstNow=ToKST(TimeCurrent(),InpServerToKST); MqlDateTime kt; TimeToStruct(kstNow,kt); kt.hour=0;kt.min=0;kt.sec=0;
     datetime mid=StructToTime(kt)-(datetime)d*86400;
     datetime ks=mid+(datetime)sm*60, ke=(em>sm)? mid+(datetime)em*60 : mid+86400+(datetime)em*60;
     int shS=iBarShift(_Symbol,PERIOD_M5,ToServer(ks,InpServerToKST),false), shE=iBarShift(_Symbol,PERIOD_M5,ToServer(ke,InpServerToKST),false);
     if(shS<0||shE<0)continue;
     op=iOpen(_Symbol,PERIOD_M5,shS);
     for(int sh=shS; sh>=shE; sh--){ double h=iHigh(_Symbol,PERIOD_M5,sh),l=iLow(_Symbol,PERIOD_M5,sh); if(h==0.0)continue;
        hi=MathMax(hi,h); lo=MathMin(lo,l); cl=iClose(_Symbol,PERIOD_M5,sh); tv+=iVolume(_Symbol,PERIOD_M5,sh); any=true; }
     if(any && hi>lo){ avgTrend+=MathAbs(DirStrength(op,hi,lo,cl,true,true)); avgUp+=(hi-op); avgDn+=(op-lo); avgTick+=(double)tv; used++; }
  }
  if(used>0){ avgTrend/=used; avgUp/=used; avgDn/=used; avgTick/=used; }
}
// 도달률 + 문구 (가격 이동한 쪽 레벨 기준)
void ReachInfo(const double op,const double px,const double up,const double dn,
               double &reach,string &txt,int &sideDir)
{ bool upside=(px>=op); double lvl=upside?up:dn; double den=lvl-op;
  reach=(MathAbs(den)<_Point)?0:(px-op)/den*100.0; sideDir=upside?+1:-1;
  string side=upside?"상단":"하단";
  if(reach<100.0){ double rem=MathAbs(lvl-px); txt=side+" 잔여 +"+DoubleToString(ToPt(rem),1)+"pt"; }
  else{ double ov=MathAbs(px-lvl); txt=side+" 돌파 -"+DoubleToString(ToPt(ov),1)+"pt 초과"; }
}

//==================================================================//
//  텔레그램 전송                                                    //
//==================================================================//
string JsonEscape(string s){ StringReplace(s,"\\","\\\\"); StringReplace(s,"\"","\\\""); StringReplace(s,"\r",""); StringReplace(s,"\n","\\n"); return(s); }
string HtmlEscape(string s){ StringReplace(s,"&","&amp;"); StringReplace(s,"<","&lt;"); StringReplace(s,">","&gt;"); return(s); }
void SendTelegram(const string text,const bool asPre=false)
{
   if(!InpTgEnable) return;
   if(InpTgToken=="" || InpTgChatId==""){ Print("텔레그램: 토큰/chat_id 비어있음"); return; }
   string url="https://api.telegram.org/bot"+InpTgToken+"/sendMessage";
   string body = asPre
     ? "{\"chat_id\":\""+InpTgChatId+"\",\"text\":\""+JsonEscape("<pre>"+HtmlEscape(text)+"</pre>")+"\",\"parse_mode\":\"HTML\",\"disable_web_page_preview\":true}"
     : "{\"chat_id\":\""+InpTgChatId+"\",\"text\":\""+JsonEscape(text)+"\",\"disable_web_page_preview\":true}";
   char post[]; char res[]; string rh; int tot=StringToCharArray(body,post,0,WHOLE_ARRAY,CP_UTF8); if(tot>0)ArrayResize(post,tot-1);
   ResetLastError();
   int r=WebRequest("POST",url,"Content-Type: application/json\r\n",5000,post,res,rh);
   if(r==-1) Print("텔레그램 실패 오류 ",GetLastError()," — api.telegram.org WebRequest 허용 확인");
   else if(r!=200) Print("텔레그램 응답 ",r,": ",CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8));
}
void Notify(const string t){ if(InpAlertPopup)Alert(t); if(InpAlertPush)SendNotification(t); SendTelegram(t); Print(t); }
void SendDashboard(const string json)
{
   if(!InpDashEnable || InpDashUrl=="") return;
   char post[]; char res[]; string rh; int tot=StringToCharArray(json,post,0,WHOLE_ARRAY,CP_UTF8); if(tot>0)ArrayResize(post,tot-1);
   ResetLastError();
   int r=WebRequest("POST",InpDashUrl,"Content-Type: application/json\r\n",5000,post,res,rh);
   if(r==-1) Print("대시보드 전송 실패 오류 ",GetLastError()," — getpantry.cloud WebRequest 허용 확인");
   else if(r!=200 && r!=201) Print("대시보드 응답 ",r);
}

//==================================================================//
//  상태                                                             //
//==================================================================//
bool g_rtActive=false; string g_rtId=""; EngulfResult g_rtEng;
datetime g_rtStartM15=0; int g_rtBars=0; datetime g_lastEngBar=0,g_lastM15Bar=0,g_lastStatus=0,g_lastDash=0;
bool g_rtLeftZone=false;

//==================================================================//
//  MT5 이벤트                                                       //
//==================================================================//
int OnInit()
{
   InitUnit();
   EventSetTimer(3);
   EnsureCsvHeader();
   Print("인걸핑알림EA v2.00 — 단위 ",(g_metal?"금($/pt)":"FX(핍)"),
         " | 텔레그램 ",(InpTgEnable?"ON":"OFF")," | 대시보드 ",(InpDashEnable?"ON":"OFF")," | 매매안함");
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){ EventKillTimer(); }
void OnTimer()
{
   CheckEngulf(); TrackRetest();
   if(InpStatusEnable && InpStatusMin>0 && (g_lastStatus==0 || (TimeCurrent()-g_lastStatus)>=(datetime)InpStatusMin*60))
   { g_lastStatus=TimeCurrent(); SendTelegram(BuildStatusText(), true); }
   if(InpDashEnable && InpDashSec>0 && (g_lastDash==0 || (TimeCurrent()-g_lastDash)>=(datetime)InpDashSec))
   { g_lastDash=TimeCurrent(); SendDashboard(BuildStatusJson()); }
}
void OnTick(){ CheckEngulf(); TrackRetest(); }

//==================================================================//
//  현황 계산 (텔레그램 텍스트 + JSON 공용 로직)                     //
//==================================================================//
// 한 기간 계산 결과
struct PeriodData{
   double open,hi,lo,chgpct,range,oc,strength,trend,avg,tickpct; long tickcnt;
   // 레벨(최대 2개: 세션은 1차/최종, 그 외 1개)
   int    nlvl;
   string lname[2]; double lup[2],ldn[2],luppt[2],ldnpt[2],lreach[2]; string ltxt[2]; int ldir[2];
};
void CalcPeriod(const ENUM_TIMEFRAMES tf,const int avgN,const bool isSession,const datetime sessStart,
                const ENUM_SESSION sess,const double price,PeriodData &d)
{
   double avgUp=0,avgDn=0; d.nlvl=0;
   if(isSession){
      long tv; SessionCurrent(sessStart,d.hi,d.lo,d.open,tv); d.tickcnt=tv;
      double aTrend,aUp,aDn,aTick; SessionHist(SessionStartMinute(sess),SessionEndMinute(sess),avgN,aTrend,aUp,aDn,aTick);
      d.avg=aTrend; avgUp=aUp; avgDn=aDn; d.tickpct=(aTick>0? d.tickcnt/aTick*100.0:0);
   } else {
      d.open=iOpen(_Symbol,tf,0); d.hi=iHigh(_Symbol,tf,0); d.lo=iLow(_Symbol,tf,0); d.tickcnt=iVolume(_Symbol,tf,0);
      d.avg=AvgTrend(tf,avgN); AvgUpDn(tf,avgN,avgUp,avgDn);
      double aTick=AvgTickVol(tf,avgN); d.tickpct=(aTick>0? d.tickcnt/aTick*100.0:0);
   }
   d.chgpct=(d.open>0.0)?(price-d.open)/d.open*100.0:0;
   d.range=(d.hi-d.lo);
   d.oc=(price-d.open);
   d.strength=DirStrength(d.open,d.hi,d.lo,price,true,true);
   d.trend=MathAbs(d.strength);
   // 레벨
   if(isSession){
      double mults[2]; string names[2]; mults[0]=InpLevelMid; mults[1]=InpLevelFull;
      names[0]="1차 레벨 (50%)"; names[1]="최종 레벨 (100%)";
      for(int i=0;i<2;i++){ double up=d.open+avgUp*mults[i], dn=d.open-avgDn*mults[i];
         d.lname[i]=names[i]; d.lup[i]=up; d.ldn[i]=dn; d.luppt[i]=ToPt(up-d.open); d.ldnpt[i]=ToPt(dn-d.open);
         string tx; double rc; int sd; ReachInfo(d.open,price,up,dn,rc,tx,sd); d.lreach[i]=rc; d.ltxt[i]=tx; d.ldir[i]=sd; }
      d.nlvl=2;
   } else {
      double up=d.open+avgUp*InpLevelFull, dn=d.open-avgDn*InpLevelFull;
      d.lname[0]=(tf==PERIOD_W1? StringFormat("%d주 주간 레벨",InpWeekWeeks): StringFormat("%d일 일간 레벨",avgN));
      d.lup[0]=up; d.ldn[0]=dn; d.luppt[0]=ToPt(up-d.open); d.ldnpt[0]=ToPt(dn-d.open);
      string tx; double rc; int sd; ReachInfo(d.open,price,up,dn,rc,tx,sd); d.lreach[0]=rc; d.ltxt[0]=tx; d.ldir[0]=sd;
      d.nlvl=1;
   }
}

// 텔레그램: 방향강도 한 블록
string TgDirBlock(const string title,const PeriodData &d,const string avgLabel)
{
   string s=StringFormat("%s\n", title);
   s+=StringFormat("• 시가: %s (시가대비 %s%%)\n", FmtPrice(d.open), SignStr(d.chgpct,2));
   s+=StringFormat("• 변동: 고저 %s | 시종 %s (추세율 %.1f%% | %s %.1f%%)\n",
        FmtPtAbs(d.range,1), FmtPtAbs(d.oc,1), d.trend, avgLabel, d.avg);
   s+=StringFormat("• 틱볼륨: %s %.1f%% (%s Ticks)\n", Bar10(d.tickpct), d.tickpct, FmtInt(d.tickcnt));
   for(int i=0;i<d.nlvl;i++){
      s+=StringFormat("• %s: %s (%s) / %s (%s)\n", d.lname[i],
           FmtPrice(d.lup[i]), FmtPtSgn(d.lup[i]-d.open,1), FmtPrice(d.ldn[i]), FmtPtSgn(d.ldn[i]-d.open,1));
      s+=StringFormat("   └ 도달률: %s %.1f%% (%s)\n", Bar10(d.lreach[i]), d.lreach[i], d.ltxt[i]);
   }
   return(s);
}
string FmtInt(const long v){ string s=IntegerToString(v); // 천단위 콤마
   string o=""; int c=0; for(int i=StringLen(s)-1;i>=0;i--){ o=StringSubstr(s,i,1)+o; if(++c%3==0 && i>0)o=","+o; } return(o); }

// 텔레그램: 체결 봉 라인
string TgFlowBar(const string head,const ENUM_TIMEFRAMES tf,const int shift,const bool useFlag)
{
   double o=iOpen(_Symbol,tf,shift),h=iHigh(_Symbol,tf,shift),l=iLow(_Symbol,tf,shift);
   double c=(shift==0)?CurrentPrice():iClose(_Symbol,tf,shift);
   if(o<=0.0) return("  ["+head+"] (데이터 준비중)\n");
   double move=c-o, swing=h-l, eff=(swing>0?MathAbs(move)/swing:0);
   TickStats st; AggregateBarTicks(tf,shift,st,useFlag); double dom=st.Dominance();
   double perTick=(st.total>0? move/(double)st.total:0);
   string hd=head;
   if(shift==0){ datetime bt=iTime(_Symbol,tf,0); int es=(int)(TimeCurrent()-bt);
      hd=StringFormat("%s %d분/%d분(%.0f%%)",head,es/60,PeriodSeconds(tf)/60,ElapsedRatio(bt,TimeCurrent(),PeriodSeconds(tf))*100); }
   string s=StringFormat("  ┌ %s\n",hd);
   s+=StringFormat("  │ 총틱 %s (왜곡 %s)\n", FmtInt(st.total), FmtInt(st.distort));
   s+=StringFormat("  │ 방향성 %.1f%% (↑%s/↓%s)\n", dom, FmtInt(st.up), FmtInt(st.down));
   s+=StringFormat("  │ 실이동 %s (흔들림 %s | 효율 %.2f)\n", FmtMove(move), FmtMove(swing), eff);
   s+=StringFormat("  │ 틱당 실이동 %s\n", FmtPerTick(perTick));
   return(s);
}
//--- 시간범위 & 시계열 봉(자리 프레임)
string HM(const datetime t){ return(TimeToString(t,TIME_MINUTES)); }
string KstRange(const ENUM_TIMEFRAMES tf,const int shift){ datetime o=iTime(_Symbol,tf,shift); if(o==0)return("-"); datetime c=o+PeriodSeconds(tf);
   if(shift==0) return(HM(ToKST(o,InpServerToKST))+"~현재"); return(HM(ToKST(o,InpServerToKST))+"~"+HM(ToKST(c,InpServerToKST))); }
string ChartRange(const ENUM_TIMEFRAMES tf,const int shift){ datetime o=iTime(_Symbol,tf,shift); if(o==0)return("-"); datetime c=o+PeriodSeconds(tf);
   if(shift==0){ int em=(int)((TimeCurrent()-o)/60); return(HM(o)+" ("+IntegerToString(em)+"분 경과)"); } return(HM(o)+"~"+HM(c)); }
string TgFlowSeries(const ENUM_TIMEFRAMES tf,const int shift,const bool useFlag){
   double o=iOpen(_Symbol,tf,shift),h=iHigh(_Symbol,tf,shift),l=iLow(_Symbol,tf,shift),c=(shift==0)?CurrentPrice():iClose(_Symbol,tf,shift);
   if(o<=0.0) return("");
   double move=c-o,span=h-l,eff=(span>0?MathAbs(move)/span:0);
   TickStats st; AggregateBarTicks(tf,shift,st,useFlag); double dom=st.Dominance();
   string tag=(shift==0)?"진행":("-"+IntegerToString(shift)); string note=(shift==1)?" (직전완성)":"";
   string s=StringFormat("  ┌ [%s %s봉%s] KST %s | 차트 %s\n",tag,TfName(tf),note,KstRange(tf,shift),ChartRange(tf,shift));
   s+=StringFormat("  │ 가격 %s→%s (L %s ~ H %s)\n",FmtPrice(o),FmtPrice(c),FmtPrice(l),FmtPrice(h));
   s+=StringFormat("  │ 실이동 %s / 고저폭 %s (효율 %.2f)\n",FmtMove(move),FmtMove(span),eff);
   s+=StringFormat("  │ 체결우위 %.1f%% %s (↑%s/↓%s | %s틱)\n",dom,(dom>0?"매수":(dom<0?"매도":"중립")),FmtInt(st.up),FmtInt(st.down),FmtInt(st.total));
   return(s); }

string BuildStatusText()
{
   InitUnit();
   double price=CurrentPrice(); datetime kstNow=ToKST(TimeCurrent(),InpServerToKST);
   datetime sessStart; ENUM_SESSION sess=CurrentSessionStart(sessStart);
   bool useFlag=BrokerProvidesTradeFlags();

   string s=StringFormat("PIPxLOT | %s   %s KST\n",_Symbol,TimeToString(kstNow,TIME_MINUTES));
   s+="현재 세션: "+SessionName(sess)+" | 실시간가 "+FmtPrice(price)+"\n";
   s+="시장 상태: 정규장 실시간 연동 중\n";
   s+="════ 방향강도 ════\n";

   PeriodData ps,pd,pw;
   CalcPeriod((ENUM_TIMEFRAMES)0,InpSessDays,true,sessStart,sess,price,ps);
   CalcPeriod(PERIOD_D1,InpSessDays,false,sessStart,sess,price,pd);
   CalcPeriod(PERIOD_W1,InpWeekWeeks,false,sessStart,sess,price,pw);
   s+=TgDirBlock("[1] 실시간 세션 (Session)",ps,StringFormat("%d일 세션",InpSessDays));
   s+=TgDirBlock("[2] 당일 일간 (Daily)",pd,StringFormat("%d일 일간",InpSessDays));
   s+=TgDirBlock("[3] 이번주 주간 (Weekly)",pw,StringFormat("%d주 주간",InpWeekWeeks));

   // H4 국면
   double h4=DirStrength(iOpen(_Symbol,PERIOD_H4,1),iHigh(_Symbol,PERIOD_H4,1),iLow(_Symbol,PERIOD_H4,1),iClose(_Symbol,PERIOD_H4,1),true,true);
   double h4a=AvgTrend(PERIOD_H4,30);
   double h4n=DirStrength(iOpen(_Symbol,PERIOD_H4,0),iHigh(_Symbol,PERIOD_H4,0),iLow(_Symbol,PERIOD_H4,0),price,true,true);
   datetime h4bt=iTime(_Symbol,PERIOD_H4,0); int h4m=(int)((TimeCurrent()-h4bt)/60);
   s+="[4] H4 국면 (전략)\n";
   s+=StringFormat("• 완성 %s%% (평균 %.0f · %s)\n", SignStr(h4,1), h4a, PhaseStr(MathAbs(h4),h4a));
   s+=StringFormat("• 진행 %s%% 경과 %dH%dm/4H | 방향 %s\n", SignStr(h4n,1), h4m/60, h4m%60, (h4>0?"상승↑":(h4<0?"하락↓":"-")));
   s+=StringFormat("• H1위치(5일범위) %.0f%%\n", RangePosPct());

   // 체결
   s+="════ 체결 ════\n";
   TickStats t4; AggregateTicks(TimeCurrent()-4*3600,TimeCurrent(),t4,useFlag);
   double o4=0; { int sh=iBarShift(_Symbol,PERIOD_M1,TimeCurrent()-4*3600,false); if(sh>=0)o4=iOpen(_Symbol,PERIOD_M1,sh); }
   int hh=iHighest(_Symbol,PERIOD_M5,MODE_HIGH,48,0),ll=iLowest(_Symbol,PERIOD_M5,MODE_LOW,48,0);
   double span=(hh>=0&&ll>=0)?(iHigh(_Symbol,PERIOD_M5,hh)-iLow(_Symbol,PERIOD_M5,ll)):0;
   s+="[1] 최근 4H 체결 역학 요약\n";
   if(t4.valid){ s+=StringFormat("• 누적틱 %s (왜곡 %s)\n",FmtInt(t4.total),FmtInt(t4.distort));
      s+=StringFormat("• 순 방향성 %.1f%% %s (↑%s/↓%s)\n",t4.Dominance(),(t4.Dominance()>0?"매수 우위":(t4.Dominance()<0?"매도 우위":"중립")),FmtInt(t4.up),FmtInt(t4.down)); }
   else s+="• 틱 데이터 없음 (휴장/보관량)\n";
   s+=StringFormat("• 순이동 %s | 고저폭 %s\n",FmtMove(price-o4),FmtMove(span));
   s+=StringFormat("[2] %s 자리 프레임 (시계열)\n",TfName(InpFlowZoneTF));
   for(int sh=InpZoneBars; sh>=1; sh--) s+=TgFlowSeries(InpFlowZoneTF,sh,useFlag);
   s+=TgFlowSeries(InpFlowZoneTF,0,useFlag);
   s+=StringFormat("[3] %s 진입 프레임 (완성 vs 진행)\n",TfName(InpFlowEntryTF));
   s+=TgFlowBar("직전 완성봉",InpFlowEntryTF,1,useFlag);
   s+=TgFlowBar("진행봉",InpFlowEntryTF,0,useFlag);
   s+="─────────────\n* 추세율=|시종|/고저, 평균보다 크면 추세. 진입은 캔들로.";
   return(s);
}

//==================================================================//
//  JSON (웹 대시보드)                                               //
//==================================================================//
string JNum(const double v,const int d=5){ return(DoubleToString(v,d)); }
string JPeriod(const PeriodData &d)
{
   string s=StringFormat("{\"open\":%s,\"chgpct\":%s,\"range_pt\":%s,\"oc_pt\":%s,\"strength\":%s,\"trend\":%s,\"avg\":%s,\"tickvol_pct\":%s,\"tickvol_cnt\":%d,\"levels\":[",
      JNum(d.open,_Digits),JNum(d.chgpct,2),JNum(ToPt(d.range),1),JNum(ToPt(d.oc),1),JNum(d.strength,1),JNum(d.trend,1),JNum(d.avg,1),JNum(d.tickpct,1),(int)d.tickcnt);
   for(int i=0;i<d.nlvl;i++){ if(i>0)s+=",";
      s+=StringFormat("{\"name\":\"%s\",\"up\":%s,\"dn\":%s,\"up_pt\":%s,\"dn_pt\":%s,\"reach\":%s,\"reach_txt\":\"%s\",\"dir\":%d}",
         d.lname[i],JNum(d.lup[i],_Digits),JNum(d.ldn[i],_Digits),JNum(d.luppt[i],1),JNum(d.ldnpt[i],1),JNum(d.lreach[i],1),d.ltxt[i],d.ldir[i]); }
   s+="]}"; return(s);
}
string JFlowBar(const ENUM_TIMEFRAMES tf,const int shift,const bool useFlag)
{
   double o=iOpen(_Symbol,tf,shift),h=iHigh(_Symbol,tf,shift),l=iLow(_Symbol,tf,shift);
   double c=(shift==0)?CurrentPrice():iClose(_Symbol,tf,shift);
   double move=c-o,swing=h-l,eff=(swing>0?MathAbs(move)/swing:0);
   TickStats st; AggregateBarTicks(tf,shift,st,useFlag); double dom=st.Dominance();
   double perTick=(st.total>0?move/(double)st.total:0);
   double moveU = g_metal? move : move/OnePip();
   double swingU= g_metal? swing: swing/OnePip();
   double ptU   = g_metal? perTick : perTick/OnePip();
   string el = (shift==0)? StringFormat(",\"elapsed_pct\":%s",JNum(ElapsedRatio(iTime(_Symbol,tf,0),TimeCurrent(),PeriodSeconds(tf))*100,0)) : "";
   return(StringFormat("{\"total\":%d,\"distort\":%d,\"up\":%d,\"down\":%d,\"dom\":%s,\"move\":%s,\"swing\":%s,\"eff\":%s,\"perTick\":%s%s}",
      (int)st.total,(int)st.distort,(int)st.up,(int)st.down,JNum(dom,1),JNum(moveU,2),JNum(swingU,2),JNum(eff,2),JNum(ptU,5),el));
}
string JFlowSeries(const ENUM_TIMEFRAMES tf,const int shift,const bool useFlag)
{
   double o=iOpen(_Symbol,tf,shift),h=iHigh(_Symbol,tf,shift),l=iLow(_Symbol,tf,shift),c=(shift==0)?CurrentPrice():iClose(_Symbol,tf,shift);
   double move=c-o,span=h-l,eff=(span>0?MathAbs(move)/span:0);
   TickStats st; AggregateBarTicks(tf,shift,st,useFlag); double dom=st.Dominance();
   double moveU=g_metal?move:move/OnePip(), spanU=g_metal?span:span/OnePip();
   string tag=(shift==0)?"진행":("-"+IntegerToString(shift));
   return(StringFormat("{\"tag\":\"%s\",\"kst\":\"%s\",\"chart\":\"%s\",\"open\":%s,\"close\":%s,\"lo\":%s,\"hi\":%s,\"move\":%s,\"span\":%s,\"eff\":%s,\"dom\":%s,\"up\":%d,\"down\":%d,\"total\":%d}",
      tag,KstRange(tf,shift),ChartRange(tf,shift),JNum(o,_Digits),JNum(c,_Digits),JNum(l,_Digits),JNum(h,_Digits),JNum(moveU,2),JNum(spanU,2),JNum(eff,2),JNum(dom,1),(int)st.up,(int)st.down,(int)st.total));
}
string BuildStatusJson()
{
   InitUnit();
   double price=CurrentPrice(); datetime kstNow=ToKST(TimeCurrent(),InpServerToKST);
   datetime sessStart; ENUM_SESSION sess=CurrentSessionStart(sessStart);
   bool useFlag=BrokerProvidesTradeFlags();
   PeriodData ps,pd,pw;
   CalcPeriod((ENUM_TIMEFRAMES)0,InpSessDays,true,sessStart,sess,price,ps);
   CalcPeriod(PERIOD_D1,InpSessDays,false,sessStart,sess,price,pd);
   CalcPeriod(PERIOD_W1,InpWeekWeeks,false,sessStart,sess,price,pw);

   double h4=DirStrength(iOpen(_Symbol,PERIOD_H4,1),iHigh(_Symbol,PERIOD_H4,1),iLow(_Symbol,PERIOD_H4,1),iClose(_Symbol,PERIOD_H4,1),true,true);
   double h4a=AvgTrend(PERIOD_H4,30);
   double h4n=DirStrength(iOpen(_Symbol,PERIOD_H4,0),iHigh(_Symbol,PERIOD_H4,0),iLow(_Symbol,PERIOD_H4,0),price,true,true);
   double h4el=ElapsedRatio(iTime(_Symbol,PERIOD_H4,0),TimeCurrent(),PeriodSeconds(PERIOD_H4))*100;

   TickStats t4; AggregateTicks(TimeCurrent()-4*3600,TimeCurrent(),t4,useFlag);
   double o4=0; { int sh=iBarShift(_Symbol,PERIOD_M1,TimeCurrent()-4*3600,false); if(sh>=0)o4=iOpen(_Symbol,PERIOD_M1,sh); }
   int hh=iHighest(_Symbol,PERIOD_M5,MODE_HIGH,48,0),ll=iLowest(_Symbol,PERIOD_M5,MODE_LOW,48,0);
   double span=(hh>=0&&ll>=0)?(iHigh(_Symbol,PERIOD_M5,hh)-iLow(_Symbol,PERIOD_M5,ll)):0;
   double netU=g_metal?(price-o4):(price-o4)/OnePip(), spanU=g_metal?span:span/OnePip();

   string j="{";
   j+="\"sym\":\""+_Symbol+"\",\"session\":\""+SessionName(sess)+"\",\"market\":\"정규장 실시간 연동 중\",";
   j+="\"price\":"+JNum(price,_Digits)+",\"cur\":\""+g_cur+"\",\"ptl\":\"pt\",\"kst\":\""+TimeToString(kstNow,TIME_MINUTES)+"\",";
   j+="\"dir\":{\"session\":"+JPeriod(ps)+",\"daily\":"+JPeriod(pd)+",\"weekly\":"+JPeriod(pw)+",";
   j+=StringFormat("\"h4\":{\"done\":%s,\"avg\":%s,\"now\":%s,\"elapsed_pct\":%s,\"h1pos\":%s}},",JNum(h4,1),JNum(h4a,0),JNum(h4n,1),JNum(h4el,0),JNum(RangePosPct(),0));
   j+="\"flow\":{\"flag\":\""+(useFlag?"제공":"추정")+"\",\"unit\":\""+g_unit+"\",";
   j+=StringFormat("\"h4\":{\"valid\":%s,\"total\":%d,\"distort\":%d,\"up\":%d,\"down\":%d,\"dom\":%s,\"net\":%s,\"span\":%s},",
        (t4.valid?"true":"false"),(int)t4.total,(int)t4.distort,(int)t4.up,(int)t4.down,JNum(t4.Dominance(),1),JNum(netU,1),JNum(spanU,1));
   j+="\"zone\":{\"tf\":\""+TfName(InpFlowZoneTF)+"\",\"bars\":[";
   for(int sh=InpZoneBars; sh>=1; sh--){ j+=JFlowSeries(InpFlowZoneTF,sh,useFlag); j+=","; }
   j+=JFlowSeries(InpFlowZoneTF,0,useFlag);
   j+="]},";
   j+="\"entry\":{\"tf\":\""+TfName(InpFlowEntryTF)+"\",\"done\":"+JFlowBar(InpFlowEntryTF,1,useFlag)+",\"now\":"+JFlowBar(InpFlowEntryTF,0,useFlag)+"}";
   j+="}}";
   return(j);
}

//==================================================================//
//  인걸핑 감지                                                      //
//==================================================================//
void CheckEngulf()
{
   datetime b1=iTime(_Symbol,InpEngulfTF,1); if(b1==0||b1==g_lastEngBar)return; g_lastEngBar=b1;
   EngulfResult r; if(!DetectEngulf(InpEngulfTF,1,r,InpMaxLegs))return;
   double prevBody=MathAbs(iClose(_Symbol,InpEngulfTF,2)-iOpen(_Symbol,InpEngulfTF,2));
   double h4=DirStrength(iOpen(_Symbol,PERIOD_H4,1),iHigh(_Symbol,PERIOD_H4,1),iLow(_Symbol,PERIOD_H4,1),iClose(_Symbol,PERIOD_H4,1),true,true);
   double htf=(h4*(double)r.dir>0)?1:(h4*(double)r.dir<0?-1:0);
   bool useFlag=BrokerProvidesTradeFlags(); TickStats ts; AggregateBarTicks(InpEngulfTF,1,ts,useFlag); double dom=ts.Dominance();
   double flow=0; if(ts.valid&&ts.total>0) flow=(dom*(double)r.dir>0)?1:(dom*(double)r.dir<0?-1:0);
   double lv=NearestLevelPips((r.zoneOpen+r.zoneClose)/2.0); double rsi=GetRSI(InpEngulfTF,14,1);
   double w[5]; ArrayInitialize(w,0); QualityScore q=ComputeQuality(r,prevBody,htf,flow,lv,rsi,w);
   double pos=RangePosPct(); string id=MakeEngulfId(r.time);
   if(InpWriteCsv) LogEngulf(id,r,q,rsi,SessionName(CurrentSession()),h4,pos,ToPt(CurrentPrice()-iOpen(_Symbol,PERIOD_W1,0)),dom,ts.valid);
   g_rtActive=true; g_rtId=id; g_rtEng=r; g_rtStartM15=iTime(_Symbol,InpRetestTF,0); g_rtBars=0; g_rtLeftZone=false;
   if(q.score<InpMinScore) return;
   datetime kstNow=ToKST(TimeCurrent(),InpServerToKST); string dirTxt=(r.dir==ENGULF_BULL?"🟢 상승(롱)":"🔴 하락(숏)");
   string msg=StringFormat("🔔 %s 인걸핑 발생\n━━━━━━━━━━━━━\n방향   : %s\n시각   : %s KST (%s)\n품질점수: %.0f 점\nRSI    : %.1f\n존(진입범위): %s ~ %s\nH4방향 일치 : %s\n체결 우위 일치: %s\n5일 위치: %.0f%%\n━━━━━━━━━━━━━\n→ M15 %d개 안에 존 재진입 시 리테스트 알림",
      _Symbol,dirTxt,TimeToString(kstNow,TIME_MINUTES),SessionName(CurrentSession()),q.score,rsi,
      FmtPrice(r.zoneOpen),FmtPrice(r.zoneClose),(htf>0?"✅":"❌"),(flow>0?"✅":(ts.valid?"❌":"—")),pos,InpRetestBars);
   Notify(msg);
}
//==================================================================//
//  리테스트 (존 이탈 후 재진입만)                                   //
//==================================================================//
void TrackRetest()
{
   if(!g_rtActive)return; datetime m15=iTime(_Symbol,InpRetestTF,0);
   if(m15!=g_lastM15Bar){ g_lastM15Bar=m15; if(m15>g_rtStartM15)g_rtBars++; }
   double price=CurrentPrice(); bool inZone=PriceInZone(price,g_rtEng,InpWickZone);
   if(!g_rtLeftZone){ if(!inZone)g_rtLeftZone=true; }
   else if(inZone){
      double zT=MathMax(g_rtEng.zoneOpen,g_rtEng.zoneClose),zB=MathMin(g_rtEng.zoneOpen,g_rtEng.zoneClose),entry,sl,tp;
      if(g_rtEng.dir==ENGULF_BULL){ entry=zB+(zT-zB)*0.5; sl=g_rtEng.zoneOpen-OnePip(); tp=entry+(entry-sl)*2.0; }
      else{ entry=zT-(zT-zB)*0.5; sl=g_rtEng.zoneOpen+OnePip(); tp=entry-(sl-entry)*2.0; }
      string di=(g_rtEng.dir==ENGULF_BULL?"🟢 상승(롱)":"🔴 하락(숏)");
      string msg=StringFormat("✅ 리테스트 도달 (%d/%d)\n━━━━━━━━━━━━━\n%s %s\n진입 후보: %s\n손절     : %s\n익절     : %s (2:1)\n━━━━━━━━━━━━━\n※ 진입은 캔들 보고 직접 판단",
         g_rtBars+1,InpRetestBars,_Symbol,di,FmtPrice(entry),FmtPrice(sl),FmtPrice(tp));
      Notify(msg); UpdateEngulfRetest(g_rtId,g_rtBars+1); g_rtActive=false; return;
   }
   if(g_rtBars>=InpRetestBars){ Print(StringFormat("⛔ [리테스트 무효] %s",g_rtId)); UpdateEngulfRetest(g_rtId,-1); g_rtActive=false; }
}
//==================================================================//
//  CSV                                                              //
//==================================================================//
void EnsureCsvHeader()
{
   if(!InpWriteCsv||FileIsExist(InpCsvFile))return;
   int h=FileOpen(InpCsvFile,FILE_WRITE|FILE_CSV|FILE_ANSI,','); if(h==INVALID_HANDLE){Print("CSV 헤더 실패 ",GetLastError());return;}
   FileWrite(h,"engulf_id","time_kst","symbol","dir","zone_open","zone_close","score","q_ratio","q_candle","q_levelpip","q_htf","q_flow","rsi","session","h4_dir","pos_pct","wk_chg_pt","flow_dom","account","retest_bar","entered");
   FileClose(h);
}
void LogEngulf(const string id,const EngulfResult &r,const QualityScore &q,const double rsi,const string session,
               const double h4,const double pos,const double wk,const double dom,const bool fv)
{
   int h=FileOpen(InpCsvFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI,','); if(h==INVALID_HANDLE)return; FileSeek(h,0,SEEK_END);
   datetime kst=ToKST(r.time,InpServerToKST);
   FileWrite(h,id,TimeToString(kst,TIME_DATE|TIME_MINUTES),_Symbol,(r.dir==ENGULF_BULL?"상승":"하락"),
      DoubleToString(r.zoneOpen,_Digits),DoubleToString(r.zoneClose,_Digits),DoubleToString(q.score,1),DoubleToString(q.engulfRatio,2),
      DoubleToString(q.candleStrength,3),DoubleToString(q.levelProx,1),DoubleToString(q.htfAlign,0),DoubleToString(q.flowAlign,0),
      DoubleToString(rsi,1),session,DoubleToString(h4,1),DoubleToString(pos,0),DoubleToString(wk,1),(fv?DoubleToString(dom,1):"NA"),AccountTag(),"","N");
   FileClose(h);
}
void UpdateEngulfRetest(const string id,const int rb)
{
   if(!InpWriteCsv)return; int h=FileOpen(InpCsvFile,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI,','); if(h==INVALID_HANDLE)return; FileSeek(h,0,SEEK_END);
   FileWrite(h,id,"RETEST_UPDATE",_Symbol,"","","","","","","","","","","","","","","",AccountTag(),(rb<0?"무효":IntegerToString(rb)),"");
   FileClose(h);
}
//+------------------------------------------------------------------+
