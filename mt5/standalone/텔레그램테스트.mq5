//+------------------------------------------------------------------+
//|                                          텔레그램테스트.mq5       |
//|   텔레그램 연동 진단용 스크립트 (한 번 실행해서 원인 팝업 확인)   |
//|   파일>새로만들기>[스크립트]로 생성. 차트에 끌어다 놓으면 1회 실행. |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

input string InpTgToken  = "";   // 봇 토큰 (BotFather가 준 긴 문자열)
input string InpTgChatId = "";   // chat_id (getUpdates 로 확인한 숫자)

void OnStart()
{
   //--- 1) 입력값 확인
   if(InpTgToken=="" || InpTgChatId=="")
   {
      Alert("❌ 토큰 또는 chat_id 가 비어있습니다. 스크립트 실행창 '입력값' 탭에 넣으세요.");
      return;
   }

   //--- 2) 요청 준비
   string url="https://api.telegram.org/bot"+InpTgToken+"/sendMessage";
   string text="✅ MT5 → 텔레그램 연결 테스트 성공";
   string body="{\"chat_id\":\""+InpTgChatId+"\",\"text\":\""+text+"\"}";

   char post[]; char result[]; string resHeaders;
   int total=StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
   if(total>0) ArrayResize(post, total-1);

   //--- 3) 전송
   ResetLastError();
   int res=WebRequest("POST", url, "Content-Type: application/json\r\n", 5000, post, result, resHeaders);
   string resp=CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);

   //--- 4) 결과 진단 (팝업으로 명확히)
   if(res==-1)
   {
      int err=GetLastError();
      Alert("❌ WebRequest 차단됨 (오류 ", err, ")\n",
            "→ 도구>옵션>전문가 자문 에서\n",
            "   'WebRequest 허용' 체크 + https://api.telegram.org 추가 후\n",
            "   MT5 재시작하고 다시 실행하세요.");
      Print("WebRequest -1, error=", err);
      return;
   }
   if(res==200)
   {
      Alert("✅ 성공! 텔레그램 앱을 확인하세요. 메시지가 왔으면 토큰/챗ID 정상입니다.");
      Print("성공 200: ", resp);
      return;
   }
   // 그 외 응답코드 → 텔레그램이 이유를 resp 에 알려줌
   Alert("⚠️ 텔레그램 응답 코드 ", res, "\n",
         "401=토큰 틀림 / 400=chat_id 틀림(먼저 봇에 메시지 보내야 함)\n",
         "응답: ", resp);
   Print("응답코드 ", res, " : ", resp);
}
//+------------------------------------------------------------------+
