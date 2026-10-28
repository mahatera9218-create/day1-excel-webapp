# 지도·지오코딩 공급자 비교 — 결정 문서 (D-02, D-03)

PRD §14 Open Decisions 중 **D-03(지도 엔진/타일)** 과 **D-02(주소→좌표 지오코딩 + 캐싱 권한)** 을 위한 라이선스·비용 비교.

> 라이선스 조건은 2026-10-28 기준 조사. 조건은 수시로 바뀌므로 ⚠ 표시 항목은 **계약 전 서면 재확인** 필수.
> OpenCage·MapTiler 일부 약관 페이지는 조사 환경 네트워크 제한으로 직접 확인 불가 → 검색 스니펫/2차 출처 기반, 아래 ⚠ 로 표시.

---

## 결론 (요약)

- **D-03 (지도 엔진 + 타일): MapLibre GL JS + 유료 호스팅 벡터타일.**
  MVP는 **Stadia Maps Starter($20/mo)** 또는 **MapTiler Flex($25/mo)** — 둘 다 상업 라이선스·MapLibre 네이티브. 스타일 취향으로 선택(Stadia가 약간 저렴 + 초과분 하드리밋). 트래픽/비용 커지면 **Protomaps 셀프호스트(PMTiles)** 로 전환해 벤더 종속·타일당 비용 제거.
  ❌ 생 OSM 타일(상업 프로덕션 금지), ❌ Mapbox GL JS v2+(독점).

- **D-02 (지오코딩 + 캐싱): OpenCage 또는 LocationIQ(유료), 대안 self-host Nominatim.**
  FR-02가 **좌표를 DB에 영구 저장**해야 하므로, 저장 허용 + non-Google 지도(MapLibre) 병용 가능한 공급자만 적격.
  ❌ Google(비-Google 지도 금지 + 좌표 30일 삭제), ⚠ Mapbox(기본 temporary=저장 전면 금지, permanent 유료만 저장).

---

## D-03 — 지도 타일 / SDK

| 구성요소 | 오픈소스/셀프호스트 | 대략 비용 | 귀속 표기 | 핵심 상업 제약 | 판정 |
|---|---|---|---|---|---|
| **MapLibre GL JS** (렌더러) | ✅ BSD-3 / N/A | 무료 | 라이브러리 자체는 없음 | 렌더러일 뿐, 타일/스타일 소스 필요 | ✅ **엔진으로 채택**. Mapbox GL JS v1.13(마지막 BSD)의 포크 |
| **MapTiler** (타일/스타일) | ✗ / ✗(호스팅) | 무료=**비상업/R&D만**, Flex **$25/mo** 상업 | 유료 no-logo 아니면 로고 필수 | 무료는 비상업 명시 → 유료 필수 | ✅ 좋은 호스팅 벡터타일, $25/mo |
| **Stadia Maps** | ✗ / ✗(호스팅) | 무료=**비상업만**(20만 크레딧/mo), Starter **$20/mo**(~100만) | Stadia + OSM | 무료 비상업; 초과분 기본 하드리밋(폭탄 청구 없음) | ✅ 최저가 상업 옵션, MapLibre 지원 양호 |
| **Protomaps (PMTiles 셀프호스트)** | ✅ 개방/셀프호스트 | 베이스맵 무료, 비용=스토리지+대역폭(플래닛 ≈120GB, Cloudflare 실사용 ~$0–2/mo) | OSM/ODbL | 셀프호스트=무제한·API키 없음. 호스팅 데모 API는 상업시 GitHub Sponsor + 1M tiles/mo soft cap(핫링크 금지) | ✅ 규모 시 최저가·벤더 종속 없음, 빌드+호스팅 운영 추가 |
| **AWS Location Service** | ✗(MapLibre 클라) / ✗ | 신규 ~$200 프리티어 크레딧, 이후 종량 | AWS/공급자 | ⚠ geocode 저장은 "stored" 옵션(고가), 데이터 공급자 재사용 제약 | ◐ 이미 AWS면 가능, 가격/캐싱 모델 복잡 |
| **Mapbox GL JS v2+** | ❌ 2020.12부터 독점 / ✗ | 계정+ToS 필요 | Mapbox | v2+ BSD 폐기 → Mapbox 약관 수락 필요(MapLibre 포크 사유) | ❌ 오픈SDK 전략이면 회피, MapLibre 사용 |
| **생 OSM 타일** (tile.openstreetmap.org) | 데이터 개방/기부 서버 | "무료"지만 정책 제한 | OSM + 유효 User-Agent | OSMF 정책: 상업/대량 프로덕션 금지, 예고 없이 차단 | ❌ **프로덕션 금지** |

---

## D-02 — 지오코딩 (결정 축 = "좌표를 저장/캐싱할 수 있는가")

FR-02 "임시 숙소 위치 분석"을 좌우. 두 권리가 따로다: (1) 출력 **좌표를 DB에 저장**, (2) 지오코딩 좌표를 **non-Google 지도**(MapLibre)에 표시. 우리는 MapLibre 렌더이므로 (2)는 하드 제약.

| 공급자 | 오픈소스/셀프호스트 | 대략 비용 | 귀속 | 핵심 상업+캐싱 제약 | 판정 |
|---|---|---|---|---|---|
| **Google Geocoding** | ✗ / ✗ | ~$5/1k, 월 크레딧 | Google 로고/약관 | ⚠ 좌표 캐시 **최대 연속 30일 후 삭제**, place_id는 캐시 가능. **비-Google 지도와 사용 금지** | ❌ **부적격** — MapLibre 표시 + 영구 저장 둘 다 위반 |
| **Mapbox Geocoding** | ✗ / ✗ | temporary ~$0.75/1k, permanent ~$5/1k(확인) | Mapbox | **기본 temporary = 저장/캐싱 전면 금지(세션 한정)**. 저장은 `permanent=true`(카드/엔터프라이즈) 필요, 이후 영구 저장 가능 | ⚠ permanent 유료일 때만 FR-02 가능 |
| **MapTiler Geocoding** | ✗(OSM 데이터)/✗ | 무료=비상업, Flex $25/mo 상업 | MapTiler+OSM | ⚠ **상충 신호**: 제품/FAQ는 "좌표·메타 영구 저장 가능", JS 클라 readme는 "저장/재배포 금지". 서면 확인 필요 | ⚠ 유료 + 서면 확인 전제로 가능 |
| **LocationIQ** | ✗(OSM)/✗ | 무료 5,000/day·2req/s, 유료 ~$45/mo(확인) | 무료 플랜 "Search by LocationIQ" 링크 필수 | **출력 영구 저장 가능**. 요청→응답 "캐싱"은 시간제한(무료 48h, 유료 구독기간) | ✅ 저장 친화적; 무료는 귀속링크+상업 제한 |
| **OpenCage** | ✗(OSM/개방데이터 집계)/✗ | 무료 ~2,500/day(트라이얼), 유료 확장 | 하위 데이터 라이선스별(OSM 등) | ⚠ 가장 관대: **캐시/저장 무기한 + 어떤 지도와도 사용 가능**(리셀러 리스팅+포지셔닝). `no_record=true`로 자체 로깅 중단. ToS 문구 확인 | ✅ **FR-02 라이선스 적합도 최고** — MapLibre 병용·30일 제약 없음. 문구 확인 |
| **Nominatim (OSM)** | ✅ AGPL / ✅ | 공개서버 무료, 셀프호스트=인프라 비용 | OSM/ODbL | **공개서버:** 대량/상업 사용 비권장, 예고 없이 차단 → 프로덕션 부적합. **셀프호스트:** 무제한, 데이터는 ODbL | ✅ 셀프호스트=완전 저장 자유+쿼리당 비용 0, 운영 부담. ❌ 공개서버 프로덕션 금지 |

**FR-02 지침:** "임시 분석"이 세션 한정이면 거의 모든 공급자 가능. **좌표를 DB에 영구 저장**하는 순간 적격은 OpenCage · LocationIQ(유료) · Mapbox-permanent(유료) · self-host Nominatim (적합도-vs-노력 순).

---

## ⚠ 라이선스 함정 체크리스트

1. **Google "비-Google 지도" 조항** — Google 지오코딩 좌표를 MapLibre/OSM 타일에 표시 불가 + 좌표 캐시 30일 상한. 우리에겐 2중 부적격.
2. **Mapbox 기본 지오코딩 = temporary = 저장 전면 금지.** 영구 저장은 `permanent=true`(카드/엔터프라이즈, 고가). GL JS v2+도 독점 → MapLibre 사용.
3. **MapTiler·Stadia 무료 티어는 비상업만.** SafetyTrip은 상업 제품 → 1일차부터 유료(~$20–25/mo). 무료로 프로토타이핑 후 업그레이드 누락 주의.
4. **생 OSM 타일은 상업 프로덕션 금지** + 예고 없이 차단 가능. 벡터타일 정책은 별도로 동일하게 제한.
5. **OSM 파생 소스는 전부 귀속 표기 필수**(MapTiler/Stadia/LocationIQ/OpenCage/Protomaps/Nominatim). LocationIQ **무료**는 "Search by LocationIQ" 링크 추가 필요.
6. **LocationIQ "영구 저장" vs "캐싱"은 다른 권리** — 출력 저장은 영구, 요청→응답 캐싱은 시간제한(무료 48h/유료 구독기간).
7. **셀프호스트(Nominatim/Protomaps)** 는 벤더 비용 대신 ODbL 귀속 + 자체 인프라·빌드·갱신 책임.
8. **MapTiler ⚠ · OpenCage ⚠ 저장 권리는 서면 확인** — 제품 페이지 vs 클라 readme/리셀러 리스팅 신호 상충. 영구 저장 구현 전 공급자 지원팀 확인.

---

## 출처 (2026-10-28 확인)

- Google Maps Platform Service Specific Terms — https://cloud.google.com/maps-platform/terms/maps-service-terms/
- Mapbox Temporary vs Permanent Geocoding — https://docs.mapbox.com/help/dive-deeper/understand-temporary-vs-permanent-geocoding/
- Mapbox Geocoding API — https://docs.mapbox.com/api/search/geocoding/
- MapTiler Cloud Terms / Pricing — https://www.maptiler.com/cloud/terms/ , https://www.maptiler.com/cloud/pricing/
- LocationIQ 저장 FAQ / Pricing — https://help.locationiq.com/support/solutions/articles/36000216111 , https://locationiq.com/pricing
- OpenCage Pricing / client docs — https://opencagedata.com/pricing , https://docs.ropensci.org/opencage/
- Nominatim Usage Policy — https://operations.osmfoundation.org/policies/nominatim/
- OSMF Tile / Vector Tile Policy — https://operations.osmfoundation.org/policies/tiles/ , https://operations.osmfoundation.org/policies/vector/
- Protomaps FAQ / Downloads — https://protomaps.com/faq , https://docs.protomaps.com/basemaps/downloads
- AWS Location Pricing / FAQ — https://aws.amazon.com/location/pricing , https://aws.amazon.com/location/faqs
- Stadia Maps Pricing / FAQ — https://stadiamaps.com/pricing , https://stadiamaps.com/faqs/
- MapLibre 포크 배경 — https://thenewstack.io/maplibre-how-a-fork-became-a-thriving-open-source-project/

> 검증 메모: opencagedata.com·maptiler.com 직접 접속이 조사 환경 네트워크 정책으로 차단됨. 해당 저장 조건은 서면 재확인 후 확정할 것.
