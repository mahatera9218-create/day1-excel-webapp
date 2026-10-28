import { data } from "@/lib/data";
import { ok } from "@/lib/http";

export const dynamic = "force-dynamic";

export async function GET() {
  return ok(await data.cities());
}
