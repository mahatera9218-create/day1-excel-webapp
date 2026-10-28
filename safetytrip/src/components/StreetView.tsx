import type { LatLon } from "@/lib/distance";
import { bearingDegrees } from "@/lib/distance";
import { formatCaptureDate, streetViewEmbedUrl, streetViewMeta } from "@/lib/streetview";

/**
 * 숙소 상세의 "실제 거리 모습" 섹션 (Street View).
 *  - 촬영일을 반드시 명시(최신성 투명 공개, 임의값 금지).
 *  - 거리뷰가 없으면 "거리뷰 없음", 키 미설정이면 데모 안내.
 *  - heading 기본값 = 숙소에서 최근접 역을 바라보는 방향.
 */
export async function StreetView({
  location,
  lookAt,
}: {
  location: LatLon | null;
  lookAt?: LatLon | null; // 바라볼 대상(최근접 역) — heading 계산용
}) {
  if (!location) {
    return (
      <section className="rounded-md border bg-white p-4">
        <h2 className="mb-2 text-sm font-semibold text-slate-500">실제 거리 모습</h2>
        <p className="text-sm text-slate-600">좌표가 없어 거리뷰를 표시할 수 없습니다.</p>
      </section>
    );
  }

  const meta = await streetViewMeta(location);
  const heading = lookAt ? bearingDegrees(location, lookAt) : null;
  const url = streetViewEmbedUrl(location, { heading });

  return (
    <section className="rounded-md border bg-white p-4">
      <div className="mb-2 flex items-baseline justify-between">
        <h2 className="text-sm font-semibold text-slate-500">실제 거리 모습</h2>
        {/* 촬영일: 최신성 투명 공개 */}
        {!meta.unconfigured && (
          <span className="rounded bg-slate-100 px-2 py-0.5 text-xs text-slate-600">
            {meta.available ? formatCaptureDate(meta.date) : "거리뷰 없음"}
          </span>
        )}
      </div>

      {url && meta.available ? (
        <iframe
          title="Street View"
          className="h-56 w-full rounded"
          loading="lazy"
          referrerPolicy="no-referrer-when-downgrade"
          src={url}
          allowFullScreen
        />
      ) : (
        <div className="flex h-56 flex-col items-center justify-center gap-1 rounded bg-slate-100 p-4 text-center text-sm text-slate-500">
          {meta.unconfigured ? (
            <>
              <p className="font-medium text-slate-600">Street View 데모 — API 키 미설정</p>
              <p className="text-xs">
                <code>NEXT_PUBLIC_GOOGLE_MAPS_EMBED_KEY</code>(iframe)와{" "}
                <code>GOOGLE_MAPS_API_KEY</code>(촬영일 메타데이터)를 설정하면
                이 자리에 실제 거리뷰와 촬영일이 표시됩니다.
              </p>
              <p className="mt-1 text-xs text-slate-400">
                heading(최근접 역 방향): {heading != null ? `${Math.round(heading)}°` : "—"} ·
                위치: {location.lat.toFixed(4)}, {location.lon.toFixed(4)}
              </p>
            </>
          ) : (
            <p>이 위치에는 거리뷰가 없습니다.</p>
          )}
        </div>
      )}

      <p className="mt-2 text-xs text-slate-400">
        거리뷰는 촬영 시점의 모습이며 실시간이 아닙니다. 폐업·공사 등 최신 변동은 반영되지 않을 수 있습니다.
        {meta.copyright ? ` ${meta.copyright}` : " © Google"}
      </p>
    </section>
  );
}
