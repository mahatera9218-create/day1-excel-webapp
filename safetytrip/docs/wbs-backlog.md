# SafetyTrip MVP — WBS → 개발 티켓 백로그

PRD v1.0 §12 WBS를 **GitHub 이슈 단위**로 분해한 것. 6주 목표.
라벨 규칙: `P0`/`P1`, 영역(`backend`/`frontend`/`data`/`infra`/`qa`), 상태는 GitHub로 관리.
각 티켓은 PRD의 FR/수락 기준에 매핑된다. ✅ 는 본 스캐폴딩에서 이미 구현/검증된 항목.

---

## 주차별 묶음 (마일스톤)

| 마일스톤 | 티켓 | 완료 기준 |
|---|---|---|
| M1 (1주) 기반 | T-01~T-04 | 홈·검색 기본 화면, DB 마이그레이션, 샘플 데이터, 개발환경 실행 |
| M2 (2주) 데이터·거리 | T-05~T-08 | 좌표 기반 최근접 역·거리 API 검증 |
| M3 (3주) 플로우 | T-09~T-12 | 검색→상세→지도 P0 연결 |
| M4 (4주) 비교·운영 | T-13~T-16 | 비교 링크 재현, 수동 데이터 수정 |
| M5 (5주) 품질 | T-17~T-20 | QA 케이스, 실데이터 검증, SEO·속도·접근성 |
| M6 (6주) 출시 게이트 | T-21~T-24 | 보안·법적 문구·관찰성·베타 |

---

## M1 — 프로젝트 기반

### T-01 · 프로젝트 셋업 (Next.js+TS+Tailwind) · `P0` `infra` ✅
- Next 14 App Router, TS strict, Tailwind, Vitest, lint/typecheck/build 스크립트.
- **완료:** `npm run build`·`typecheck`·`test` 통과.

### T-02 · DB 스키마 & 마이그레이션 (PostGIS) · `P0` `backend` `data` ✅(초안)
- `cities/areas/properties/stations/property_station_distances/sources/data_issues/audit_logs/property_aliases`.
- geography(Point,4326), GiST/GIN 인덱스, `property_status` ENUM, `distance_m >= 0` 체크.
- **완료:** `db/migrations/0001_init.sql`. **TODO:** 실 DB에서 apply 검증, 마이그레이션 도구 도입.
- 수락: 스키마가 PRD §6과 일치, lat/lon 순서 고정.

### T-03 · 샘플 데이터 시드 (도쿄 4개 지역) · `P0` `data` ✅(샘플)
- 역 8개 + 숙소 6개(동명 1쌍, 좌표 없는 1건 포함). SSOT = `src/data/seed-data.ts` ↔ `db/seed`.
- **TODO (D-01/D-04):** 검증된 실 역 중심점·실 숙소 소량으로 교체, 출처·검증일 기록.

### T-04 · 홈 + 지역 선택 UI · `P0` `frontend` ✅
- 검색창, 지역 칩, 서비스 소개, 모바일 우선. 수락: 320px 레이아웃 정상.

---

## M2 — 데이터 정제 & 거리 계산

### T-05 · 거리·분류 핵심 로직 · `P0` `backend` ✅(검증됨)
- 측지선 직선거리(m), 정수 반올림, 구간 라벨(300/600/1000 경계), 5km 상한, 좌표 검증.
- **완료:** `src/lib/distance.ts` + 20개 유닛테스트(경계값 포함) 통과.
- 수락(QA #4,5,6): 좌표 없음→미확인, 0m 금지, 경계 분류 정확.

### T-06 · 근접역 PostGIS 쿼리 + 캐시 · `P0` `backend` `data`
- `db/queries/nearby_stations.sql`(ST_DWithin 후보제한 + 역그룹 중복제거 + 안정정렬) 초안 존재.
- **TODO:** `data.ts` DB 경로 구현, `property_station_distances` 캐시 채우기/무효화 잡.
- 수락: 동일 좌표 일관 결과, 지도·거리 동일 좌표 사용.

### T-07 · 데이터 접근 계층 (DB | fallback) · `P0` `backend` ✅(fallback)
- `DATABASE_URL` 유무로 경로 분기. **완료:** fallback 전체. **TODO:** pg 경로 구현 + 통합테스트.

### T-08 · 거리/근접역 API · `P0` `backend` ✅
- `GET /properties/:id/nearby-stations`, 역 없음→`[]`+`resolved:false`, 0m 금지. **완료·스모크테스트 통과.**

---

## M3 — 검색·상세·지도

### T-09 · 검색 API + 결과 화면 · `P0` `backend` `frontend` ✅
- `GET /properties` (city/area/q/limit), debounce 300ms(FE), 2자 이상, 20건, URL 보존.
- 명칭 일치도→검증상태→id 정렬. 로딩/빈결과/오류 상태. **완료(서버측·UI)**; **TODO:** FE debounce·스켈레톤·네트워크 재시도.
- 수락(QA #1,2,3): 유효 숙소 목록, 동명 주소 구분, 결과없음 가이드.

### T-10 · 숙소 상세 화면 · `P0` `frontend` ✅
- 명칭/지역/주소/최근접역/직선거리/구간/출처/검증일/**필수 고지**/한계. 좌표 없으면 미확인, 404 처리.

### T-11 · 지도 통합 (MapLibre, 지연 로드) · `P0` `frontend` ◻︎
- 숙소 핀+역 핀+연결 직선(경로 아님), 동적 import, 로딩 실패해도 텍스트 유지, attribution.
- **의존:** D-03(타일 공급자). 현재 placeholder만. 수락(QA #10,14): 지도 실패시 텍스트 지속, attribution 노출.

### T-12 · 방법/개인정보 정적 페이지 · `P0` `frontend` ✅
- `/about/methodology`(직선거리 정의·한계·구간), `/privacy`(수집/보관/제3자).

---

## M4 — 비교·공유·운영

### T-13 · 비교함·공유 (URL 상태) · `P0` `backend` `frontend` ✅
- 최대 3, 중복 방지, 4번째 안내, 무효 ID skip+안내, URL 재현, PII 미저장.
- **완료·스모크테스트 통과.** 수락(QA #7,8,9).

### T-14 · 오류 신고 (API+UI) · `P1` `backend` `frontend` ◻︎(API stub)
- `POST /issues` 유형/설명(≤1000자)/선택연락처, HTML 제거, **TODO:** IP rate limit·저장·운영 상태전환·audit.
- 수락(QA #12): 특수문자/HTML 안전 저장·표시.

### T-15 · 관리자 CRUD + 캐시 재계산 · `P1` `backend` ⬜
- properties/stations/data_issues CRUD(최소 CSV import), 변경 시 거리 캐시 재계산, 공개 API 차단(RBAC).
- 수락(QA #13): 수정 후 거리 캐시 재계산·검증일 갱신.

### T-16 · 지역 경계 (D-05) · `P1` `data` ⬜
- 도쿄 4개 지역 polygon 또는 행정 기준. `areas.boundary_geom`.

---

## M5 — 품질·데이터·성능

### T-17 · QA 시나리오 자동화 · `P0` `qa`
- PRD §11 14개 시나리오. 거리 경계·0m 금지·비교 재현·지도 실패·320px·신고 sanitize 등. 일부 유닛/스모크 완료, E2E 추가.

### T-18 · 실데이터 교차 검증 · `P0` `data`
- 실 역/숙소 샘플 수동 교차 검증(D-01/D-04). 좌표·역 그룹 정책 확정.

### T-19 · SEO · `P0` `frontend`
- 고유 title/description, canonical, sitemap, robots, 데이터 없는 자동생성 페이지 색인 제한.

### T-20 · 성능·접근성 · `P0` `frontend`
- 모바일 Lighthouse Perf 80+/A11y 90+, LCP≤2.5s, CLS≤0.1. 지도 지연로드, 가벼운 첫화면, 서버 캐시.
- 접근성: 레이블·포커스·명도대비·지도 외 텍스트 동등 정보.

---

## M6 — 보안·법적·관찰성·출시

### T-21 · 보안 하드닝 · `P0` `backend` `infra`
- 서버 입력검증·SQL 파라미터화(✅ 설계), CSRF(상태변경), 관리자 RBAC, 비밀키 관리, 전 공개 API rate limit.

### T-22 · 법적/라이선스 점검 · `P0` `infra` `data`
- 지도/숙소/역 데이터 귀속·캐싱·상업 재배포 허용 검증(D-02/D-03), 일본 현지 개인정보·지도·상업데이터 검토.

### T-23 · 관찰성 · `P0` `infra`
- 구조화 로그, API 에러율·p95, 지도 로드 실패율, 검색 0건 비율, request_id. 분석 이벤트(§10, PII 미전송).

### T-24 · 배포 파이프라인 + 베타 · `P0` `infra`
- GitHub CI → test/build → preview → production. 환경변수/비밀키 서버 전용. 베타 사용자 테스트 → 출시 게이트 판단.

---

## 출시 게이트 (Definition of Done)

- [ ] P0 전체 완료 · 크리티컬 버그 0
- [ ] 핵심 QA 14개 통과
- [ ] 실 숙소·역 샘플 수동 교차 검증
- [ ] 법적/지도 데이터 이용권 점검
- [ ] 에러 모니터링 적용
- [ ] 개인정보 안내 페이지 공개

## 선결 블로커 (착수 전)

- **D-01** 샘플 숙소/역 데이터 확보 → T-03/T-18 차단
- **D-03** 지도 타일 공급자 → T-11 차단 (권장: MapLibre + Stadia/MapTiler, `providers-comparison.md`)
- **D-02** 지오코딩 캐싱 권한 → FR-02(T 미편성, flag off) 차단
