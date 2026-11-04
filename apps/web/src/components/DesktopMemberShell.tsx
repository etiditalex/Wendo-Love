"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { loadInboxCounts, loadOwnAvatar, markPresence } from "@/lib/member-data";

const topLinks = [
  { href: "/app", label: "Home" },
  { href: "/app/messages", label: "Messages", badge: "messages" as const },
  { href: "/app/matches", label: "Activity", badge: "likes" as const },
];

export function DesktopMemberShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [likes, setLikes] = useState(0);
  const [messages, setMessages] = useState(0);
  const [avatar, setAvatar] = useState<string | null>(null);

  useEffect(() => {
    const supabase = createClient();
    if (!supabase) return;
    let timer: ReturnType<typeof setInterval> | undefined;
    supabase.auth.getSession().then(async ({ data }) => {
      const userId = data.session?.user.id;
      if (!userId) return;
      const [counts, photo] = await Promise.all([
        loadInboxCounts(supabase, userId),
        loadOwnAvatar(supabase, userId),
      ]);
      setLikes(counts.likes);
      setMessages(counts.messages);
      setAvatar(photo);
      await markPresence(supabase, true);
      timer = setInterval(() => {
        markPresence(supabase, true);
      }, 45000);
    });
    const onLeave = () => {
      markPresence(supabase, false);
    };
    window.addEventListener("pagehide", onLeave);
    return () => {
      if (timer) clearInterval(timer);
      window.removeEventListener("pagehide", onLeave);
      markPresence(supabase, false);
    };
  }, [pathname]);

  return (
    <div className="hidden min-h-screen bg-[#f3eee6] md:block">
      <header className="bg-clay-deep text-paper">
        <div className="mx-auto flex max-w-[1400px] items-center gap-8 px-5 py-3 lg:px-8">
          <Link href="/app" className="shrink-0">
            <img src="/wendo_logo_white.png" alt="Wendo" className="h-12 w-auto lg:h-14" />
          </Link>

          <nav className="flex flex-1 items-center justify-center gap-8 text-[15px] font-medium">
            {topLinks.map((link) => {
              const active = pathname === link.href || (link.href !== "/app" && pathname.startsWith(link.href));
              const count = link.badge === "messages" ? messages : link.badge === "likes" ? likes : 0;
              return (
                <Link key={link.href} href={link.href} className={`relative pb-1 ${active ? "text-paper" : "text-paper/85 hover:text-paper"}`}>
                  {link.label}
                  {active ? <span className="absolute inset-x-0 -bottom-0.5 mx-auto h-0.5 w-full bg-gold" /> : null}
                  {count > 0 ? (
                    <span className="ml-1.5 inline-flex min-w-5 items-center justify-center rounded-full bg-sage px-1.5 py-0.5 text-[11px] font-semibold text-paper">
                      {count > 99 ? "99+" : count}
                    </span>
                  ) : null}
                </Link>
              );
            })}
          </nav>

          <div className="flex items-center gap-3">
            <Link
              href="/app/meet"
              className="rounded-md bg-clay px-4 py-2 text-sm font-semibold text-paper shadow-[0_2px_4px_rgba(0,0,0,0.2)] hover:bg-[#d01f64]"
            >
              Meet safely
            </Link>
            <Link href="/app/learn" title="Learn" className="grid h-9 w-9 place-items-center rounded-full text-paper/90 hover:bg-white/10">
              <GlobeIcon />
            </Link>
            <Link href="/app/profile" className="h-9 w-9 overflow-hidden rounded-full bg-paper/20 ring-2 ring-paper/40">
              {avatar ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={avatar} alt="" className="h-full w-full object-cover" />
              ) : (
                <span className="grid h-full w-full place-items-center text-xs font-semibold">You</span>
              )}
            </Link>
            <Link href="/app/settings" title="Settings" className="grid h-9 w-9 place-items-center rounded-full text-paper/90 hover:bg-white/10">
              <GearIcon />
            </Link>
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-[1400px] px-5 py-4 lg:px-8">{children}</div>
    </div>
  );
}

function GlobeIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.7" />
      <path d="M3 12h18M12 3c2.5 2.8 3.8 5.8 3.8 9S14.5 18.2 12 21c-2.5-2.8-3.8-5.8-3.8-9S9.5 5.8 12 3z" stroke="currentColor" strokeWidth="1.7" />
    </svg>
  );
}

function GearIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M12 15.2a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4z"
        stroke="currentColor"
        strokeWidth="1.7"
      />
      <path
        d="M19.4 13a7.8 7.8 0 0 0 .1-2l2-1.2-2-3.4-2.3.7a7.7 7.7 0 0 0-1.7-1L15 4h-4l-.5 2.1a7.7 7.7 0 0 0-1.7 1l-2.3-.7-2 3.4 2 1.2a7.8 7.8 0 0 0 0 2l-2 1.2 2 3.4 2.3-.7a7.7 7.7 0 0 0 1.7 1L11 20h4l.5-2.1a7.7 7.7 0 0 0 1.7-1l2.3.7 2-3.4-2-1.2z"
        stroke="currentColor"
        strokeWidth="1.4"
        strokeLinejoin="round"
      />
    </svg>
  );
}
