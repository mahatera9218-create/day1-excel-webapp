"""YouTube Data API 로 영상을 올린다. 처음 한 번은 브라우저에서 구글 로그인이 필요하다."""

from pathlib import Path

from .config import ROOT

SCOPES = ["https://www.googleapis.com/auth/youtube.upload"]
AI_NOTICE = "※ 이 영상의 화면과 음성은 AI(MiniMax H3 기반 Pika)로 생성되었습니다."


def _credentials(client_secret: Path):
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow

    token_path = ROOT / "token.json"
    creds = Credentials.from_authorized_user_file(str(token_path), SCOPES) if token_path.exists() else None
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
    if not creds or not creds.valid:
        if not client_secret.exists():
            raise SystemExit(f"[오류] {client_secret.name} 이(가) 없습니다. README 의 'YouTube 업로드 설정'을 따라 받아주세요.")
        creds = InstalledAppFlow.from_client_secrets_file(str(client_secret), SCOPES).run_local_server(port=0)
    token_path.write_text(creds.to_json(), encoding="utf-8")
    return creds


def upload(video: Path, plan: dict, cfg: dict) -> str:
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload

    yt = cfg["youtube"]
    shorts = cfg["video"]["format"] == "shorts"
    title = plan["title"][:100]
    description = f"{plan['description'].strip()}\n\n{AI_NOTICE}"
    if shorts:
        description += "\n\n#Shorts"

    service = build("youtube", "v3", credentials=_credentials(ROOT / yt["client_secret_file"]))
    request = service.videos().insert(
        part="snippet,status",
        body={
            "snippet": {
                "title": title,
                "description": description[:5000],
                "tags": plan.get("tags", [])[:30],
                "categoryId": str(yt["category_id"]),
                "defaultLanguage": "ko",
            },
            "status": {
                "privacyStatus": yt["privacy"],
                "selfDeclaredMadeForKids": bool(yt["made_for_kids"]),
                # 유튜브 정책상 실제처럼 보이는 AI 생성 콘텐츠는 공개 표시가 필요하다
                "containsSyntheticMedia": True,
            },
        },
        media_body=MediaFileUpload(str(video), chunksize=8 << 20, resumable=True, mimetype="video/mp4"),
    )
    response = None
    while response is None:
        status, response = request.next_chunk()
        if status:
            print(f"    업로드 {int(status.progress() * 100)}%")
    return response["id"]
