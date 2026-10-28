import Link from "next/link";
import { data } from "@/lib/data";

export default async function HomePage() {
  const areas = await data.areas("tokyo");
  return (
    <div className="space-y-6">
      <section className="space-y-2">
        <h1 className="text-xl font-bold">도쿄 숙소, 역에서 얼마나 가까운가요?</h1>
        <p className="text-sm text-slate-600">
          숙소명 또는 주소로 검색해 가장 가까운 역까지의 직선거리를 확인하고, 최대 3개를 같은 기준으로 비교하세요.
        </p>
      </section>

      <form action="/search" method="get" className="space-y-3">
        <input type="hidden" name="city" value="tokyo" />
        <label htmlFor="q" className="block text-sm font-medium">숙소명 또는 주소</label>
        <input
          id="q"
          name="q"
          type="search"
          placeholder="예: Sample Hotel Shinjuku / 新宿"
          className="tap w-full rounded-md border border-slate-300 px-3 py-2"
          minLength={2}
        />
        <button type="submit" className="tap w-full rounded-md bg-brand px-4 py-2 font-medium text-white">
          검색
        </button>
      </form>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-slate-500">지원 지역</h2>
        <div className="flex flex-wrap gap-2">
          {areas.map((a) => (
            <Link
              key={a.slug}
              href={`/search?city=tokyo&area=${a.slug}`}
              className="tap flex items-center rounded-full border border-slate-300 bg-white px-4 text-sm"
            >
              {a.name_ko}
            </Link>
          ))}
        </div>
      </section>
    </div>
  );
}
