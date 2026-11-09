# Mr.Untold 로컬 렌더 (Windows + NVIDIA GPU)

본인 PC GPU로 **이미지를 공짜로** 만들어 렌더·업로드한다. 스마트플러그로 PC를 켜면
자동으로 돌고, 끝나면 **스스로 꺼진다.**

```
스마트플러그 ON(예약) → PC 부팅 → (작업 스케줄러) render_once.ps1
   → 최신 에피소드 git pull → ComfyUI(SDXL)로 이미지 생성(무료)
   → ffmpeg 합성 + edge-tts 음성(무료) → 유튜브 비공개 업로드 → PC 자동 종료
```

- **이미지 = 로컬 SDXL (공짜).** 모션(짧은 영상)은 Pika 키가 있으면 1~2컷만 사용(싸다), 없으면 스틸로.
- 클라우드 설정(`channel.yaml`)은 **안 건드린다** — 로컬 전환은 `AUTOTUBE_IMAGE_ENGINE=comfy` 환경변수로만. (render_once.ps1 이 자동 설정)

---

## 사전 준비
- Windows 10/11 + **NVIDIA RTX 3060 Ti** (최신 지포스 드라이버 설치되어 있을 것)
- 디스크 여유 ~20GB (ComfyUI + SDXL 모델)

## 1단계 — 설치 (자동)
관리자 PowerShell 에서:
```powershell
# 이 폴더(local-render)를 받은 위치에서, 혹은 아래처럼 스크립트만 먼저 받아 실행
powershell -ExecutionPolicy Bypass -File setup.ps1
```
이게 Git·Python·7zip·ffmpeg 설치 → 레포 클론(`C:\mruntold\day1-excel-webapp`) →
ComfyUI 포터블 + SDXL 모델 다운로드 → 파이썬 의존성 설치까지 한다. (모델 ~6.9GB 라 시간 걸림)

> ⚠️ 여기 스크립트는 제가 윈도우에서 직접 못 돌려봤어요. **에러 나오면 그 줄을 저한테 붙여주세요** — 바로 잡아드립니다.

## 2단계 — 한 번만 하는 수동 설정
1. **유튜브 인증.** `C:\mruntold\day1-excel-webapp\youtube-auto` 에서:
   ```powershell
   python -m autotube auth world
   ```
   브라우저로 로그인·허용 → `channels/world/token.json` 생성. (또는 GitHub Secret 의
   `YOUTUBE_TOKEN_JSON` 내용을 그 파일로 저장, `CLIENT_SECRET_JSON` → `client_secret.json`)
2. **git 로그인.** 처음 `git push` 할 때 GitHub 로그인 창이 뜨면 로그인(1회).
3. **(선택) 모션 쓰려면** `.env` 의 `PIKA_API_KEY=` 에 키 입력. 안 쓰면 비워두면 모션 장면은 스틸.
4. **BIOS: 전원 복구 시 자동 부팅.** BIOS → Power/APM 메뉴 →
   "Restore on AC Power Loss" / "AC Back" → **Power On** 으로. (스마트플러그가 전기를 넣으면 PC가 켜지게)
5. **윈도우 자동 로그인**(선택이지만 권장): `netplwiz` → "사용자 이름과 암호를 입력해야…" 체크 해제 →
   암호 입력. (부팅 후 바로 작업이 돌게)
6. **작업 스케줄러 등록:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File install_task.ps1
   ```
   부팅 3분 뒤 자동으로 `render_once.ps1` 실행된다.
7. **스마트플러그 앱:** 매일 **ON 스케줄**(예: 13:00) 설정. PC는 렌더 끝나면 스스로 꺼지므로,
   안전하게 플러그 **OFF 스케줄**도 1~2시간 뒤(예: 15:00)로 하나 걸어두면 좋다.

## 3단계 — 테스트 (중요)
자동 종료 없이 수동으로 한 번 돌려보기:
```powershell
cd C:\mruntold\day1-excel-webapp\youtube-auto\local-render
powershell -ExecutionPolicy Bypass -File render_once.ps1
# 렌더가 끝나고 'shutdown /s /t 120' 가 뜨면, 끄기 싫을 때 다른 창에서:
shutdown /a
```
`C:\mruntold\render_last.log` 에 로그가 남는다. 문제가 생기면 이 로그를 저에게 주세요.

---

## 클라우드 vs 로컬 — 중복 주의 (switchover)
지금은 **클라우드(GitHub Actions)가 매일 자동 렌더**하고 있습니다. 로컬도 같이 켜두면
클라우드가 먼저 렌더·업로드해버려서 로컬이 할 게 없어져요(중복 아님, 그냥 로컬이 빈손).

**→ 로컬이 잘 도는 걸 확인한 뒤**, 클라우드 자동 렌더를 끄고 로컬로 넘깁니다. 그 전환은
저한테 "로컬 테스트 성공, 클라우드 끄자" 하시면 제가 `render.yml` 의 자동 트리거를 내려드릴게요.
(그때까지는 클라우드가 계속 돌아서 매일 영상은 안 끊깁니다.)

## 참고
- **모델 교체:** 더 예쁜 체크포인트(.safetensors)를 `ComfyUI_windows_portable\ComfyUI\models\checkpoints`
  에 넣고, `.env` 에 `COMFY_CKPT=파일명.safetensors` 추가하면 그걸 씀. (기본은 SDXL base)
- **컷 수 늘리기(장면마다 새 이미지·빠른 컷):** 이미지가 공짜가 됐으니 이 업그레이드를 이어서
  할 겁니다 — 로컬이 돌기 시작하면 DRAFTING·파이프라인에 반영해 드립니다.
- **비용:** 이미지 0원(전기값만, 1회 렌더 몇 원). 모션 Pika만 소액.
