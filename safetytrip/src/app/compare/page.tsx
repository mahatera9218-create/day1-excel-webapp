import Link from "next/link";
import { data } from "@/lib/data";
import { Disclaimer } from "@/components/Disclaimer";

export const dynamic = "force-dynamic";

const MAX = 3;

export default async function ComparePage({ searchParams }: { searchParams: { ids?: string } }) {
  const ids = (searchParams.ids ?? "").split(",").map((s) => s.trim()).filter(Boolean);

  if (ids.length === 0) {
    return (
      <div className="space-y-3">
        <h1 className="text-xl font-bold">숙소 비교</h1>
        <p className="rounded-md bg-slate-100 p-4 text-sm text-slate-600">
          비교할 숙소가 없습니다. 검색 후 상세 화면에서 “비교함에 추가”를 눌러 최대 3개까지 담아보세요.
        </p>
        <Link href="/search?city=tokyo" className="tap inline-flex items-center rounded-md bg-brand px-4 text-white">
          숙소 검색
        </Link>
      </div>
    );
  }

  const { items, skipped } = await data.compare(ids);
  const shown = items.slice(0, MAX);
  const overflow = items.length > MAX || ids.length > MAX;

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold">숙소 비교 ({shown.length}/{MAX})</h1>

      {(skipped.length > 0 || overflow) && (
        <ul className="rounded-md bg-amber-50 p-3 text-xs text-amber-900">
          {skipped.length > 0 && <li>• 찾을 수 없는 항목 {skipped.length}건을 건너뛰었습니다.</li>}
          {overflow && <li>• 비교는 최대 {MAX}개까지만 표시됩니다.</li>}
        </ul>
      )}

      {/* 모바일: 가로 스크롤 테이블 (PRD §5) */}
      <div className="overflow-x-auto">
        <table className="w-full min-w-[480px] border-collapse text-sm">
          <thead>
            <tr className="border-b text-left text-slate-500">
              <th className="p-2">숙소</th>
              <th className="p-2">지역/주소</th>
              <th className="p-2">최근접 역</th>
              <th className="p-2">직선거리</th>
              <th className="p-2">구간</th>
              <th className="p-2">검증일</th>
            </tr>
          </thead>
          <tbody>
            {shown.map((p) => (
              <tr key={p.id} className="border-b align-top">
                <td className="p-2 font-medium">
                  <Link href={`/stay/${p.slug}`} className="underline">{p.name}</Link>
                </td>
                <td className="p-2 text-slate-600">{p.area_name_ko ?? p.area_slug}<br />{p.address}</td>
                <td className="p-2">{p.nearest_station?.name ?? "확인 불가"}</td>
                <td className="p-2">
                  {p.nearest_station ? `${p.nearest_station.straight_distance_m.toLocaleString()} m` : "확인 불가"}
                </td>
                <td className="p-2">{p.nearest_station?.classification ?? "—"}</td>
                <td className="p-2 text-slate-500">{p.verified_at ? p.verified_at.slice(0, 10) : "미검증"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <Disclaimer />
    </div>
  );
}
