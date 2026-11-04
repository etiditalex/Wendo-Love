import Link from "next/link";

const links = [
  { href: "/learn", label: "Learn" },
  { href: "/safety", label: "Safety" },
  { href: "/privacy", label: "Privacy" },
  { href: "/support", label: "Support" },
];

export function SiteHeader() {
  return (
    <header className="border-b border-line bg-paper/90">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 px-6 py-4">
        <Link href="/" className="block w-[108px]">
          <img src="/wendo_logo.png" alt="Wendo" className="h-auto w-full" />
        </Link>
        <nav className="flex flex-wrap items-center gap-x-5 gap-y-2 text-sm text-ink-soft">
          {links.map((link) => (
            <Link key={link.href} href={link.href} className="hover:text-ink">
              {link.label}
            </Link>
          ))}
          <Link href="/login" className="hover:text-ink">
            Log in
          </Link>
          <Link
            href="/join"
            className="rounded-full bg-clay px-4 py-2 font-semibold text-paper hover:bg-clay-deep"
          >
            Join
          </Link>
        </nav>
      </div>
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="mt-16 border-t border-line">
      <div className="mx-auto flex max-w-6xl flex-wrap items-end justify-between gap-4 px-6 py-8 text-sm text-ink-soft">
        <div>
          <img src="/wendo_logo.png" alt="Wendo" className="h-12 w-auto" />
          <p className="mt-2">Love. Dignity. Connection.</p>
        </div>
        <p className="max-w-md">
          Adults 18 and over. Kenya-first pilot. This is a relationship platform, not a clinic,
          testing service, or patient registry.
        </p>
      </div>
    </footer>
  );
}

export function BoundaryNote() {
  return (
    <aside className="rounded-2xl border border-line bg-paper px-5 py-4 text-sm leading-6 text-ink-soft">
      Wendo does not diagnose HIV, certify a test result, or replace a clinician. Clinic
      names, patient numbers, and treatment cards are never collected.
    </aside>
  );
}
