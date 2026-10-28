import { notFound } from "next/navigation";
import Link from "next/link";
import { data } from "@/lib/data";
import { Disclaimer } from "@/components/Disclaimer";
import { StreetView } from "@/components/StreetView";

export const dynamic = "force-dynamic";

export default async function StayDetailPage({ params }: { params: { slug: string } }) {
  const detail = await data.getProperty(params.slug);
  if (!detail) notFound(); // 숙소 없음 = 404

  const near = detail.nearest_station;
  const stations = await data.nearbyStations(params.slug, 3);
  const stationLoc = await data.nearestStationLatLon(params.slug);

  return (
    <article className="space-y-4">
      <header>
        <h1 className="text-xl font-bold">{detail.name}</h1>
        {detail.name_local && <p className="text-sm text-slate-500">{detail.name_local}</p>}
        <p className="mt-1 text-sm text-slate-600">
          {detail.area_name_ko ?? detail.area_slug} · {detail.address}
        </p>
      </header>

      <section className="rounded-md border bg-white p-4">
        <h2 className="mb-2 text-sm font-semibold text-slate-500">가장 가까운 역</h2>
        {near ? (
          <div className="flex items-baseline justify-between">
            <span className="text-lg font-semibold">{near.name}</span>
            <span className="text-right">
              <span className="text-2xl font-bold">{near.straight_distance_m.toLocaleString()}</span>
              <span className="text-sm text-slate-500"> m</span>
              <span className="ml-2 rounded bg-slate-100 px-2 py-0.5 text-xs">{near.classification}</span>
            </span>
          </div>
        ) : (
          <p className="text-sm text-slate-600">
            {detail.location ? "반경 5km 내 역 정보 확인 불가" : "숙소 좌표 미검증 — 거리 확인 불가"}
          </p>
        )}
        {stations.length > 1 && (
          <ul className="mt-3 space-y-1 text-sm text-slate-600">
            {stations.slice(1).map((s) => (
              <li key={s.id} className="flex justify-between">
                <span>{s.name}</span>
                <span>{s.straight_distance_m.toLocaleString()} m · {s.classification}</span>
              </li>
            ))}
          </ul>
        )}
      </section>

      {/* 실제 거리 모습 (Street View) — 촬영일 명시. 실시간 아님. */}
      <StreetView location={detail.location} lookAt={stationLoc} />

      {/* 지도는 지연 로드 (PRD §FR-05). 지도 실패해도 위 텍스트 정보는 정상. */}
      <section className="rounded-md border bg-white p-4">
        <h2 className="mb-2 text-sm font-semibold text-slate-500">지도</h2>
        {detail.location ? (
          <div className="flex h-40 items-center justify-center rounded bg-slate-100 text-sm text-slate-400">
            지도 열기 (MapLibre 지연 로드 — 숙소/역 핀 + 연결 직선, 경로 아님)
          </div>
        ) : (
          <p className="text-sm text-slate-600">좌표가 없어 지도를 표시할 수 없습니다.</p>
        )}
      </section>

      <Disclaimer />

      <section className="text-xs text-slate-400">
        <p>최종 검증일: {detail.verified_at ? detail.verified_at.slice(0, 10) : "미검증"}</p>
        <p>데이터 한계: {detail.limitations.join(", ")}</p>
      </section>

      <div className="flex gap-2">
        <Link href={`/compare?ids=${detail.id}`} className="tap flex items-center rounded-md border px-4 text-sm">
          비교함에 추가
        </Link>
        <Link href={`/search?city=${detail.city}`} className="tap flex items-center rounded-md border px-4 text-sm">
          검색으로
        </Link>
      </div>
    </article>
  );
}
