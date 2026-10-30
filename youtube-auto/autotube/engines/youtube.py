"""YouTube Data API 업로드. 영상은 비공개(=임시저장)로 올라간다.

최초 1회는 브라우저 로그인이 필요하고, 그 결과(token.json)는 채널 폴더에 저장되어
다음부터 자동으로 쓰인다. GitHub 실행용으로는 이 token.json 을 Secret 으로 넣는다.
"""

import json
from pathlib import Path

SCOPES = ["https://www.googleapis.com/auth/youtube.upload"]
AI_NOTICE = "※ 이 영상의 화면과 음성은 AI로 생성되었습니다."


def _credentials(channel_dir: Path, client_secret_name: str):
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow

    token_path = channel_dir / "token.json"
    creds = Credentials.from_authorized_user_file(str(token_path), SCOPES) if token_path.exists() else None
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
    if not creds or not creds.valid:
        secret = channel_dir / client_secret_name
        if not secret.exists():
            raise SystemExit(f"[오류] {secret} 가 없습니다. README 의 'YouTube 자동 업로드 설정'을 따라주세요.")
        creds = InstalledAppFlow.from_client_secrets_file(str(secret), SCOPES).run_local_server(port=0)
        token_path.write_text(creds.to_json(), encoding="utf-8")
    return creds


def upload(video: Path, plan: dict, cfg: dict) -> str:
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload

    yt = cfg["youtube"]
    creds = _credentials(cfg["_dir"], yt["client_secret_file"])
    service = build("youtube", "v3", credentials=creds)
    desc = f"{plan['description'].strip()}\n\n{AI_NOTICE}"
    body = {
        "snippet": {
            "title": plan["title"][:100],
            "description": desc[:5000],
            "tags": plan.get("tags", [])[:30],
            "categoryId": str(yt["category_id"]),
            "defaultLanguage": "ko",
        },
        "status": {
            "privacyStatus": yt["privacy"],
            "selfDeclaredMadeForKids": bool(yt["made_for_kids"]),
            "containsSyntheticMedia": True,
        },
    }
    req = service.videos().insert(part="snippet,status", body=body,
                                  media_body=MediaFileUpload(str(video), chunksize=8 << 20, resumable=True))
    response = None
    while response is None:
        status, response = req.next_chunk()
        if status:
            print(f"      업로드 {int(status.progress() * 100)}%")
    return response["id"]
