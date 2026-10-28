/** FR-04 필수 고지 문구. 문구 유지 권장. 모든 상세/비교 화면에 노출. */
export function Disclaimer() {
  return (
    <p className="rounded-md border border-amber-300 bg-amber-50 p-3 text-xs leading-relaxed text-amber-900">
      역 거리는 <strong>역 중심점 기준 직선거리</strong>입니다. 실제 역 출구, 횡단보도,
      경사도와 도보 소요시간은 다를 수 있으며, 본 정보는 해당 지역의 치안이나 안전을
      보장하지 않습니다.
    </p>
  );
}
