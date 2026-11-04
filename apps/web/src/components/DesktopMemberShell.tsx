"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { loadInboxCounts, loadOwnAvatar, markPresence } from "@/lib/member-data";
import { useLang } from "@/components/LanguageProvider";

/**
 * Cupid Media-style desktop chrome:
 * - Globe → language menu
 * - Profile photo → member menu (edit profile / settings / sign out)
 * - Gear → account settings menu (profile settings entry, privacy, sign out)
 */
export function DesktopMemberShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { lang, setLang, t } = useLang();
  const [likes, setLikes] = useState(0);
  const [messages, setMessages] = useState(0);
  const [avatar, setAvatar] = useState<string | null>(null);
  const [langOpen, setLangOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  const topLinks = [
    { href: "/app", label: t("home") },
    { href: "/app/messages", label: t("messages"), badge: "messages" as const },
    { href: "/app/matches", label: t("activity"), badge: "likes" as const },
  ];

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

  useEffect(() => {
    setLangOpen(false);
    setProfileOpen(false);
    setSettingsOpen(false);
  }, [pathname]);

  useEffect(() => {
    function onDocClick(event: MouseEvent) {
      if (!menuRef.current?.contains(event.target as Node)) {
        setLangOpen(false);
        setProfileOpen(false);
        setSettingsOpen(false);
      }
    }
    document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, []);

  async function signOut() {
    const supabase = createClient();
    if (supabase) {
      await markPresence(supabase, false);
      await supabase.auth.signOut({ scope: "local" }).catch(() => undefined);
    }
    router.push("/login");
  }

  function closeMenus() {
    setLangOpen(false);
    setProfileOpen(false);
    setSettingsOpen(false);
  }

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

          <div ref={menuRef} className="flex items-center gap-2.5">
            <Link
              href="/app/upgrade"
              className="rounded-md bg-clay px-4 py-2 text-sm font-semibold text-paper shadow-[0_2px_4px_rgba(0,0,0,0.2)] hover:bg-[#d01f64]"
            >
              {t("upgrade")}
            </Link>

            {/* Cupid “web/language” globe — opens language menu */}
            <div className="relative">
              <button
                type="button"
                title={lang === "sw" ? t("swahili") : t("english")}
                aria-label="Language"
                aria-expanded={langOpen}
                onClick={() => {
                  setLangOpen((open) => !open);
                  setProfileOpen(false);
                  setSettingsOpen(false);
                }}
                className="grid h-9 w-9 place-items-center rounded-full text-paper/90 hover:bg-white/10"
              >
                <GlobeIcon />
              </button>
              {langOpen ? (
                <MenuCard>
                  <MenuButton
                    onClick={() => {
                      setLang("en");
                      closeMenus();
                    }}
                  >
                    {t("english")}
                  </MenuButton>
                  <MenuButton
                    onClick={() => {
                      setLang("sw");
                      closeMenus();
                    }}
                  >
                    {t("swahili")}
                  </MenuButton>
                </MenuCard>
              ) : null}
            </div>

            {/* Cupid silhouette / profile photo — member menu */}
            <div className="relative">
              <button
                type="button"
                title="My profile"
                aria-label="My profile"
                aria-expanded={profileOpen}
                onClick={() => {
                  setProfileOpen((open) => !open);
                  setLangOpen(false);
                  setSettingsOpen(false);
                }}
                className="h-9 w-9 overflow-hidden rounded-full bg-paper/20 ring-2 ring-paper/40"
              >
                {avatar ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={avatar} alt="" className="h-full w-full object-cover" />
                ) : (
                  <span className="grid h-full w-full place-items-center text-paper">
                    <PersonIcon />
                  </span>
                )}
              </button>
              {profileOpen ? (
                <MenuCard>
                  <MenuLink href="/app/profile" onClick={closeMenus}>
                    Edit profile
                  </MenuLink>
                  <MenuLink href="/app/profile" onClick={closeMenus}>
                    Photos
                  </MenuLink>
                  <MenuLink href="/app/settings" onClick={closeMenus}>
                    Account settings
                  </MenuLink>
                  <MenuButton onClick={() => void signOut()}>Sign out</MenuButton>
                </MenuCard>
              ) : null}
            </div>

            {/* Cupid gear — settings menu → Profile Settings */}
            <div className="relative">
              <button
                type="button"
                title="Settings"
                aria-label="Settings"
                aria-expanded={settingsOpen}
                onClick={() => {
                  setSettingsOpen((open) => !open);
                  setLangOpen(false);
                  setProfileOpen(false);
                }}
                className="grid h-9 w-9 place-items-center rounded-full text-paper/90 hover:bg-white/10"
              >
                <GearIcon />
              </button>
              {settingsOpen ? (
                <MenuCard>
                  <MenuLink href="/app/settings" onClick={closeMenus}>
                    Profile settings
                  </MenuLink>
                  <MenuLink href="/app/settings#privacy" onClick={closeMenus}>
                    Privacy
                  </MenuLink>
                  <MenuLink href="/app/settings#notifications" onClick={closeMenus}>
                    Notifications
                  </MenuLink>
                  <MenuLink href="/app/matches?tab=favorites" onClick={closeMenus}>
                    Favorites
                  </MenuLink>
                  <MenuButton onClick={() => void signOut()}>Sign out</MenuButton>
                </MenuCard>
              ) : null}
            </div>
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-[1400px] px-5 py-4 lg:px-8">{children}</div>
    </div>
  );
}

function MenuCard({ children }: { children: React.ReactNode }) {
  return (
    <div className="absolute right-0 z-30 mt-2 min-w-48 overflow-hidden rounded-md bg-ink py-1 text-sm text-paper shadow-lg ring-1 ring-white/10">
      {children}
    </div>
  );
}

function MenuLink({ href, onClick, children }: { href: string; onClick: () => void; children: React.ReactNode }) {
  return (
    <Link href={href} onClick={onClick} className="block w-full px-3.5 py-2.5 text-left hover:bg-white/10">
      {children}
    </Link>
  );
}

function MenuButton({ onClick, children }: { onClick: () => void; children: React.ReactNode }) {
  return (
    <button type="button" onClick={onClick} className="block w-full px-3.5 py-2.5 text-left hover:bg-white/10">
      {children}
    </button>
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

function PersonIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="8" r="3.2" stroke="currentColor" strokeWidth="1.7" />
      <path d="M5 19c1.6-3.2 4-4.8 7-4.8s5.4 1.6 7 4.8" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
    </svg>
  );
}

function GearIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M12 15.2a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4z" stroke="currentColor" strokeWidth="1.7" />
      <path
        d="M19.4 13a7.8 7.8 0 0 0 .1-2l2-1.2-2-3.4-2.3.7a7.7 7.7 0 0 0-1.7-1L15 4h-4l-.5 2.1a7.7 7.7 0 0 0-1.7 1l-2.3-.7-2 3.4 2 1.2a7.8 7.8 0 0 0 0 2l-2 1.2 2 3.4 2.3-.7a7.7 7.7 0 0 0 1.7 1L11 20h4l.5-2.1a7.7 7.7 0 0 0 1.7-1l2.3.7 2-3.4-2-1.2z"
        stroke="currentColor"
        strokeWidth="1.4"
        strokeLinejoin="round"
      />
    </svg>
  );
}
