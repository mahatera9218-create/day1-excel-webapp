# AI 롱폼 유튜브 자동 제작 (autotube)

야담·역사 같은 **롱폼**을 반자동으로 만듭니다. **대본은 당신+Claude(월구독)**가 쓰고,
**목소리·그림·합성·업로드는 GitHub가 자동**으로 처리합니다.

```
① 대본   당신 + Claude로 작성/검토  →  plan.json (GitHub에 저장)
② 승인   script.md 읽고 OK          →  autotube approve
③ 자동   GitHub 버튼 한 번           →  목소리(ElevenLabs) + 그림(Pika)
                                        + 확대효과/영상 + 강조자막 + 쇼츠 + 비공개 업로드
```

## 어떻게 돌아가나 (중요)

- **월구독 ≠ API.** 구독은 당신이 Claude와 대화하며 **직접 글 쓰는 용도**입니다. 자동화가 API로 글을 대신 쓰지 않습니다.
- 그래서 **대본은 여기 Claude Code(또는 claude.ai)에서 당신+Claude가 작성**해 `plan.json`으로 저장합니다. 돈이 안 듭니다.
- 자동화가 **돈을 쓰는 건 그림·영상(Pika)과 목소리(ElevenLabs) 둘뿐**입니다.
- 무거운 영상 파일은 저장소에 담지 않고, **GitHub가 실행할 때마다 새로 만들어** 유튜브에 바로 올립니다. 당신 PC는 꺼놔도 됩니다.

## 폴더

```
youtube-auto/
├─ channels/yadam/channel.yaml   채널 설정 (콘셉트·화풍·목소리·길이·업로드)
├─ channels/yadam/topics.txt     소재 목록
├─ episodes/yadam/<편>/plan.json 편별 대본 (커밋됨)  ← 당신+Claude가 채움
├─ autotube/                     파이프라인 코드
└─ .github/workflows/render.yml  "영상 만들기" 버튼
```

## 쓰는 순서

**1) 대본 작성 (당신 + Claude)**
여기 Claude Code에 이렇게 말하면 됩니다:
> "yadam 채널 다음 편, 소재는 '구미호에게 장가든 선비'. plan.json 만들어줘."

Claude가 `episodes/yadam/<편>/plan.json`과 읽기용 `script.md`를 만듭니다. `script.md`를 읽고 고칠 곳을 알려주면 반영합니다.

**2) 승인**
```
autotube approve episodes/yadam/<편>
```
그리고 GitHub에 커밋/푸시합니다. (Claude에게 "커밋해줘" 하면 됩니다.)

**3) 영상 만들기 (GitHub 버튼)**
GitHub 저장소 → Actions 탭 → **영상 만들기** → Run workflow → 채널 이름 입력 → 실행.
폰의 GitHub 앱에서도 됩니다. 끝나면 유튜브에 **비공개**로 올라가 있고, 스튜디오에서 보고 공개만 누르면 됩니다.
(`final.mp4`·썸네일·쇼츠는 Actions 결과물에서 내려받을 수도 있습니다.)

## 처음 한 번: 키 등록 (GitHub Secrets)

저장소 → Settings → Secrets and variables → Actions → New repository secret 에 추가:

| 이름 | 값 | 받는 곳 |
|---|---|---|
| `PIKA_API_KEY` | Pika API 키 | dev.pika.art |
| `ELEVENLABS_API_KEY` | ElevenLabs API 키 | elevenlabs.io |
| `CLIENT_SECRET_JSON` | 구글 OAuth JSON 전체 내용 | 아래 참고 |
| `YOUTUBE_TOKEN_JSON` | 최초 로그인으로 생긴 token.json 내용 | 아래 참고 |

키가 준비되면 `channel.yaml`의 `engines.mode`를 `mock` → `real`로 바꾸고, `voice_id`에 ElevenLabs 목소리 ID를 넣으세요.

### YouTube 자동 업로드 설정 (최초 1회, 조금 번거롭습니다 — 같이 하면 됩니다)

1. [Google Cloud Console](https://console.cloud.google.com/)에서 프로젝트 생성 → **YouTube Data API v3** 사용 설정
2. OAuth 동의 화면 → 외부 → 테스트 사용자에 본인 구글 계정 추가
3. 사용자 인증 정보 → OAuth 클라이언트 ID → **데스크톱 앱** → JSON 다운로드
4. 그 JSON 내용을 `CLIENT_SECRET_JSON` Secret에 붙여넣기
5. 토큰 발급(브라우저 로그인)은 PC에서 한 번만: 파일을 `channels/yadam/client_secret.json`으로 두고
   `python -m autotube upload <편>` 를 로컬에서 한 번 실행 → 로그인하면 `channels/yadam/token.json` 생성
   → 그 내용을 `YOUTUBE_TOKEN_JSON` Secret에 붙여넣기

## 비용 (롱폼 25분 1편, 대략)

| 항목 | 양 | 비용 |
|---|---|---|
| 그림 | 40~70장 | 약 $1~3 |
| 영상 변환 | 몇 장면 | 약 $1~3 |
| ElevenLabs | 내레이션 | 요금제 크레딧 |
| 대본(당신+Claude) | - | $0 (구독) |

`channel.yaml`의 `engines.max_cost_usd`로 편당 상한을 둡니다. 넘으면 시작하지 않습니다.

## 채널 늘리기 (공격·수비 포트폴리오)

`channels/yadam/` 폴더를 통째로 복사해서 이름만 바꾸면 새 채널입니다.
```
channels/history/   (역사 미스터리 — 공격)
channels/sleep/     (잠잘 때 듣는 역사 — 수비)
```
`channel.yaml`의 콘셉트·화풍·목소리·`youtube` 설정만 바꾸면 됩니다. 업로드 토큰은 채널마다 따로 발급합니다.

## 수익화 — 꼭 지킬 것

- 유튜브는 **반복·대량 생산** 콘텐츠를 수익화에서 제외합니다. **②번 대본 검토를 사람이 하는 것**이 통과의 핵심입니다.
- 건강·투자·법률·정치 **조언**은 'AI 전문가 행세'로 분류돼 수익 제외 대상입니다. 야담·역사 **이야기**로 풀면 안전합니다.
- 업로드는 **비공개**가 기본입니다. 스튜디오에서 직접 확인하고 공개하세요.
- AI 생성 표시가 자동으로 들어갑니다. 유튜브 정책상 지우면 안 됩니다.
- 채널끼리 같은 영상을 돌려쓰지 마세요. 소재는 공유해도 대본·그림·음성은 새로 만들어야 합니다.

## 키 없이 시험하기

```
python -m autotube run yadam --mock
```
가짜 그림·무음으로 기획→완성까지 전체 흐름을 돈 없이 확인합니다. (`episodes/yadam/<편>/final.mp4`)
