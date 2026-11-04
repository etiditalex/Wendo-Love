"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const items = [
  { href: "/app", label: "Discover" },
  { href: "/app/profile", label: "Profile" },
  { href: "/app/matches", label: "Matches" },
  { href: "/app/messages", label: "Messages" },
  { href: "/app/meet", label: "Meet safely" },
  { href: "/app/learn", label: "Learn" },
  { href: "/app/support", label: "Support" },
  { href: "/app/settings", label: "Privacy" },
];

export function MemberNav() {
  const pathname = usePathname();

  return (
    <nav className="flex gap-2 overflow-x-auto pb-2 text-sm">
      {items.map((item) => {
        const active = pathname === item.href;
        return (
          <Link
            key={item.href}
            href={item.href}
            className={`shrink-0 rounded-full px-3 py-1.5 ${
              active ? "bg-clay-deep text-paper" : "bg-paper text-ink-soft ring-1 ring-line"
            }`}
          >
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
