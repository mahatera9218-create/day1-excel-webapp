# 내 PC로 영상 만들기 (쉬운 설명서)

내 컴퓨터 그래픽카드로 **그림을 공짜로** 만들어서 영상을 뽑고 유튜브에 올린다.
스마트플러그로 **PC를 켜면 알아서 다 하고, 끝나면 알아서 꺼진다.**

```
플러그가 PC 켬 → 알아서 영상 2편 만들고 유튜브에 비공개 업로드 → PC 스스로 꺼짐
```

> 어려워 보여도, 아래 **복사(복붙)** 만 순서대로 하면 됩니다. 막히면 그 화면을 저한테 주세요.

---

## 준비물
- 윈도우 PC (그래픽카드 RTX 3060 Ti) — 그래픽 드라이버는 보통 이미 깔려 있음
- 빈 저장공간 20GB 쯤

---

## 1단계 · 설치 (한 줄)

1. 시작 버튼 옆 검색창에 **powershell** 입력 → **관리자 권한으로 실행** (마우스 오른쪽 클릭)
2. 아래를 **복사해서 붙여넣고 엔터:**

```powershell
cd C:\mruntold\day1-excel-webapp\youtube-auto\local-render; powershell -ExecutionPolicy Bypass -File setup.ps1
```

   (처음이라 위 폴더가 없다고 뜨면, 먼저 이 한 줄부터:)
```powershell
git clone https://github.com/mahatera9218-create/day1-excel-webapp C:\mruntold\day1-excel-webapp
```
   ※ `git` 이 없다고 하면: 검색창에 "소프트웨어 설치" 어쩌구 뜨는 거 설치하거나, 저한테 알려주세요.

→ 프로그램들과 **그림 생성기(ComfyUI) + 그림 모델**을 자동으로 깝니다.
   **모델이 7GB라 시간이 좀 걸려요**(커피 한 잔). 다 되면 "설치 끝!" 이 떠요.

---

## 2단계 · 딱 한 번만 설정 (5개)

**① 유튜브 로그인** (영상을 올릴 수 있게)
powershell에 복붙:
```powershell
cd C:\mruntold\day1-excel-webapp\youtube-auto; python -m autotube auth world
```
→ 브라우저가 뜨면 **내 유튜브 계정으로 로그인 → 허용**. 끝.

**② PC가 "전기 들어오면 저절로 켜지게"** (스마트플러그로 켜려면 필요)
- PC 켤 때 **Del 키**(또는 F2)를 연타해서 파란 설정화면(BIOS)에 들어감
- "Power" 메뉴에서 **"Restore on AC Power"**(또는 비슷한 말) 를 **"On / Power On"** 으로 바꾸고 저장·종료
- ※ 이 메뉴 못 찾겠으면 PC 모델명을 저한테 주세요. 찾아드립니다.

**③ 켜지면 자동 로그인되게**
- 검색창에 **netplwiz** 입력 → 실행
- "사용자 이름과 암호를 입력해야…" **체크 해제** → 암호 한 번 입력

**④ "켜지면 자동으로 영상 만들기" 등록**
powershell(관리자)에 복붙:
```powershell
cd C:\mruntold\day1-excel-webapp\youtube-auto\local-render; powershell -ExecutionPolicy Bypass -File install_task.ps1
```

**⑤ 스마트플러그 앱에서 시간 예약**
- 매일 **켜는 시간** 하나 (예: 오후 1시)
- 혹시 몰라 **끄는 시간** 하나 더 (예: 오후 3시) — PC는 알아서 꺼지지만 안전용

---

## 3단계 · 잘 되나 한 번 테스트

powershell에 복붙:
```powershell
cd C:\mruntold\day1-excel-webapp\youtube-auto\local-render; powershell -ExecutionPolicy Bypass -File render_once.ps1
```
- 영상이 만들어지고 유튜브(비공개)에 올라갑니다.
- 끝에 **"2분 뒤 꺼진다"** 가 뜨는데, **끄기 싫으면** 새 powershell 창에 복붙:
```powershell
shutdown /a
```

잘 되면 끝! 이제 **플러그 예약 시간마다 알아서** 영상이 쌓입니다.

---

## 막히면
- 빨간 글씨(에러)가 뜨면 **그 화면을 캡처하거나 복사해서 저한테** 주세요. 바로 고쳐드립니다.
- 기록은 여기 남아요: `C:\mruntold\render_last.log` (이 파일을 줘도 됩니다)

## 두 가지만 기억
1. **지금 쓰는 클라우드(자동)는 아직 끄지 마세요.** 로컬이 잘 도는 거 확인되면, "이제 클라우드 끄자" 한마디 하시면 제가 넘겨드립니다. 그 전까진 매일 영상 안 끊겨요.
2. 로컬이 돌기 시작하면 — 그림이 공짜니까 **컷(장면)을 더 많이·빠르게** 넣는 업그레이드도 이어서 해드릴게요.
