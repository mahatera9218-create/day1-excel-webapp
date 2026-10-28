import { data } from "@/lib/data";
import { err, normalizeQuery, okWith, parseLimit } from "@/lib/http";

export const dynamic = "force-dynamic";

const MAX_RESULTS = 20;

export async function GET(req: Request) {
  const sp = new URL(req.url).searchParams;
  const city = sp.get("city");
  if (!city) return err("BAD_REQUEST", "city 파라미터가 필요합니다.");

  const area = sp.get("area") ?? undefined;
  const limit = parseLimit(sp.get("limit"), MAX_RESULTS, MAX_RESULTS);
  const q = normalizeQuery(sp.get("q")); // null=검색어 없음, ""=2자 미만

  // 2자 미만 검색어는 결과를 좁히지 못하므로 빈 결과 + 안내 meta
  if (q === "") {
    return okWith({ data: [], meta: { query_too_short: true, min_length: 2 } });
  }

  const results = await data.searchProperties({ citySlug: city, areaSlug: area, q: q ?? undefined, limit });
  return okWith({ data: results, meta: { count: results.length, limit, truncated: results.length >= limit } });
}
