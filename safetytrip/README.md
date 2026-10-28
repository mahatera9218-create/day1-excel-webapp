# SafetyTrip (안심트래블) — MVP 스캐폴딩

해외 숙소의 **역 접근성(직선거리)** 을 같은 기준으로 확인·비교하는 한국어·모바일 우선 웹앱.
본 디렉터리는 PRD v1.0 기준 **P0 스캐폴딩**이다. (루트의 엑셀 대시보드와는 별개 프로젝트)

> ⚠️ 직선거리 ≠ 도보거리/소요시간, 교통 접근성 ≠ 치안. 치안 등급·도보시간·역 출구 정보는 제공하지 않는다.

## 기술 스택

- **Next.js 14 (App Router) + TypeScript + Tailwind**
- **PostgreSQL + PostGIS** (프로덕션 데이터·거리 계산)
- 지도: MapLibre GL JS (지연 로드) — 타일 공급자는 [docs/providers-comparison.md](docs/providers-comparison.md) 참고
- 테스트: Vitest

## 실행

```bash
npm install
npm run dev        # http://localhost:3000
npm test           # 거리/분류 핵심 로직 유닛테스트 (20 cases)
npm run typecheck
npm run build
```

### DB 없이 동작

`DATABASE_URL` 이 없으면 `src/data/seed-data.ts` 기반 **인메모리 fallback**으로 동작한다
(로컬·CI·데모용). 프로덕션은 PostGIS 경로를 사용한다.

### DB 사용 (PostGIS)

```bash
export DATABASE_URL=postgres://user:pass@host:5432/safetytrip
npm run db:migrate   # db/migrations/*.sql
npm run db:seed      # db/seed/*.sql (샘플 데이터, 실재 숙소 아님)
```

## 구현 범위 (P0)

| 영역 | 상태 | 비고 |
|---|---|---|
| FR-01 검색 | ✅ API+UI | city/area/q, 20건, 2자 미만 안내, URL 보존 |
| FR-03 근접역 거리 | ✅ 검증됨 | 측지선 직선거리, 경계 분류, 5km 상한, 0m 금지 |
| FR-04 상세 | ✅ | 필수 고지·한계·검증일, 좌표 없으면 미확인 |
| FR-05 지도 | ◻︎ placeholder | MapLibre 연동 자리(지연 로드)만, 타일 공급자 결정 후 |
| FR-06 비교·공유 | ✅ | 최대 3, 중복/무효 ID 처리, URL 공유 |
| FR-07 오류 신고 | ◻︎ API stub | 검증·sanitize 포함, 저장/rate limit TODO |
| FR-02 지오코딩 | 🚫 flag off | `FEATURE_GEOCODING=on` + 공급자 어댑터 후 활성 |
| FR-08 관리자 | ⬜ 미착수 | Phase 후반 |

## 핵심 설계 원칙 (PRD 반영)

1. **데이터가 없으면 "확인 불가"** — 거리·역·도보시간을 임의 생성하지 않는다. 0m로 대체 금지.
2. **직선거리 ≠ 도보 ≠ 안전** — 모든 상세/비교 화면에 고지 문구 고정(`components/Disclaimer.tsx`).
3. **거리 로직 단일 소스** — `src/lib/distance.ts`. 캐시는 좌표/알고리즘 버전 변경 시 무효화.
4. **lat/lon 순서 고정**, 좌표 범위 검증, 안정적 정렬(거리 ASC, id ASC).

## 디렉터리

```
src/lib/distance.ts     # 거리·분류 핵심 (유닛테스트 대상)
src/lib/data.ts         # 데이터 접근 (PostGIS | fallback)
src/lib/http.ts         # API 응답/검증 유틸
src/app/api/v1/*        # REST 엔드포인트 (PRD §7)
src/app/*               # 홈/검색/상세/비교/방법/개인정보
db/migrations, db/seed, db/queries
docs/wbs-backlog.md         # WBS → 개발 티켓 (PRD §12)
docs/providers-comparison.md# 지도·지오코딩 공급자 라이선스 비교 (D-02, D-03)
tests/distance.test.ts
```

## 미결정 항목 (Open Decisions)

PRD §14 D-01~D-08. 특히 착수 전 필요: **D-03 지도 타일 공급자**, **D-01 샘플 숙소/역 데이터**.
자세한 비교·권장은 `docs/providers-comparison.md`.
