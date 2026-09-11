//+------------------------------------------------------------------+
//|                                           TradeSnapshotLogger.mq5 |
//|   지표 C — 진입 스냅샷 자동 기록기 ★핵심 (PRD §2, 우선순위 2b)   |
//|                                                                  |
//|  성격: 표시가 아니라 '데이터 수집 엔진'.                          |
//|  포지션이 열리는 순간(OnTradeTransaction)을 자동 감지 →           |
//|   그 시점 모든 터미널 수치를 스냅샷 → trade_log.csv 한 줄 기록.   |
//|  포지션이 닫히면 결과(승패/손익/R)를 같은 행에 자동 추가.          |
//|  감정(정성)만 사용자가 나중에 수동으로 채움.                      |
//|                                                                  |
//|  ※ 이 EA 는 매매를 하지 않는다. 기록만 한다 (수동매매 전제).      |
//+------------------------------------------------------------------+
#property copyright "Engulf Strategy Indicator Set"
#property version   "1.00"
#property strict

#include <Engulf/Common.mqh>
#include <Engulf/Stats.mqh>
#include <Engulf/Engulf.mqh>
#include <Engulf/Ticks.mqh>

//--- 입력 --------------------------------------------------------
input int    InpServerToKST = 7;                 // 서버→KST 시차(시간)
input string InpCsvFile     = "trade_log.csv";   // 기록 파일
input int    InpSessDays    = 5;
input int    InpWeekWeeks   = 4;
input bool   InpDemoTag     = true;

//--- 스냅샷의 CSV 컬럼 (헤더와 1:1) ------------------------------
#define COL_COUNT 34

//+------------------------------------------------------------------+
int OnInit()
{
   EnsureHeader();
   Print("TradeSnapshotLogger 시작 — 파일: ", InpCsvFile,
         "  (진입/청산 자동 기록, 매매는 하지 않음)");
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason) {}
void OnTick() {}   // 계산 없음 — 이벤트 기반

//==================================================================//
//  거래 트랜잭션 감지 (진입 IN / 청산 OUT)                          //
//==================================================================//
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket))
      return;

   long   entry    = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   long   posId    = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   string sym      = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
   if(sym != _Symbol)
      return;

   if(entry == DEAL_ENTRY_IN)
      OnPositionOpen(dealTicket, posId);
   else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT)
      OnPositionClose(dealTicket, posId);
}

//------------------------------------------------------------------//
//  진입 스냅샷                                                      |
//------------------------------------------------------------------//
void OnPositionOpen(const ulong dealTicket, const long posId)
{
   double price   = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   double lots     = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
   long   dtype    = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   datetime dtime  = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   string dir      = (dtype == DEAL_TYPE_BUY) ? "롱" : "숏";

   // SL/TP: 포지션에서 조회
   double sl = 0, tp = 0;
   if(PositionSelectByTicket(posId))
   {
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
   }

   //--- 방향강도 (H4/일간/주간) — 진입 '즉시' 계산 (PRD 주의)
   double h4o=iOpen(_Symbol,PERIOD_H4,1), h4h=iHigh(_Symbol,PERIOD_H4,1),
          h4l=iLow(_Symbol,PERIOD_H4,1),  h4c=iClose(_Symbol,PERIOD_H4,1);
   double h4dir = DirStrength(h4o,h4h,h4l,h4c,true,true);
   double h4avg = AvgDirStrengthAbs(PERIOD_H4, 30, 1);
   string h4phase = PhaseStr(MathAbs(h4dir), h4avg);

   double dOpen=iOpen(_Symbol,PERIOD_D1,0);
   double dDir = DirStrength(dOpen,iHigh(_Symbol,PERIOD_D1,0),iLow(_Symbol,PERIOD_D1,0),price,true,true);
   double dAvg = AvgDirStrengthAbs(PERIOD_D1, InpSessDays, 1);

   double wOpen=iOpen(_Symbol,PERIOD_W1,0);
   double wDir = DirStrength(wOpen,iHigh(_Symbol,PERIOD_W1,0),iLow(_Symbol,PERIOD_W1,0),price,true,true);
   double wAvg = AvgDirStrengthAbs(PERIOD_W1, InpWeekWeeks, 1);

   //--- 레벨 도달률 (일간, 시가±R)
   double dR = AvgRange(PERIOD_D1, InpSessDays, 1);
   double dReach = (dR>0)? ReachPercent(price, dOpen, dOpen + (price>=dOpen? dR : -dR)) : 0;
   double dRoom  = (dR>0)? ToPips((dOpen + (price>=dOpen? dR : -dR)) - price) : 0;

   //--- 위치 (5일 범위%) + 주간시가 대비
   double posPct = RangePosPct();
   double wkChg  = ToPips(price - wOpen);

   //--- 틱볼륨 %
   double dTv = TickVolPct(PERIOD_D1, InpSessDays);
   double wTv = TickVolPct(PERIOD_W1, InpWeekWeeks);

   //--- 세션
   datetime dm; ENUM_SESSION sess = CurrentSession(TimeCurrent(), InpServerToKST, dm);

   //--- 인걸핑 (가장 최근 H1 인걸핑 재확인)
   EngulfResult er; string engId=""; double score=0, qr=0, qc=0, qlv=0, qhtf=0;
   double rsi=0;
   if(DetectEngulf(PERIOD_H1, 1, er, 3))
   {
      double prevBody=MathAbs(iClose(_Symbol,PERIOD_H1,2)-iOpen(_Symbol,PERIOD_H1,2));
      double htfSame=(h4dir*(double)er.dir>0)?+1:(h4dir*(double)er.dir<0?-1:0);
      double lvpip = NearestLevelPips((er.zoneOpen+er.zoneClose)/2.0);
      rsi = GetRSI(PERIOD_H1,14,1);
      double w[5]; ArrayInitialize(w,0);
      QualityScore q = ComputeQuality(er, prevBody, htfSame, 0, lvpip, rsi, w);
      score=q.score; qr=q.engulfRatio; qc=q.candleStrength; qlv=q.levelProx; qhtf=q.htfAlign;
      MqlDateTime et; TimeToStruct(ToKST(er.time,InpServerToKST),et);
      engId=StringFormat("%s-%04d%02d%02d-%02d%02d",_Symbol,et.year,et.mon,et.day,et.hour,et.min);
   }

   //--- 체결 우위 (진입봉 H1)
   bool useFlag=BrokerProvidesTradeFlags();
   TickStats ts; AggregateBarTicks(PERIOD_H1,0,ts,useFlag);
   double dom = ts.valid? ts.Dominance() : 0;

   //--- CSV 한 줄 (결과/감정 컬럼은 공란)
   datetime kst = ToKST(dtime, InpServerToKST);
   string row[COL_COUNT];
   int i=0;
   row[i++]=IntegerToString(posId);                               // position_id
   row[i++]=TimeToString(kst, TIME_DATE|TIME_MINUTES);            // entry_kst
   row[i++]=_Symbol;                                              // symbol
   row[i++]=dir;                                                  // dir
   row[i++]=DoubleToString(price,_Digits);                       // entry_price
   row[i++]=DoubleToString(lots,2);                              // lots
   row[i++]=DoubleToString(sl,_Digits);                         // sl
   row[i++]=DoubleToString(tp,_Digits);                         // tp
   row[i++]=DoubleToString(h4dir,1);                            // h4_dir
   row[i++]=DoubleToString(h4avg,0);                            // h4_avg
   row[i++]=h4phase;                                            // h4_phase
   row[i++]=DoubleToString(dDir,1);                             // daily_dir
   row[i++]=DoubleToString(dAvg,0);                             // daily_avg
   row[i++]=DoubleToString(wDir,1);                             // weekly_dir
   row[i++]=DoubleToString(wAvg,0);                             // weekly_avg
   row[i++]=DoubleToString(dReach,0);                           // daily_reach%
   row[i++]=DoubleToString(dRoom,0);                            // daily_room_pip
   row[i++]=DoubleToString(posPct,0);                           // pos_pct
   row[i++]=DoubleToString(wkChg,1);                            // wk_chg_pip
   row[i++]=DoubleToString(dTv,0);                              // daily_tickvol%
   row[i++]=DoubleToString(wTv,0);                              // weekly_tickvol%
   row[i++]=SessionName(sess);                                  // session
   row[i++]=engId;                                              // engulf_id (연결키)
   row[i++]=DoubleToString(score,1);                            // q_score
   row[i++]=DoubleToString(qr,2);                               // q_ratio
   row[i++]=DoubleToString(qc,3);                               // q_candle
   row[i++]=DoubleToString(qlv,1);                              // q_levelpip
   row[i++]=DoubleToString(qhtf,0);                             // q_htf
   row[i++]=DoubleToString(rsi,1);                              // rsi
   row[i++]=ts.valid? DoubleToString(dom,1) : "NA";            // flow_dom
   row[i++]=AccountTag();                                       // account
   // --- 결과/감정 (공란) ---
   row[i++]="";  // result       — 청산 시 자동 (승/패/무)
   row[i++]="";  // result_detail — 청산 시 자동 (손익/보유/R)
   row[i++]="";  // emotion       — 사용자 수동 기입

   AppendRow(row, COL_COUNT);
   Print("📸 진입 스냅샷 기록 posId=", posId, " 점수=", DoubleToString(score,1));
}

//------------------------------------------------------------------//
//  청산 결과 채우기 (같은 posId 행 갱신)                            |
//------------------------------------------------------------------//
void OnPositionClose(const ulong dealTicket, const long posId)
{
   double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   double profit     = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
   datetime ctime    = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);

   // 포지션 전체 손익/진입가/보유시간 재구성
   double entryPrice=0, slPrice=0; datetime openTime=0; long dir=0; double totalProfit=0;
   if(HistorySelectByPosition(posId))
   {
      int deals = HistoryDealsTotal();
      for(int d=0; d<deals; d++)
      {
         ulong tk = HistoryDealGetTicket(d);
         long e = HistoryDealGetInteger(tk, DEAL_ENTRY);
         totalProfit += HistoryDealGetDouble(tk, DEAL_PROFIT);
         if(e == DEAL_ENTRY_IN)
         {
            entryPrice = HistoryDealGetDouble(tk, DEAL_PRICE);
            openTime   = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
            dir        = HistoryDealGetInteger(tk, DEAL_TYPE);
         }
      }
   }

   double pips = (dir == DEAL_TYPE_BUY) ? ToPips(closePrice - entryPrice)
                                        : ToPips(entryPrice - closePrice);
   string outcome = (totalProfit > 0) ? "승" : (totalProfit < 0 ? "패" : "무");
   int holdMin = (openTime>0)? (int)((ctime - openTime)/60) : 0;

   // R배수: 스냅샷 행에서 sl 을 읽어 계산 (파일에서 조회)
   double rMult = ComputeRMultiple(posId, entryPrice, closePrice, dir);

   datetime kst = ToKST(ctime, InpServerToKST);
   string resultStr = StringFormat("%s|청산 %s|손익 %.2f(%.1f핍)|보유 %dm|R %.2f",
      outcome, TimeToString(kst, TIME_MINUTES),
      totalProfit, pips, holdMin, rMult);

   FillResult(posId, outcome, resultStr);
   Print("🏁 청산 결과 기록 posId=", posId, " ", resultStr);
}

//==================================================================//
//  CSV 파일 조작 (전체 읽기→수정→재기록)                            //
//==================================================================//
void EnsureHeader()
{
   if(FileIsExist(InpCsvFile)) return;
   int h = FileOpen(InpCsvFile, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(h==INVALID_HANDLE){ Print("헤더 생성 실패 ", GetLastError()); return; }
   FileWrite(h,
     "position_id","entry_kst","symbol","dir","entry_price","lots","sl","tp",
     "h4_dir","h4_avg","h4_phase","daily_dir","daily_avg","weekly_dir","weekly_avg",
     "daily_reach%","daily_room_pip","pos_pct","wk_chg_pip","daily_tickvol%","weekly_tickvol%",
     "session","engulf_id","q_score","q_ratio","q_candle","q_levelpip","q_htf","rsi",
     "flow_dom","account","result","result_detail","emotion");
   FileClose(h);
}

void AppendRow(string &row[], const int cnt)
{
   int h = FileOpen(InpCsvFile, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE){ Print("append 실패 ", GetLastError()); return; }
   FileSeek(h, 0, SEEK_END);
   // 한 줄 조립하여 직접 기록
   string line="";
   for(int i=0;i<cnt;i++){ if(i>0) line+=","; line+=CsvEscape(row[i]); }
   FileWriteString(h, line + "\r\n");
   FileClose(h);
}

// posId 행의 result/result_detail 컬럼을 채움 (컬럼 33/34, 0-based 32/33)
void FillResult(const long posId, const string outcome, const string detail)
{
   string lines[]; int n = ReadAllLines(lines);
   if(n<=0) return;
   string key = IntegerToString(posId);
   for(int i=1;i<n;i++)   // 0 = 헤더
   {
      string parts[];
      int c = SplitCsv(lines[i], parts);
      // 아직 결과가 비어있는(진입만 기록된) 같은 posId 행을 찾는다
      if(c>0 && parts[0]==key && (c<=31 || parts[31]==""))
      {
         // 컬럼 수 보정
         if(c < COL_COUNT)
         {
            ArrayResize(parts, COL_COUNT);
            for(int k=c;k<COL_COUNT;k++) parts[k]="";
         }
         parts[31]=outcome;   // result (index 31)
         parts[32]=detail;    // result_detail (index 32) — emotion(33)은 보존
         lines[i]=JoinCsv(parts, COL_COUNT);
         break;
      }
   }
   WriteAllLines(lines, n);
}

double ComputeRMultiple(const long posId, const double entryPrice,
                        const double closePrice, const long dir)
{
   string lines[]; int n = ReadAllLines(lines);
   double sl=0;
   string key = IntegerToString(posId);
   for(int i=1;i<n;i++)
   {
      string parts[]; int c=SplitCsv(lines[i], parts);
      if(c>6 && parts[0]==key){ sl=StringToDouble(parts[6]); break; }
   }
   double risk = MathAbs(entryPrice - sl);
   if(risk <= 0.0) return(0.0);
   double reward = (dir==DEAL_TYPE_BUY)? (closePrice-entryPrice) : (entryPrice-closePrice);
   return(reward / risk);
}

int ReadAllLines(string &lines[])
{
   int h = FileOpen(InpCsvFile, FILE_READ|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE) return(0);
   int n=0;
   while(!FileIsEnding(h))
   {
      string s = FileReadString(h);
      ArrayResize(lines, n+1); lines[n]=s; n++;
   }
   FileClose(h);
   // 마지막 빈 줄 제거
   if(n>0 && StringLen(lines[n-1])==0) n--;
   return(n);
}

void WriteAllLines(string &lines[], const int n)
{
   int h = FileOpen(InpCsvFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE){ Print("재기록 실패 ", GetLastError()); return; }
   for(int i=0;i<n;i++)
      FileWriteString(h, lines[i] + "\r\n");
   FileClose(h);
}

//==================================================================//
//  보조 계산 (EngulfAlert 와 동일 로직 재사용)                      //
//==================================================================//
double RangePosPct()
{
   int hh=iHighest(_Symbol,PERIOD_H1,MODE_HIGH,120,0);
   int ll=iLowest(_Symbol,PERIOD_H1,MODE_LOW,120,0);
   if(hh<0||ll<0) return(0.0);
   double h=iHigh(_Symbol,PERIOD_H1,hh), l=iLow(_Symbol,PERIOD_H1,ll), p=CurrentPrice();
   return((h>l)?(p-l)/(h-l)*100.0:0.0);
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

double TickVolPct(const ENUM_TIMEFRAMES tf, const int avgN)
{
   long cur=iVolume(_Symbol,tf,0);
   double avg=AvgTickVolume(tf,avgN,1);
   return((avg>0)?(double)cur/avg*100.0:0.0);
}

double GetRSI(const ENUM_TIMEFRAMES tf, const int period, const int shift)
{
   int h=iRSI(_Symbol,tf,period,PRICE_CLOSE);
   if(h==INVALID_HANDLE) return(0.0);
   double buf[];
   if(CopyBuffer(h,0,shift,1,buf)<=0){ IndicatorRelease(h); return(0.0); }
   double v=buf[0]; IndicatorRelease(h); return(v);
}

string AccountTag()
{
   if(!InpDemoTag) return("");
   ENUM_ACCOUNT_TRADE_MODE m=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   switch(m){ case ACCOUNT_TRADE_MODE_DEMO:return("DEMO");
              case ACCOUNT_TRADE_MODE_CONTEST:return("CONTEST");
              default:return("REAL"); }
}

//--- CSV 문자열 처리 (콤마/따옴표 escape) ------------------------
string CsvEscape(const string s)
{
   if(StringFind(s,",")>=0 || StringFind(s,"\"")>=0 || StringFind(s,"|")>=0)
   {
      string t=s; StringReplace(t,"\"","\"\"");
      return("\""+t+"\"");
   }
   return(s);
}

int SplitCsv(const string line, string &parts[])
{
   // 단순 파서 (따옴표 안 콤마 처리)
   int n=0; string cur=""; bool inQ=false;
   int len=StringLen(line);
   for(int i=0;i<len;i++)
   {
      ushort ch=StringGetCharacter(line,i);
      if(ch=='"'){ inQ=!inQ; continue; }
      if(ch==',' && !inQ){ ArrayResize(parts,n+1); parts[n]=cur; n++; cur=""; }
      else cur+=ShortToString(ch);
   }
   ArrayResize(parts,n+1); parts[n]=cur; n++;
   return(n);
}

string JoinCsv(string &parts[], const int cnt)
{
   string s="";
   for(int i=0;i<cnt;i++){ if(i>0)s+=","; s+=CsvEscape(parts[i]); }
   return(s);
}
//+------------------------------------------------------------------+
