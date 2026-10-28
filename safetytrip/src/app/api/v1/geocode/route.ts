import { err } from "@/lib/http";

export const dynamic = "force-dynamic";

/**
 * FR-02 임시 숙소 위치 분석 — P1, 기능 플래그.
 * 지오코딩 제공자의 상업적 사용·캐싱·결과 표시 조건 확인 전까지 비활성.
 * FEATURE_GEOCODING=on 이고 공급자 어댑터가 구현되면 활성화.
 * (D-02 결론: 좌표 영구 저장이 필요하므로 OpenCage/LocationIQ(유료)/self-host Nominatim 중 택1.
 *  Google/Mapbox-temporary 는 저장·non-Google map 제약으로 부적합.)
 */
export async function POST() {
  if (process.env.FEATURE_GEOCODING !== "on") {
    return err("FEATURE_DISABLED", "임시 위치 분석은 현재 비활성화되어 있습니다.");
  }
  // TODO: 공급자 어댑터 → 후보 주소 반환(자동 선택 금지, 확인 UI 필요).
  return err("FEATURE_DISABLED", "지오코딩 어댑터가 아직 구성되지 않았습니다.");
}
