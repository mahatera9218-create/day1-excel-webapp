import { data } from "@/lib/data";
import { err, ok, parseLimit } from "@/lib/http";

export const dynamic = "force-dynamic";

export async function GET(req: Request, { params }: { params: { id: string } }) {
  const detail = await data.getProperty(params.id);
  if (!detail) return err("PROPERTY_NOT_FOUND");

  const limit = parseLimit(new URL(req.url).searchParams.get("limit"), 3, 3);
  const stations = await data.nearbyStations(params.id, limit);
  // 좌표 없음/역 데이터 부재 → 빈 배열 + unresolved. 0m 반환 금지.
  return ok(stations, { meta: { resolved: stations.length > 0 } });
}
