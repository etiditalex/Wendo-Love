import Link from "next/link";
import { MemberNav } from "@/components/MemberNav";
import { DesktopMemberShell } from "@/components/DesktopMemberShell";
import { LanguageProvider } from "@/components/LanguageProvider";

export default function MemberLayout({ children }: { children: React.ReactNode }) {
  return (
    <LanguageProvider>
      <div className="min-h-screen md:hidden">
        <header className="border-b border-line bg-clay-deep text-paper">
          <div className="mx-auto flex max-w-5xl items-center justify-between px-6 py-3">
            <Link href="/app" className="block w-[112px]">
              <img src="/wendo_logo_white.png" alt="Wendo" className="h-auto w-full" />
            </Link>
            <Link href="/safety" className="text-sm text-paper/90">
              Safety
            </Link>
          </div>
        </header>
        <div className="mx-auto grid max-w-5xl gap-6 px-6 py-8">
          <MemberNav />
          {children}
        </div>
      </div>

      <DesktopMemberShell>{children}</DesktopMemberShell>
    </LanguageProvider>
  );
}
