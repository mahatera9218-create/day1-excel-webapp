# AI 유튜브 자동 제작 (autotube)

주제 하나만 넣으면 **대본 → 영상(음성 포함) → 자막 → 유튜브 업로드**까지 자동으로 만들어 줍니다.

```
주제 ──▶ Claude: 제목·설명·태그·장면별 내레이션/연출
     ──▶ Pika API (H3): 장면마다 5~15초 영상 + 내레이션 음성 + 효과음 + 음악
     ──▶ ffmpeg: 규격 통일 → 이어 붙이기 → 한글 자막 → (선택) 배경음악
     ──▶ YouTube: 비공개로 업로드 (AI 생성 표시 포함)
```

## 1. 준비물

| 항목 | 받는 곳 | 비용 |
|---|---|---|
| Python 3.11+ | python.org | 무료 |
| ffmpeg | `winget install ffmpeg` | 무료 |
| Anthropic API 키 | console.anthropic.com | 영상 1편 대본 약 100~300원 |
| Pika API 키 | dev.pika.art | 768p 기준 초당 $0.08 → 50초 쇼츠 약 **$4** |
| 구글 OAuth 파일 | 아래 "YouTube 업로드 설정" | 무료 |

## 2. 실행

Windows 는 **`run.bat` 더블클릭**이 끝입니다. 처음 실행하면 패키지를 설치하고 `.env`를 열어 줍니다. 키를 넣고 다시 실행하세요.

직접 실행할 때:

```bash
pip install -r requirements.txt
cp .env.example .env            # 키 입력
cp config.example.yaml config.yaml

python -m autotube run --mock   # ① 돈 안 드는 시험 실행 (가짜 영상)
python -m autotube run --topic "번개가 치는 순간 실제로 일어나는 일" --no-upload   # ② 실제 생성, 업로드 X
python -m autotube upload output/<폴더>                                           # ③ 확인 후 업로드
```

단계별로 나눠서 돌릴 수도 있습니다. **대본을 사람이 한 번 고치는 걸 권장합니다** (아래 "수익화" 참고).

```bash
python -m autotube plan --topic "..."     # output/<폴더>/plan.json 생성 → 열어서 수정
python -m autotube render output/<폴더>   # 비용 확인 후 생성. 중간에 끊겨도 다시 실행하면 이어서 함
python -m autotube assemble output/<폴더> # final.mp4
python -m autotube upload output/<폴더>
```

`--topic` 을 빼면 `topics.txt` 에서 아직 안 만든 주제를 위에서부터 씁니다.

## 3. 설정 (`config.yaml`)

- `channel.concept` — 채널 콘셉트. 대본 품질에 가장 큰 영향을 줍니다.
- `channel.visual_style` — 모든 장면에 공통으로 붙는 화풍 (장면끼리 톤 통일)
- `video.format` — `shorts`(세로) / `long`(가로)
- `pika.max_cost_usd` — 1편당 비용 상한. 넘으면 시작하지 않습니다.
- `pika.model_path` — Pika API 모델 경로. 기본은 `minimax/h3/text-to-video`
- `subtitles.font` — Windows `Malgun Gothic`, Mac `Apple SD Gothic Neo`

## 4. YouTube 업로드 설정 (최초 1회)

1. [Google Cloud Console](https://console.cloud.google.com/) → 새 프로젝트
2. "API 및 서비스 → 라이브러리" → **YouTube Data API v3** 사용 설정
3. "OAuth 동의 화면" → 외부 → 테스트 사용자에 본인 구글 계정 추가
4. "사용자 인증 정보 → OAuth 클라이언트 ID → **데스크톱 앱**" → JSON 다운로드
5. 파일을 이 폴더에 `client_secret.json` 으로 저장

첫 업로드 때 브라우저가 열리고 로그인하면 `token.json` 이 생겨 다음부터는 자동입니다.
테스트 상태의 구글 프로젝트는 업로드 영상이 비공개로 잠길 수 있으니, 공개 운영 전에 YouTube API 감사(audit)를 신청하세요.

## 5. 수익화 — 꼭 읽어주세요

- **유튜브는 "대량 생산·반복형" 콘텐츠를 수익화에서 제외합니다.** 같은 틀로 찍어낸 영상만 올리면 파트너 프로그램 심사에서 떨어지기 쉽습니다.
  주제 선정과 `plan.json` 대본 검토·수정은 사람이 하고, 반복 작업만 자동화하는 걸 권합니다.
- 업로드는 기본이 **비공개**입니다. YouTube Studio 에서 직접 보고 공개하세요.
- AI 생성 영상이라는 표시(`containsSyntheticMedia`)와 설명란 안내 문구가 자동으로 들어갑니다. 유튜브 정책과 MiniMax H3 이용 정책 모두 요구하는 사항이니 지우지 마세요.
- 대본은 사실 위주로 쓰도록 지시되어 있지만 AI 는 틀릴 수 있습니다. 수치·역사적 사실은 올리기 전에 확인하세요.

## 6. 라이선스 메모

Pika-H3-Flex **오픈 모델(직접 다운로드해서 돌리는 버전)** 은 MiniMax H3 Community License 를 따르며,
이 라이선스는 **대한민국·미국·EU·영국을 사용 지역에서 제외**합니다. 그래서 이 프로젝트는 오픈 모델이 아니라 **Pika 유료 API** 를 씁니다.
API 는 Pika 서비스 약관을 따르므로, 수익 채널을 시작하기 전에 dev.pika.art 약관에서 상업적 이용 조건을 한 번 확인하세요.

## 7. 문제 해결

- **Pika 요청이 400/422 로 실패** — 모델마다 파라미터 이름이 조금씩 다릅니다. dev.pika.art 의 해당 모델 페이지를 보고 `pika.extra_body` 나 `pika.model_path` 를 맞춰주세요. 에러 메시지에 틀린 필드가 나옵니다.
- **자막 글자가 네모(□)로 나옴** — `subtitles.font` 를 PC에 설치된 한글 글꼴 이름으로 바꾸세요.
- **내레이션이 장면보다 길어 잘림** — `plan.json` 에서 해당 장면 `narration` 을 줄이거나 `duration` 을 늘린 뒤 그 장면 클립(`clips/scene_XX.mp4`)만 지우고 `render` 를 다시 실행하세요.
