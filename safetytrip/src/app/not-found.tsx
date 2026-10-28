import Link from "next/link";

export default function NotFound() {
  return (
    <div className="space-y-3 py-10 text-center">
      <h1 className="text-2xl font-bold">찾을 수 없습니다 (404)</h1>
      <p className="text-sm text-slate-600">요청하신 숙소나 페이지를 찾을 수 없습니다.</p>
      <Link href="/" className="tap inline-flex items-center rounded-md bg-brand px-4 text-white">홈으로</Link>
    </div>
  );
}
