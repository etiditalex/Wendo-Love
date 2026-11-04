"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { loadInboxCounts, loadOwnAvatar, markPresence } from "@/lib/member-data";
import { useLang } from "@/components/LanguageProvider";

/**
 * Cupid Media desktop chrome (matched from KenyanCupid .membernav):
 * - Globe + current language + chevron → hover/click opens white language list
 * - Profile photo → member menu (edit profile / photos / settings / sign out)
 * - Gear → Profile settings menu
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
  const closeTimers = useRef<Record<string, ReturnType<typeof setTimeout>>>({});

  const topLinks = [
    { href: "/app", label: t("home") },
    { href: "/app/messages", label: t("messages"), badge: "messages" as const },
    { href: "/app/matches", label: t("activity"), badge: "likes" as const },
  ];

  const langLabel = lang === "sw" ? t("swahili") : t("english");

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

  function openOnly(which: "lang" | "profile" | "settings") {
    setLangOpen(which === "lang");
    setProfileOpen(which === "profile");
    setSettingsOpen(which === "settings");
  }

  function scheduleClose(which: "lang" | "profile" | "settings") {
    clearTimeout(closeTimers.current[which]);
    closeTimers.current[which] = setTimeout(() => {
      if (which === "lang") setLangOpen(false);
      if (which === "profile") setProfileOpen(false);
      if (which === "settings") setSettingsOpen(false);
    }, 180);
  }

  function cancelClose(which: "lang" | "profile" | "settings") {
    clearTimeout(closeTimers.current[which]);
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

          <div ref={menuRef} className="flex items-center gap-2">
            <Link
              href="/app/upgrade"
              className="rounded bg-clay px-3 py-1.5 text-sm font-semibold text-paper shadow-[0_2px_4px_rgba(0,0,0,0.2)] hover:bg-[#d01f64]"
            >
              {t("upgrade")}
            </Link>

            {/* Cupid web/language control: globe + label + chevron, hover opens list */}
            <div
              className="relative"
              onMouseEnter={() => {
                cancelClose("lang");
                openOnly("lang");
              }}
              onMouseLeave={() => scheduleClose("lang")}
            >
              <button
                type="button"
                title={langLabel}
                aria-label="Language"
                aria-expanded={langOpen}
                onClick={() => (langOpen ? closeMenus() : openOnly("lang"))}
                className="flex items-center rounded bg-black/80 px-2 py-1.5 text-sm text-paper hover:bg-black/90"
              >
                <GlobeIcon />
                <span className="mx-1 whitespace-nowrap">{langLabel}</span>
                <span className={`inline-flex transition-transform ${langOpen ? "-rotate-90" : "rotate-90"}`}>
                  <ChevronIcon />
                </span>
              </button>
              {langOpen ? (
                <ul className="absolute left-0 top-full z-40 mt-0 min-w-[120%] list-none overflow-hidden p-0 pt-1 shadow-md">
                  <li className="bg-white/80 hover:bg-white">
                    <button
                      type="button"
                      className={`block w-full px-3 py-2 text-left text-sm leading-tight text-[#565656] ${lang === "en" ? "font-semibold" : ""}`}
                      onClick={() => {
                        setLang("en");
                        closeMenus();
                      }}
                    >
                      English
                    </button>
                  </li>
                  <li className="bg-white/80 hover:bg-white">
                    <button
                      type="button"
                      className={`block w-full px-3 py-2 text-left text-sm leading-tight text-[#565656] ${lang === "sw" ? "font-semibold" : ""}`}
                      onClick={() => {
                        setLang("sw");
                        closeMenus();
                      }}
                    >
                      Kiswahili
                    </button>
                  </li>
                </ul>
              ) : null}
            </div>

            {/* Cupid silhouette / profile photo */}
            <div
              className="relative"
              onMouseEnter={() => {
                cancelClose("profile");
                openOnly("profile");
              }}
              onMouseLeave={() => scheduleClose("profile")}
            >
              <button
                type="button"
                title="My profile"
                aria-label="My profile"
                aria-expanded={profileOpen}
                onClick={() => openOnly("profile")}
                className="h-9 w-9 overflow-hidden rounded-full bg-black/40 ring-1 ring-white/50"
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
                <ul className="absolute right-0 top-full z-40 mt-1 min-w-48 list-none overflow-hidden rounded-sm p-0 shadow-md">
                  <MenuItem href="/app/profile" onClick={closeMenus}>
                    Edit profile
                  </MenuItem>
                  <MenuItem href="/app/profile" onClick={closeMenus}>
                    Photos
                  </MenuItem>
                  <MenuItem href="/app/settings" onClick={closeMenus}>
                    Account settings
                  </MenuItem>
                  <MenuItemButton onClick={() => void signOut()}>Sign out</MenuItemButton>
                </ul>
              ) : null}
            </div>

            {/* Cupid gear → Profile Settings */}
            <div
              className="relative"
              onMouseEnter={() => {
                cancelClose("settings");
                openOnly("settings");
              }}
              onMouseLeave={() => scheduleClose("settings")}
            >
              <button
                type="button"
                title="Settings"
                aria-label="Settings"
                aria-expanded={settingsOpen}
                onClick={() => openOnly("settings")}
                className={`grid h-9 w-9 place-items-center rounded text-paper ${settingsOpen ? "bg-black/80" : "bg-black/50 hover:bg-black/80"}`}
              >
                <GearIcon />
              </button>
              {settingsOpen ? (
                <ul className="absolute right-0 top-full z-40 mt-1 min-w-48 list-none overflow-hidden rounded-sm p-0 shadow-md">
                  <MenuItem href="/app/settings" onClick={closeMenus}>
                    Profile settings
                  </MenuItem>
                  <MenuItem href="/app/settings#privacy" onClick={closeMenus}>
                    Privacy
                  </MenuItem>
                  <MenuItem href="/app/settings#notifications" onClick={closeMenus}>
                    Notifications
                  </MenuItem>
                  <MenuItem href="/app/matches?tab=favorites" onClick={closeMenus}>
                    Favorites
                  </MenuItem>
                  <MenuItemButton onClick={() => void signOut()}>Sign out</MenuItemButton>
                </ul>
              ) : null}
            </div>
          </div>
        </div>
      </header>

      <div className="mx-auto max-w-[1400px] px-5 py-4 lg:px-8">{children}</div>
    </div>
  );
}

function MenuItem({ href, onClick, children }: { href: string; onClick: () => void; children: React.ReactNode }) {
  return (
    <li className="bg-white/90 hover:bg-white">
      <Link href={href} onClick={onClick} className="block w-full px-3.5 py-2.5 text-left text-sm text-[#565656]">
        {children}
      </Link>
    </li>
  );
}

function MenuItemButton({ onClick, children }: { onClick: () => void; children: React.ReactNode }) {
  return (
    <li className="bg-white/90 hover:bg-white">
      <button type="button" onClick={onClick} className="block w-full px-3.5 py-2.5 text-left text-sm text-[#565656]">
        {children}
      </button>
    </li>
  );
}

function GlobeIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" className="shrink-0">
      <path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm7.5 9h-3.1a15.4 15.4 0 0 0-1.3-5 8.05 8.05 0 0 1 4.4 5zM12 4c.9 1.2 1.7 3.1 2.1 5.2H9.9C10.3 7.1 11.1 5.2 12 4zM4.5 13h3.1a15.4 15.4 0 0 0 1.3 5 8.05 8.05 0 0 1-4.4-5zm3.1-2H4.5a8.05 8.05 0 0 1 4.4-5 15.4 15.4 0 0 0-1.3 5zm2.3 0h4.2c-.4 2.1-1.2 4-2.1 5.2-.9-1.2-1.7-3.1-2.1-5.2zm4.2 2H9.9c.4 2.1 1.2 4 2.1 5.2.9-1.2 1.7-3.1 2.1-5.2zm.9 5a15.4 15.4 0 0 0 1.3-5h3.1a8.05 8.05 0 0 1-4.4 5z" />
    </svg>
  );
}

function ChevronIcon() {
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" className="shrink-0 opacity-90">
      <path d="M9.3 5.3a1 1 0 0 1 1.4 0l6 6a1 1 0 0 1 0 1.4l-6 6a1 1 0 1 1-1.4-1.4L14.6 12 9.3 6.7a1 1 0 0 1 0-1.4z" />
    </svg>
  );
}

function PersonIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4zm0 2c-4.4 0-8 2.2-8 5v1h16v-1c0-2.8-3.6-5-8-5z" />
    </svg>
  );
}

function GearIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M19.4 13a7.8 7.8 0 0 0 .1-2l2-1.2-2-3.4-2.3.7a7.7 7.7 0 0 0-1.7-1L15 4h-4l-.5 2.1a7.7 7.7 0 0 0-1.7 1l-2.3-.7-2 3.4 2 1.2a7.8 7.8 0 0 0 0 2l-2 1.2 2 3.4 2.3-.7a7.7 7.7 0 0 0 1.7 1L11 20h4l.5-2.1a7.7 7.7 0 0 0 1.7-1l2.3.7 2-3.4-2-1.2zM12 15.2a3.2 3.2 0 1 1 3.2-3.2 3.2 3.2 0 0 1-3.2 3.2z" />
    </svg>
  );
}
