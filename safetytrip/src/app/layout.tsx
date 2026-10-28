import type { Metadata, Viewport } from "next";
import Link from "next/link";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "SafetyTrip 안심트래블", template: "%s · SafetyTrip" },
  description: "해외 숙소의 역 접근성(직선거리)을 같은 기준으로 확인·비교하세요. 도보시간·치안 등급이 아닙니다.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body>
        <header className="border-b bg-white">
          <div className="mx-auto flex max-w-screen-md items-center justify-between px-4 py-3">
            <Link href="/" className="font-bold text-brand-ink">
              SafetyTrip <span className="text-xs font-normal text-slate-400">안심트래블</span>
            </Link>
            <nav className="flex gap-3 text-sm text-slate-600">
              <Link href="/compare" className="tap flex items-center">비교함</Link>
              <Link href="/about/methodology" className="tap flex items-center">계산 방법</Link>
            </nav>
          </div>
        </header>
        <main className="mx-auto max-w-screen-md px-4 py-5">{children}</main>
        <footer className="mx-auto max-w-screen-md px-4 py-8 text-xs text-slate-400">
          <p>SafetyTrip은 브랜드명이며 안전을 보증하지 않습니다. 직선거리 ≠ 도보거리 · 교통 접근성 ≠ 치안.</p>
          <p className="mt-1">
            <Link href="/privacy" className="underline">개인정보 안내</Link>
            {" · "}
            <Link href="/about/methodology" className="underline">지표 계산 방법</Link>
          </p>
        </footer>
      </body>
    </html>
  );
}
