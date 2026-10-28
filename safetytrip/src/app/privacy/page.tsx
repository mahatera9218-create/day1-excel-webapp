export const metadata = { title: "개인정보 안내" };

export default function PrivacyPage() {
  return (
    <article className="space-y-4 text-sm leading-relaxed">
      <h1 className="text-xl font-bold">개인정보 안내</h1>
      <p>SafetyTrip은 로그인 없이 사용하며, 사용자 계정·정밀 실시간 위치·결제 정보를 수집하지 않습니다.</p>
      <ul className="list-disc space-y-1 pl-5 text-slate-700">
        <li>검색 로그는 서비스 품질 분석에 필요한 최소 범위로만 사용하며, IP는 장기 저장을 피하거나 비식별화합니다.</li>
        <li>오류 신고의 자유 입력은 위험한 HTML을 제거하고 크기를 제한하며, 운영자만 열람합니다.</li>
        <li>연락처는 기본 수집하지 않으며, 수집 시 보관·삭제 기간을 별도로 고지합니다.</li>
        <li>비교함·공유 링크에는 개인식별정보를 저장하지 않습니다(공개 ID/slug만 사용).</li>
        <li>분석 이벤트에 정확한 입력 주소나 개인식별정보를 전송하지 않습니다.</li>
      </ul>
    </article>
  );
}
