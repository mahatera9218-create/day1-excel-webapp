import { err, okWith, stripHtml } from "@/lib/http";

export const dynamic = "force-dynamic";

const ISSUE_TYPES = ["location", "name", "closed", "station", "other"] as const;
type IssueType = (typeof ISSUE_TYPES)[number];
const MAX_DETAILS = 1000;

export async function POST(req: Request) {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return err("BAD_REQUEST", "JSON 본문을 해석할 수 없습니다.");
  }

  const b = (body ?? {}) as Record<string, unknown>;
  const issue_type = b.issue_type;
  const details = b.details;

  if (typeof issue_type !== "string" || !ISSUE_TYPES.includes(issue_type as IssueType)) {
    return err("VALIDATION_FAILED", "issue_type 값이 올바르지 않습니다.");
  }
  if (typeof details !== "string" || details.trim().length === 0) {
    return err("VALIDATION_FAILED", "details 를 입력해 주세요.");
  }
  if (details.length > MAX_DETAILS) {
    return err("VALIDATION_FAILED", `details 는 최대 ${MAX_DETAILS}자입니다.`);
  }

  const safeDetails = stripHtml(details);
  // TODO: rate limit(IP 기준), 저장(data_issues), audit_logs. 연락처는 정책 확정 후 수집.
  const record = {
    id: "issue_" + Math.random().toString(36).slice(2, 10),
    issue_type,
    property_id: typeof b.property_id === "string" ? b.property_id : null,
    details: safeDetails,
    status: "open" as const,
  };
  return okWith({ data: { id: record.id, status: record.status } }, 201);
}
