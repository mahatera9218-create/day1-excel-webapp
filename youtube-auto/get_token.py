"""유튜브 업로드용 로그인 토큰(token.json)을 만드는 1회용 스크립트.

사용법 (PC에서):
  1) 이 파일과 구글에서 받은 client_secret JSON 을 같은 폴더에 둔다.
     (JSON 파일 이름은 아무거나 — 폴더에 client_secret* 가 하나만 있으면 자동으로 찾는다)
  2) 아래 두 패키지 설치:
        pip install google-auth-oauthlib google-api-python-client
  3) 실행:
        python get_token.py
  4) 브라우저가 열리면 본인 구글 계정으로 로그인 → "확인되지 않은 앱" 경고가 뜨면
     고급 → (안전하지 않음) 계속 → 권한 허용.
  5) 같은 폴더에 token.json 이 생긴다. 그 내용을 GitHub Secret 에 넣으면 끝.
"""

import glob
import sys

from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = [
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.readonly",
]


def main() -> None:
    matches = sorted(glob.glob("client_secret*.json")) or sorted(glob.glob("*.json"))
    matches = [m for m in matches if m != "token.json"]
    if not matches:
        sys.exit("[오류] 이 폴더에서 client_secret JSON 파일을 찾지 못했습니다. "
                 "구글에서 받은 JSON 을 이 폴더에 두고 다시 실행하세요.")
    secret = matches[0]
    print(f"사용할 클라이언트 파일: {secret}")
    creds = InstalledAppFlow.from_client_secrets_file(secret, SCOPES).run_local_server(port=0)
    with open("token.json", "w", encoding="utf-8") as f:
        f.write(creds.to_json())
    print("\n성공! 같은 폴더에 token.json 이 생겼습니다.")
    print("이제 token.json 의 내용을 GitHub Secret 'YOUTUBE_TOKEN_JSON' 에,")
    print("클라이언트 JSON 내용을 'CLIENT_SECRET_JSON' 에 넣으세요.")


if __name__ == "__main__":
    main()
