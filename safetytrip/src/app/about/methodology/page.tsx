export const metadata = { title: "지표 계산 방법" };

export default function MethodologyPage() {
  return (
    <article className="prose-sm space-y-4 text-sm leading-relaxed">
      <h1 className="text-xl font-bold">지표 계산 방법</h1>

      <section>
        <h2 className="font-semibold">직선거리 정의</h2>
        <p>
          숙소 좌표와 역 <strong>중심점</strong> 사이의 WGS84(EPSG:4326) 기준 측지선 직선거리(미터)입니다.
          프로덕션은 PostGIS <code>ST_Distance(geography, geography)</code>로 계산하며, 화면에는 정수 m로
          일관 반올림합니다.
        </p>
      </section>

      <section>
        <h2 className="font-semibold">거리 구간 라벨 (임시 UX 기준)</h2>
        <ul className="list-disc pl-5">
          <li>0–300m 매우 가까움</li>
          <li>301–600m 가까움</li>
          <li>601–1,000m 다소 이동 필요</li>
          <li>1,001m 이상 접근성 추가 확인</li>
        </ul>
        <p>이는 위험·안전 판단이 아니며, 참고용 UX 라벨입니다.</p>
      </section>

      <section>
        <h2 className="font-semibold">데이터 한계</h2>
        <ul className="list-disc pl-5">
          <li>직선거리는 실제 도보 경로·역 출구·횡단보도·경사도·소요시간과 다릅니다.</li>
          <li>교통 접근성은 치안·안전과 무관합니다.</li>
          <li>좌표가 없거나 반경 5km 내 역 데이터가 없으면 “확인 불가”로 표시하며, 임의 값을 만들지 않습니다.</li>
          <li>역/숙소 데이터는 출처와 최종 검증일을 함께 표기합니다.</li>
        </ul>
      </section>
    </article>
  );
}
