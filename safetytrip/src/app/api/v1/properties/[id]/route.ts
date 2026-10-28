import { data } from "@/lib/data";
import { err, ok } from "@/lib/http";

export const dynamic = "force-dynamic";

export async function GET(_req: Request, { params }: { params: { id: string } }) {
  const detail = await data.getProperty(params.id);
  if (!detail) return err("PROPERTY_NOT_FOUND");
  // 근접역 없으면 nearest_station: null + limitations. 절대 0m 생성하지 않음.
  return ok(detail);
}
