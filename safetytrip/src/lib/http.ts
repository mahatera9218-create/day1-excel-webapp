/**
 * API 공통 응답/검증 유틸 (PRD §7).
 *  - 성공: { data, meta? }, 오류: { error: { code, message, request_id } }
 *  - 내부 스택/상세 비노출. 시간 ISO-8601 UTC, 거리 단위 m, null 일관.
 */
import { NextResponse } from "next/server";

export type ErrorCode =
  | "BAD_REQUEST"
  | "VALIDATION_FAILED"
  | "PROPERTY_NOT_FOUND"
  | "CONFLICT"
  | "RATE_LIMITED"
  | "FEATURE_DISABLED"
  | "INTERNAL";

const STATUS: Record<ErrorCode, number> = {
  BAD_REQUEST: 400,
  VALIDATION_FAILED: 422,
  PROPERTY_NOT_FOUND: 404,
  CONFLICT: 409,
  RATE_LIMITED: 429,
  FEATURE_DISABLED: 404,
  INTERNAL: 500,
};

const MESSAGES: Record<ErrorCode, string> = {
  BAD_REQUEST: "요청 파라미터가 올바르지 않습니다.",
  VALIDATION_FAILED: "입력값 검증에 실패했습니다.",
  PROPERTY_NOT_FOUND: "숙소를 찾을 수 없습니다.",
  CONFLICT: "요청이 현재 상태와 충돌합니다.",
  RATE_LIMITED: "요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.",
  FEATURE_DISABLED: "현재 사용할 수 없는 기능입니다.",
  INTERNAL: "일시적인 오류가 발생했습니다.",
};

export function requestId(): string {
  return "req_" + Math.random().toString(36).slice(2, 12);
}

export function ok<T>(data: T, init?: { status?: number; meta?: unknown }) {
  const body: Record<string, unknown> = { data };
  if (init?.meta !== undefined) body.meta = init.meta;
  return NextResponse.json(body, { status: init?.status ?? 200 });
}

export function okWith<T>(payload: Record<string, unknown> & { data: T }, status = 200) {
  return NextResponse.json(payload, { status });
}

export function err(code: ErrorCode, messageOverride?: string) {
  return NextResponse.json(
    { error: { code, message: messageOverride ?? MESSAGES[code], request_id: requestId() } },
    { status: STATUS[code] },
  );
}

/** q 검증: 2자 이상 요구 시 사용. 길이·문자범위 서버 검증(§FR-01 수락 기준). */
export function normalizeQuery(raw: string | null, { min = 2, max = 100 } = {}): string | null {
  if (raw === null) return null;
  const q = raw.trim();
  if (q.length === 0) return null;
  if (q.length > max) return q.slice(0, max);
  return q.length >= min ? q : "";
}

export function parseLimit(raw: string | null, def: number, maxLimit: number): number {
  const n = Number(raw);
  if (!Number.isFinite(n) || n <= 0) return def;
  return Math.min(Math.floor(n), maxLimit);
}

/** 위험한 HTML 제거(간이). 실제 운영은 검증된 sanitizer 사용 권장. */
export function stripHtml(input: string): string {
  return input.replace(/<[^>]*>/g, "").replace(/[\u0000-\u001f\u007f]/g, " ").trim();
}
