/**
 * 근접역 직선거리 계산·분류 핵심 로직 (FR-03).
 *
 * 설계 원칙 (PRD §4 FR-03, §11 QA):
 *  - 좌표계: WGS84 (EPSG:4326). lat/lon 순서 고정.
 *  - 거리: 측지선 직선거리(미터). 도보거리/소요시간이 아니다.
 *  - 프로덕션 DB 경로는 PostGIS `ST_Distance(geography, geography)`(회전타원체) 사용.
 *    여기서는 동등 수준의 Haversine(구면)을 쓴다. 분류 경계(100m 단위)에서
 *    두 방식의 차이(<0.5%)는 라벨 결과를 바꾸지 않는다.
 *  - 반올림: 내부 계산은 실수 m, 화면/분류는 정수 m로 일관 반올림(Math.round).
 *  - 누락/범위 밖 좌표, 데이터 부재는 'unknown'으로 처리. 절대 0m로 대체하지 않는다.
 */

export const DISTANCE_BASIS = "station_center_geodesic" as const;

/** 역 데이터 탐색 상한. 이 반경 밖은 "확인 불가"로 처리하고 타지역까지 무한 탐색하지 않는다. */
export const MAX_SEARCH_RADIUS_M = 5000;

/** 거리 로직 버전. 변경 시 캐시(property_station_distances) 무효화 트리거. */
export const ALGORITHM_VERSION = "geodesic-haversine-v1";

export type Classification =
  | "매우 가까움"
  | "가까움"
  | "다소 이동 필요"
  | "접근성 추가 확인";

export interface LatLon {
  lat: number;
  lon: number;
}

/** 좌표 유효성 검증. 위도 -90..90, 경도 -180..180, 유한수. */
export function isValidLatLon(p: unknown): p is LatLon {
  if (!p || typeof p !== "object") return false;
  const { lat, lon } = p as Record<string, unknown>;
  return (
    typeof lat === "number" &&
    typeof lon === "number" &&
    Number.isFinite(lat) &&
    Number.isFinite(lon) &&
    lat >= -90 &&
    lat <= 90 &&
    lon >= -180 &&
    lon <= 180
  );
}

const EARTH_RADIUS_M = 6371008.8; // IUGG mean radius
const toRad = (deg: number) => (deg * Math.PI) / 180;

/**
 * 두 WGS84 좌표 사이 측지선 직선거리(미터, 실수).
 * 좌표가 유효하지 않으면 null (미확인). 0은 반환하되 그것은 "동일 지점"일 때만이며,
 * 누락을 0으로 대체하는 일은 호출부에서 금지된다(null로 전달).
 */
export function geodesicDistanceMeters(a: LatLon, b: LatLon): number | null {
  if (!isValidLatLon(a) || !isValidLatLon(b)) return null;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
  return EARTH_RADIUS_M * c;
}

/** 화면/분류용 정수 미터로 일관 반올림. null은 그대로 전달(미확인). */
export function displayMeters(raw: number | null): number | null {
  if (raw === null || !Number.isFinite(raw)) return null;
  return Math.round(raw);
}

/**
 * 거리 구간 라벨 (정수 m 기준):
 *   0~300     매우 가까움
 *   301~600   가까움
 *   601~1000  다소 이동 필요
 *   1001~     접근성 추가 확인
 * 이는 임시 UX 기준이며 위험·안전 판단이 아니다. 미확인(null)은 null.
 */
export function classifyMeters(meters: number | null): Classification | null {
  if (meters === null || !Number.isFinite(meters) || meters < 0) return null;
  if (meters <= 300) return "매우 가까움";
  if (meters <= 600) return "가까움";
  if (meters <= 1000) return "다소 이동 필요";
  return "접근성 추가 확인";
}

/**
 * A에서 B를 바라보는 초기 방위각(도, 0=북, 시계방향 0~360).
 * Street View heading 기본값으로 사용(숙소에서 최근접 역 방향을 바라보게).
 * 좌표가 유효하지 않으면 null.
 */
export function bearingDegrees(a: LatLon, b: LatLon): number | null {
  if (!isValidLatLon(a) || !isValidLatLon(b)) return null;
  const φ1 = toRad(a.lat);
  const φ2 = toRad(b.lat);
  const Δλ = toRad(b.lon - a.lon);
  const y = Math.sin(Δλ) * Math.cos(φ2);
  const x = Math.cos(φ1) * Math.sin(φ2) - Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);
  const θ = Math.atan2(y, x);
  return ((θ * 180) / Math.PI + 360) % 360;
}

export interface StationLike {
  id: string;
  name: string;
  location: LatLon | null;
}

export interface NearbyStation {
  id: string;
  name: string;
  straight_distance_m: number;
  distance_basis: typeof DISTANCE_BASIS;
  classification: Classification;
}

/**
 * 후보 역들 중 가장 가까운 상위 N개를 계산한다(기본 fallback 경로; 프로덕션은 PostGIS).
 *  - 숙소 좌표가 유효하지 않으면 [] 반환(상세에서 "미확인" 표시).
 *  - 좌표 없는 역은 제외.
 *  - MAX_SEARCH_RADIUS_M 밖의 역은 제외(잘못된 '최근접' 방지).
 *  - 동점은 안정적 정렬을 위해 id ASC로 깬다(PostGIS 쿼리의 `, s.id ASC`와 동일).
 */
export function computeNearbyStations(
  property: LatLon | null,
  stations: StationLike[],
  limit = 3,
): NearbyStation[] {
  if (!isValidLatLon(property)) return [];
  const scored: Array<{ s: StationLike; d: number }> = [];
  for (const s of stations) {
    if (!isValidLatLon(s.location)) continue;
    const raw = geodesicDistanceMeters(property, s.location);
    if (raw === null) continue;
    if (raw > MAX_SEARCH_RADIUS_M) continue;
    scored.push({ s, d: raw });
  }
  scored.sort((x, y) => (x.d !== y.d ? x.d - y.d : x.s.id.localeCompare(y.s.id)));
  return scored.slice(0, Math.max(0, limit)).map(({ s, d }) => {
    const m = displayMeters(d)!;
    return {
      id: s.id,
      name: s.name,
      straight_distance_m: m,
      distance_basis: DISTANCE_BASIS,
      classification: classifyMeters(m)!,
    };
  });
}
