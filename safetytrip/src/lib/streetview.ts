/**
 * Google Street View 연동 유틸.
 *  - 촬영일/가용성은 Street View Image Metadata 엔드포인트로 조회(무료, 쿼리 비용 0).
 *    https://developers.google.com/maps/documentation/streetview/metadata
 *  - 표시는 Maps Embed API(iframe, 무료·무제한) 사용.
 *    https://developers.google.com/maps/documentation/embed
 *  - 키가 없으면(데모) 메타데이터 없이 placeholder를 보여주고 임의값을 만들지 않는다.
 *
 * 환경변수:
 *   GOOGLE_MAPS_API_KEY            (서버: 메타데이터 조회용. 서버에서만 사용)
 *   NEXT_PUBLIC_GOOGLE_MAPS_EMBED_KEY (클라이언트 iframe URL에 노출. HTTP 리퍼러 제한 권장)
 */
import type { LatLon } from "./distance";

export interface StreetViewMeta {
  /** 거리뷰 파노라마 존재 여부(status === "OK"). */
  available: boolean;
  /** 촬영 연-월 "YYYY-MM" 또는 "YYYY". 메타데이터에 없을 수 있음 → null. */
  date: string | null;
  /** 저작권 문구(있으면). */
  copyright: string | null;
  /** 키가 없어 조회하지 못한 데모 상태인지. */
  unconfigured: boolean;
}

const METADATA_ENDPOINT = "https://maps.googleapis.com/maps/api/streetview/metadata";

/**
 * 좌표에 대한 Street View 메타데이터 조회(서버 전용).
 * 키가 없으면 unconfigured=true 로 반환(네트워크 호출 안 함).
 */
export async function streetViewMeta(loc: LatLon | null): Promise<StreetViewMeta> {
  const empty = (unconfigured: boolean): StreetViewMeta => ({
    available: false,
    date: null,
    copyright: null,
    unconfigured,
  });
  if (!loc) return empty(false);
  const key = process.env.GOOGLE_MAPS_API_KEY;
  if (!key) return empty(true);

  try {
    const url = `${METADATA_ENDPOINT}?location=${loc.lat},${loc.lon}&source=outdoor&key=${key}`;
    const res = await fetch(url, { next: { revalidate: 60 * 60 * 24 } });
    if (!res.ok) return empty(false);
    const json = (await res.json()) as { status?: string; date?: string; copyright?: string };
    if (json.status !== "OK") return empty(false); // ZERO_RESULTS 등 → 거리뷰 없음
    return {
      available: true,
      date: typeof json.date === "string" ? json.date : null, // 없으면 "촬영 시점 미상"
      copyright: typeof json.copyright === "string" ? json.copyright : null,
      unconfigured: false,
    };
  } catch {
    return empty(false);
  }
}

/** 클라이언트 임베드 키(있으면). iframe URL에 들어가므로 공개되어도 되는(리퍼러 제한) 키. */
export function embedKey(): string | null {
  return process.env.NEXT_PUBLIC_GOOGLE_MAPS_EMBED_KEY || null;
}

/** Maps Embed API Street View iframe URL. 키 없으면 null. heading 기본값은 호출부에서 계산. */
export function streetViewEmbedUrl(loc: LatLon, opts?: { heading?: number | null; pitch?: number; fov?: number }): string | null {
  const key = embedKey();
  if (!key) return null;
  const params = new URLSearchParams({
    key,
    location: `${loc.lat},${loc.lon}`,
    fov: String(opts?.fov ?? 90),
    pitch: String(opts?.pitch ?? 0),
  });
  if (opts?.heading != null) params.set("heading", String(Math.round(opts.heading)));
  return `https://www.google.com/maps/embed/v1/streetview?${params.toString()}`;
}

/** 촬영일 라벨(한국어). null이면 미상. */
export function formatCaptureDate(date: string | null): string {
  if (!date) return "촬영 시점 미상";
  const [y, m] = date.split("-");
  return m ? `${y}년 ${Number(m)}월 촬영` : `${y}년 촬영`;
}
