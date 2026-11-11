"""YouTube Data API 업로드. 영상은 비공개(=임시저장)로 올라간다.

최초 1회는 브라우저 로그인이 필요하고, 그 결과(token.json)는 채널 폴더에 저장되어
다음부터 자동으로 쓰인다. GitHub 실행용으로는 이 token.json 을 Secret 으로 넣는다.
"""

import json
from pathlib import Path

SCOPES = ["https://www.googleapis.com/auth/youtube.upload",
          "https://www.googleapis.com/auth/youtube.readonly"]
AI_NOTICE = "※ 이 영상의 화면과 음성은 AI로 생성되었습니다."
# 채널 언어 → 유튜브 언어 코드. '영상 언어'를 정확히 넣어야 그 언어권 시청자에게 노출된다.
LANG_CODE = {"Korean": "ko", "English": "en", "Japanese": "ja", "Spanish": "es",
             "French": "fr", "German": "de", "Portuguese": "pt", "Chinese": "zh"}


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


def uploaded_titles(cfg: dict) -> set[str]:
    """내 채널에 이미 올라간 영상 제목 집합. (중복 업로드 방지용)"""
    from googleapiclient.discovery import build

    creds = _credentials(cfg["_dir"], cfg["youtube"]["client_secret_file"])
    service = build("youtube", "v3", credentials=creds)
    ch = service.channels().list(part="contentDetails", mine=True).execute()
    if not ch.get("items"):
        return set()
    uploads = ch["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"]
    titles, token = set(), None
    while True:
        r = service.playlistItems().list(part="snippet", playlistId=uploads,
                                          maxResults=50, pageToken=token).execute()
        for it in r.get("items", []):
            titles.add(it["snippet"]["title"])
        token = r.get("nextPageToken")
        if not token:
            break
    return titles


def upload(video: Path, plan: dict, cfg: dict, thumbnail: Path | None = None) -> str:
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload

    yt = cfg["youtube"]
    creds = _credentials(cfg["_dir"], yt["client_secret_file"])
    service = build("youtube", "v3", credentials=creds)
    disclose = yt.get("ai_disclosure", True)
    desc = plan["description"].strip() + (f"\n\n{AI_NOTICE}" if disclose else "")
    lang = LANG_CODE.get(cfg.get("language", ""), "en")
    body = {
        "snippet": {
            "title": plan["title"][:100],
            "description": desc[:5000],
            "tags": plan.get("tags", [])[:30],
            "categoryId": str(yt["category_id"]),
            "defaultLanguage": lang,       # 제목·설명의 언어
            "defaultAudioLanguage": lang,  # 내레이션(오디오) 언어 — 노출 대상 결정의 핵심
        },
        "status": {
            "privacyStatus": yt["privacy"],
            "selfDeclaredMadeForKids": bool(yt["made_for_kids"]),
            "containsSyntheticMedia": bool(disclose),
        },
    }
    req = service.videos().insert(part="snippet,status", body=body,
                                  media_body=MediaFileUpload(str(video), chunksize=8 << 20, resumable=True))
    response = None
    while response is None:
        status, response = req.next_chunk()
        if status:
            print(f"      업로드 {int(status.progress() * 100)}%")
    vid = response["id"]

    # 커스텀 썸네일 세팅. 유튜브는 '채널 전화 인증'이 돼 있어야 커스텀 썸네일을 허용한다.
    # 미인증이면 403 이 나는데, 업로드 자체는 성공했으므로 경고만 찍고 넘어간다.
    if thumbnail is not None and Path(thumbnail).exists():
        try:
            service.thumbnails().set(
                videoId=vid, media_body=MediaFileUpload(str(thumbnail))).execute()
            print("      썸네일 설정 완료 ✓")
        except Exception as e:  # noqa: BLE001
            print(f"      [경고] 커스텀 썸네일 설정 실패(채널 전화 인증 필요?): {e}")
    return vid


def set_thumbnail(cfg: dict, video_id: str, thumb: Path) -> None:
    """이미 올라간 영상의 '썸네일만' 교체한다(영상 재업로드 없음). 채널 전화 인증 필요."""
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload

    creds = _credentials(cfg["_dir"], cfg["youtube"]["client_secret_file"])
    service = build("youtube", "v3", credentials=creds)
    service.thumbnails().set(
        videoId=video_id, media_body=MediaFileUpload(str(thumb))).execute()
