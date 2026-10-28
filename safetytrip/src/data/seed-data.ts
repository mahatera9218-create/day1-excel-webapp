/**
 * 표준 시드 데이터 (SSOT).
 *  - fallback 데이터 접근 계층과 유닛테스트가 이 모듈을 사용한다.
 *  - db/seed/0001_seed.sql 은 이 데이터를 그대로 미러링한다(둘이 어긋나면 안 됨).
 *  - 숙소는 전부 샘플/테스트 데이터이며 실재 숙소가 아니다(PRD §7 명시).
 *  - 역 좌표는 공개 지식 기반 근사치. 출시 전 검증 데이터로 교체 필요(D-04).
 */

export interface City {
  id: string;
  slug: string;
  name_ko: string;
  country_code: string;
}

export interface Area {
  id: string;
  city_id: string;
  slug: string;
  name_ko: string;
}

export interface Station {
  id: string;
  city_id: string;
  station_group_id: string;
  name: string;
  name_local: string;
  lat: number | null;
  lon: number | null;
  lines: string[];
  source_id: string;
  verified_at: string;
}

export interface Property {
  id: string;
  slug: string;
  city_id: string;
  area_id: string;
  name: string;
  name_local: string;
  address: string;
  lat: number | null;
  lon: number | null;
  source_id: string;
  verified_at: string | null;
  status: "public" | "closed" | "unverified_location";
}

export const cities: City[] = [
  { id: "city-tokyo", slug: "tokyo", name_ko: "도쿄", country_code: "JP" },
];

export const areas: Area[] = [
  { id: "area-shinjuku", city_id: "city-tokyo", slug: "shinjuku", name_ko: "신주쿠" },
  { id: "area-shibuya", city_id: "city-tokyo", slug: "shibuya", name_ko: "시부야" },
  { id: "area-ueno", city_id: "city-tokyo", slug: "ueno", name_ko: "우에노" },
  { id: "area-asakusa", city_id: "city-tokyo", slug: "asakusa", name_ko: "아사쿠사" },
];

const SRC = "src-sample";

export const stations: Station[] = [
  { id: "st-shinjuku", city_id: "city-tokyo", station_group_id: "grp-shinjuku", name: "Shinjuku", name_local: "新宿駅", lat: 35.6896, lon: 139.7006, lines: ["JR", "Odakyu", "Keio", "Tokyo Metro"], source_id: SRC, verified_at: "2026-10-01T00:00:00Z" },
  { id: "st-shinjuku-sanchome", city_id: "city-tokyo", station_group_id: "grp-shinjuku-sanchome", name: "Shinjuku-sanchome", name_local: "新宿三丁目駅", lat: 35.6916, lon: 139.705, lines: ["Tokyo Metro", "Toei"], source_id: SRC, verified_at: "2026-10-01T00:00:00Z" },
  { id: "st-shibuya", city_id: "city-tokyo", station_group_id: "grp-shibuya", name: "Shibuya", name_local: "渋谷駅", lat: 35.658, lon: 139.7016, lines: ["JR", "Tokyu", "Tokyo Metro"], source_id: SRC, verified_at: "2026-10-01T00:00:00Z" },
  { id: "st-harajuku", city_id: "city-tokyo", station_group_id: "grp-harajuku", name: "Harajuku", name_local: "原宿駅", lat: 35.6702, lon: 139.7026, lines: ["JR"], source_id: SRC, verified_at: "2026-10-01T00:00:00Z" },
  { id: "st-ueno", city_id: "city-tokyo", station_group_id: "grp-ueno", name: "Ueno", name_local: "上野駅", lat: 35.7141, lon: 139.7774, lines: ["JR", "Tokyo Metro"], source_id: SRC, verified_at: "2026-10-01T00:00:00Z" },
  { id: "st-okachimachi", city_id: "city-tokyo", station_group_id: "grp-okachimachi", name: "Okachimachi", name_local: "御徒町駅", lat: 35.7076, lon: 139.7745, lines: ["JR"], source_id: SRC, verified_at: "2026-10-01T00:00:00Z" },
  { id: "st-asakusa", city_id: "city-tokyo", station_group_id: "grp-asakusa", name: "Asakusa", name_local: "浅草駅", lat: 35.7119, lon: 139.7983, lines: ["Tokyo Metro", "Toei", "Tobu"], source_id: SRC, verified_at: "2026-10-01T00:00:00Z" },
  { id: "st-tawaramachi", city_id: "city-tokyo", station_group_id: "grp-tawaramachi", name: "Tawaramachi", name_local: "田原町駅", lat: 35.7101, lon: 139.792, lines: ["Tokyo Metro"], source_id: SRC, verified_at: "2026-10-01T00:00:00Z" },
];

export const properties: Property[] = [
  { id: "prop-shinjuku-sample", slug: "sample-hotel-shinjuku", city_id: "city-tokyo", area_id: "area-shinjuku", name: "Sample Hotel Shinjuku", name_local: "サンプルホテル新宿", address: "Tokyo, Shinjuku (sample address)", lat: 35.6905, lon: 139.701, status: "public", source_id: SRC, verified_at: "2026-10-01T00:00:00Z" },
  // US-02 / QA #2: 동명 숙소 — 이름 같고 주소/지역 다름
  { id: "prop-shinjuku-sample-2", slug: "sample-hotel-shinjuku-east", city_id: "city-tokyo", area_id: "area-shinjuku", name: "Sample Hotel Shinjuku", name_local: "サンプルホテル新宿イースト", address: "Tokyo, Shinjuku-sanchome (sample address, different building)", lat: 35.692, lon: 139.7055, status: "public", source_id: SRC, verified_at: "2026-10-01T00:00:00Z" },
  { id: "prop-shibuya-sample", slug: "sample-inn-shibuya", city_id: "city-tokyo", area_id: "area-shibuya", name: "Sample Inn Shibuya", name_local: "サンプルイン渋谷", address: "Tokyo, Shibuya (sample address)", lat: 35.659, lon: 139.703, status: "public", source_id: SRC, verified_at: "2026-10-01T00:00:00Z" },
  { id: "prop-ueno-sample", slug: "sample-ryokan-ueno", city_id: "city-tokyo", area_id: "area-ueno", name: "Sample Ryokan Ueno", name_local: "サンプル旅館上野", address: "Tokyo, Ueno (sample address)", lat: 35.7128, lon: 139.776, status: "public", source_id: SRC, verified_at: "2026-10-01T00:00:00Z" },
  { id: "prop-asakusa-sample", slug: "sample-stay-asakusa", city_id: "city-tokyo", area_id: "area-asakusa", name: "Sample Stay Asakusa", name_local: "サンプルステイ浅草", address: "Tokyo, Asakusa (sample address)", lat: 35.7112, lon: 139.7975, status: "public", source_id: SRC, verified_at: "2026-10-01T00:00:00Z" },
  // QA #4: 좌표 없는 숙소 — 거리값 생성 금지, "미확인" 표시
  { id: "prop-nocoord-sample", slug: "sample-stay-no-coords", city_id: "city-tokyo", area_id: "area-ueno", name: "Sample Stay (No Coordinates)", name_local: "サンプルステイ（座標未検証）", address: "Tokyo, Ueno (location not yet verified)", lat: null, lon: null, status: "unverified_location", source_id: SRC, verified_at: null },
];

export const sources = [
  {
    id: SRC,
    provider: "manual-sample",
    license_url: "",
    attribution: "Sample/test data for development. Not real listings.",
    retrieved_at: "2026-10-01T00:00:00Z",
    permitted_uses: "internal-development-only",
  },
];
