import Link from "next/link";
import { data } from "@/lib/data";

export const dynamic = "force-dynamic";

interface SearchParams {
  city?: string;
  area?: string;
  q?: string;
}

export default async function SearchPage({ searchParams }: { searchParams: SearchParams }) {
  const city = searchParams.city ?? "tokyo";
  const area = searchParams.area;
  const q = (searchParams.q ?? "").trim();
  const tooShort = q.length > 0 && q.length < 2;

  const results = tooShort
    ? []
    : await data.searchProperties({ citySlug: city, areaSlug: area, q: q || undefined, limit: 20 });

  return (
    <div className="space-y-4">
      <form action="/search" method="get" className="flex gap-2">
        <input type="hidden" name="city" value={city} />
        {area && <input type="hidden" name="area" value={area} />}
        <input
          name="q"
          type="search"
          defaultValue={q}
          placeholder="숙소명 또는 주소"
          className="tap w-full rounded-md border border-slate-300 px-3 py-2"
        />
        <button className="tap rounded-md bg-brand px-4 font-medium text-white">검색</button>
      </form>

      <p className="text-sm text-slate-500">
        {area ? `지역: ${area} · ` : ""}검색어: {q || "(전체)"} · {results.length}건
      </p>

      {tooShort && (
        <p className="rounded-md bg-slate-100 p-3 text-sm">검색어는 2자 이상 입력해 주세요.</p>
      )}

      {!tooShort && results.length === 0 && (
        <div className="rounded-md bg-slate-100 p-4 text-sm">
          <p className="font-medium">검색 결과가 없습니다.</p>
          <p className="mt-1 text-slate-600">철자나 지역을 바꿔 다시 검색해 보세요. 동명 숙소는 주소로 구분됩니다.</p>
        </div>
      )}

      <ul className="space-y-2">
        {results.map((p) => (
          <li key={p.id}>
            <Link href={`/stay/${p.slug}`} className="block rounded-md border bg-white p-3 hover:border-brand">
              <div className="flex items-baseline justify-between gap-2">
                <span className="font-semibold">{p.name}</span>
                <span className="shrink-0 text-xs text-slate-400">{p.area_name_ko ?? p.area_slug}</span>
              </div>
              {p.name_local && <div className="text-xs text-slate-500">{p.name_local}</div>}
              <div className="mt-1 text-sm text-slate-600">{p.address}</div>
              <div className="mt-1 text-xs text-slate-400">
                {p.verified_at ? `검증 ${p.verified_at.slice(0, 10)}` : "좌표 미검증"}
              </div>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
