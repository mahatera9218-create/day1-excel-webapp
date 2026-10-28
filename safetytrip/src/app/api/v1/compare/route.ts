import { data } from "@/lib/data";
import { err, okWith } from "@/lib/http";

export const dynamic = "force-dynamic";

const MAX_COMPARE = 3;

export async function GET(req: Request) {
  const raw = new URL(req.url).searchParams.get("ids");
  if (!raw) return err("BAD_REQUEST", "ids 파라미터가 필요합니다.");

  const ids = raw.split(",").map((s) => s.trim()).filter(Boolean);
  if (ids.length === 0) return err("BAD_REQUEST", "유효한 ids가 없습니다.");

  const { items, skipped } = await data.compare(ids);
  const warnings: string[] = [];
  if (items.length > MAX_COMPARE) items.length = MAX_COMPARE; // 상한 3
  if (skipped.length > 0) warnings.push(`무효하거나 찾을 수 없는 항목 ${skipped.length}건을 건너뛰었습니다.`);
  if (new Set(ids).size < ids.length) warnings.push("중복된 항목은 1회만 표시됩니다.");

  // 누락 수치는 각 detail 의 nearest_station:null 로 표현. 0m 대체 금지.
  return okWith({ data: items, warnings, meta: { requested: ids.length, shown: items.length, skipped } });
}
