import { data } from "@/lib/data";
import { err, ok } from "@/lib/http";

export const dynamic = "force-dynamic";

export async function GET(req: Request) {
  const city = new URL(req.url).searchParams.get("city");
  if (!city) return err("BAD_REQUEST", "city 파라미터가 필요합니다.");
  return ok(await data.areas(city));
}
