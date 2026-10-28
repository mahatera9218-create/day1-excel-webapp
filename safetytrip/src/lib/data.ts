/**
 * 데이터 접근 계층.
 *  - DATABASE_URL 이 있으면 PostgreSQL + PostGIS (프로덕션 경로).
 *  - 없으면 src/data/seed-data.ts 를 쓰는 인메모리 fallback (로컬/CI/데모).
 * 두 경로 모두 동일한 도메인 객체를 반환한다. 거리 로직은 단일 소스(distance.ts).
 */
import {
  classifyMeters,
  computeNearbyStations,
  DISTANCE_BASIS,
  type Classification,
  type LatLon,
} from "./distance";
import {
  areas as seedAreas,
  cities as seedCities,
  properties as seedProps,
  stations as seedStations,
  type Property,
} from "@/data/seed-data";

export interface PropertySummary {
  id: string;
  slug: string;
  name: string;
  name_local: string | null;
  area_slug: string;
  area_name_ko: string | null;
  address: string | null;
  verified_at: string | null;
  status: string;
}

export interface NearestStation {
  id: string;
  name: string;
  straight_distance_m: number;
  distance_basis: typeof DISTANCE_BASIS;
  classification: Classification;
}

export interface PropertyDetail extends PropertySummary {
  city: string;
  location: LatLon | null;
  nearest_station: NearestStation | null;
  limitations: string[];
}

const LIMITATIONS = ["NOT_WALKING_DISTANCE", "NOT_A_SAFETY_RATING"];

export const usingDatabase = (): boolean => !!process.env.DATABASE_URL;

// ---------------------------------------------------------------------------
// Fallback (in-memory) 구현
// ---------------------------------------------------------------------------
const areaById = new Map(seedAreas.map((a) => [a.id, a]));
const toLatLon = (lat: number | null, lon: number | null): LatLon | null =>
  lat === null || lon === null ? null : { lat, lon };

function toSummary(p: Property): PropertySummary {
  const area = areaById.get(p.area_id);
  return {
    id: p.id,
    slug: p.slug,
    name: p.name,
    name_local: p.name_local,
    area_slug: area?.slug ?? "",
    area_name_ko: area?.name_ko ?? null,
    address: p.address,
    verified_at: p.verified_at,
    status: p.status,
  };
}

function nearestFor(p: Property): NearestStation | null {
  const loc = toLatLon(p.lat, p.lon);
  const stationLikes = seedStations
    .filter((s) => s.city_id === p.city_id)
    .map((s) => ({ id: s.id, name: s.name, location: toLatLon(s.lat, s.lon) }));
  const [top] = computeNearbyStations(loc, stationLikes, 1);
  return top ?? null;
}

const fallback = {
  cities: () => seedCities.map((c) => ({ slug: c.slug, name_ko: c.name_ko, country_code: c.country_code })),
  areas: (citySlug: string) => {
    const city = seedCities.find((c) => c.slug === citySlug);
    if (!city) return [];
    return seedAreas.filter((a) => a.city_id === city.id).map((a) => ({ slug: a.slug, name_ko: a.name_ko }));
  },
  searchProperties: ({ citySlug, areaSlug, q, limit }: SearchArgs): PropertySummary[] => {
    const city = seedCities.find((c) => c.slug === citySlug);
    if (!city) return [];
    const area = areaSlug ? seedAreas.find((a) => a.city_id === city.id && a.slug === areaSlug) : undefined;
    const needle = (q ?? "").trim().toLowerCase();
    let rows = seedProps.filter((p) => p.city_id === city.id && p.status !== "closed");
    if (area) rows = rows.filter((p) => p.area_id === area.id);
    if (needle.length >= 2) {
      rows = rows.filter(
        (p) =>
          p.name.toLowerCase().includes(needle) ||
          (p.name_local ?? "").toLowerCase().includes(needle) ||
          (p.address ?? "").toLowerCase().includes(needle),
      );
      // 명칭 일치도 우선(접두 일치 우선), 이후 검증 상태, 안정적 id 정렬
      rows.sort((a, b) => {
        const ap = a.name.toLowerCase().startsWith(needle) ? 0 : 1;
        const bp = b.name.toLowerCase().startsWith(needle) ? 0 : 1;
        if (ap !== bp) return ap - bp;
        const av = a.verified_at ? 0 : 1;
        const bv = b.verified_at ? 0 : 1;
        if (av !== bv) return av - bv;
        return a.id.localeCompare(b.id);
      });
    } else {
      rows.sort((a, b) => a.id.localeCompare(b.id));
    }
    return rows.slice(0, limit).map(toSummary);
  },
  getProperty: (idOrSlug: string): PropertyDetail | null => {
    const p = seedProps.find((x) => x.id === idOrSlug || x.slug === idOrSlug);
    if (!p) return null;
    const city = seedCities.find((c) => c.id === p.city_id);
    return {
      ...toSummary(p),
      city: city?.slug ?? "",
      location: toLatLon(p.lat, p.lon),
      nearest_station: nearestFor(p),
      limitations: LIMITATIONS,
    };
  },
  nearbyStations: (idOrSlug: string, limit: number): NearestStation[] => {
    const p = seedProps.find((x) => x.id === idOrSlug || x.slug === idOrSlug);
    if (!p) return [];
    const loc = toLatLon(p.lat, p.lon);
    const stationLikes = seedStations
      .filter((s) => s.city_id === p.city_id)
      .map((s) => ({ id: s.id, name: s.name, location: toLatLon(s.lat, s.lon) }));
    return computeNearbyStations(loc, stationLikes, limit);
  },
};

export interface SearchArgs {
  citySlug: string;
  areaSlug?: string;
  q?: string;
  limit: number;
}

// ---------------------------------------------------------------------------
// 공개 facade — DB 경로는 TODO(PostGIS). 현재는 fallback 사용.
// ---------------------------------------------------------------------------
// NOTE: DB 경로 구현 시 db/queries/nearby_stations.sql 과 0001_init.sql 사용.
//       classifyMeters()/DISTANCE_BASIS 로 동일 분류를 적용해 두 경로 결과를 맞춘다.
export const data = {
  cities: async () => fallback.cities(),
  areas: async (citySlug: string) => fallback.areas(citySlug),
  searchProperties: async (args: SearchArgs) => fallback.searchProperties(args),
  getProperty: async (idOrSlug: string) => fallback.getProperty(idOrSlug),
  nearbyStations: async (idOrSlug: string, limit: number) => fallback.nearbyStations(idOrSlug, limit),
  compare: async (ids: string[]): Promise<{ items: PropertyDetail[]; skipped: string[] }> => {
    const seen = new Set<string>();
    const items: PropertyDetail[] = [];
    const skipped: string[] = [];
    for (const id of ids) {
      if (seen.has(id)) continue; // 중복 ID 제거
      seen.add(id);
      const d = fallback.getProperty(id);
      if (d) items.push(d);
      else skipped.push(id); // 무효 ID는 건너뛰되 안내
    }
    return { items, skipped };
  },
};

export { classifyMeters };
