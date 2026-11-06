"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { useLang } from "@/components/LanguageProvider";
import {
  type DiscoveryCard,
  type HomeBoard,
  addFavorite,
  blockPerson,
  formatLastSeen,
  isNewMember,
  loadDiscoveryCards,
  loadHomeBoard,
  openConversation,
  passPerson,
  reportPerson,
  seekingLine,
  sendLike,
} from "@/lib/member-data";

type Mode = "forYou" | "mutual" | "reverse" | "online" | "popular" | "newest" | "latestPhotos" | "inArea";

const pageSize = 35;

const bodyOptions = ["", "slim", "average", "athletic", "curvy"];
const educationOptions = ["", "secondary", "diploma", "degree", "postgraduate"];

export function DesktopDiscover() {
  const { t } = useLang();
  const router = useRouter();
  const [cards, setCards] = useState<DiscoveryCard[]>([]);
  const [board, setBoard] = useState<HomeBoard | null>(null);
  const [liked, setLiked] = useState<Set<string>>(new Set());
  const [mode, setMode] = useState<Mode>("forYou");
  const [note, setNote] = useState("Loading members…");
  const [userId, setUserId] = useState<string | null>(null);
  const [ageOpen, setAgeOpen] = useState(false);
  const [ageMin, setAgeMin] = useState(18);
  const [ageMax, setAgeMax] = useState(80);
  const [bodyStyle, setBodyStyle] = useState("");
  const [education, setEducation] = useState("");
  const [page, setPage] = useState(1);

  const listsOpen = Boolean(board?.plus || board?.criteriaComplete);

  useEffect(() => {
    const supabase = createClient();
    if (!supabase) {
      setNote("Connect Supabase in .env.local to load live profiles.");
      return;
    }
    supabase.auth.getSession().then(async ({ data }) => {
      const id = data.session?.user.id ?? null;
      setUserId(id);
      if (!id) {
        setNote("Log in to see members from Wendo.");
        return;
      }
      const [home, list] = await Promise.all([loadHomeBoard(supabase, id), loadDiscoveryCards(supabase, id)]);
      setBoard(home);
      setLiked(new Set(home.outgoingLikeIds));
      setCards(list);
      setNote(list.length === 0 ? "No profiles to show yet." : "");
    });
  }, []);

  useEffect(() => {
    setPage(1);
  }, [mode, ageMin, ageMax, bodyStyle, education]);

  const filtered = useMemo(() => {
    let list = cards.filter((card) => {
      if (card.age_years == null) return true;
      return card.age_years >= ageMin && card.age_years <= ageMax;
    });
    if (board?.plus && bodyStyle) list = list.filter((card) => card.body_type === bodyStyle);
    if (board?.plus && education) list = list.filter((card) => card.education === education);
    if (mode === "online") list = list.filter((card) => card.is_online);
    if (mode === "inArea" && board?.city) {
      const city = board.city.toLowerCase();
      list = list.filter((card) => (card.city ?? "").toLowerCase().includes(city) || city.includes((card.city ?? "").toLowerCase()));
    }
    if (mode === "latestPhotos") list = list.filter((card) => Boolean(card.photoUrl || card.photo_path));
    if (mode === "mutual" && listsOpen) {
      const mutual = new Set(board?.mutualIds ?? []);
      list = list.filter((card) => mutual.has(card.user_id));
    }
    if (mode === "reverse" && listsOpen) {
      const reverse = new Set(board?.reverseIds ?? []);
      list = list.filter((card) => reverse.has(card.user_id));
    }
    const ownCity = board?.city ?? null;
    const ownIntent = board?.intent ?? "";
    list.sort((a, b) => {
      if (mode === "newest" || mode === "latestPhotos") {
        return String(b.created_at ?? "").localeCompare(String(a.created_at ?? ""));
      }
      if (mode === "popular") return (b.like_count ?? 0) - (a.like_count ?? 0) || relevance(b, ownCity, ownIntent) - relevance(a, ownCity, ownIntent);
      return relevance(b, ownCity, ownIntent) - relevance(a, ownCity, ownIntent);
    });
    return list;
  }, [cards, mode, ageMin, ageMax, board, listsOpen, bodyStyle, education]);

  const pageCount = Math.max(1, Math.ceil(filtered.length / pageSize));
  const safePage = Math.min(page, pageCount);
  const visible = filtered.slice((safePage - 1) * pageSize, safePage * pageSize);
  const lockedList = (mode === "mutual" || mode === "reverse") && !listsOpen;

  async function onLike(card: DiscoveryCard) {
    if (!userId) return;
    const supabase = createClient();
    if (!supabase) return;
    const error = await sendLike(supabase, userId, card.user_id);
    if (!error) setLiked((prev) => new Set(prev).add(card.user_id));
  }

  async function onMessage(card: DiscoveryCard) {
    if (!userId) return;
    const supabase = createClient();
    if (!supabase) return;
    const matchId = await openConversation(supabase, card.user_id);
    if (matchId) router.push(`/app/messages?match=${matchId}`);
    else setNote("Chat opens after you both like each other.");
  }

  async function onFavorite(card: DiscoveryCard) {
    if (!userId) return;
    const supabase = createClient();
    if (!supabase) return;
    await addFavorite(supabase, userId, card.user_id);
    setNote("Saved to your private favorites.");
  }

  async function onPass(card: DiscoveryCard) {
    if (!userId) return;
    const supabase = createClient();
    if (!supabase) return;
    const error = await passPerson(supabase, userId, card.user_id);
    if (!error) setCards((prev) => prev.filter((row) => row.user_id !== card.user_id));
  }

  async function onBlock(card: DiscoveryCard) {
    if (!userId) return;
    const supabase = createClient();
    if (!supabase) return;
    const error = await blockPerson(supabase, userId, card.user_id);
    if (!error) setCards((prev) => prev.filter((row) => row.user_id !== card.user_id));
  }

  async function onReport(card: DiscoveryCard) {
    if (!userId) return;
    const supabase = createClient();
    if (!supabase) return;
    const reason = window.prompt(
      "Report reason: harassment, scam, impersonation, outing_threat, coercion, spam, or other",
      "other",
    );
    if (!reason) return;
    await reportPerson(supabase, userId, card.user_id, reason);
    setNote("Report sent for review.");
  }

  const modes: { id: Mode; label: string; locked?: boolean }[] = [
    { id: "forYou", label: t("matches") },
    { id: "mutual", label: t("mutual"), locked: !listsOpen },
    { id: "reverse", label: t("reverse"), locked: !listsOpen },
    { id: "online", label: t("online") },
    { id: "popular", label: t("popular") },
    { id: "newest", label: t("newest") },
    { id: "latestPhotos", label: t("latestPhotos") },
    { id: "inArea", label: t("inArea") },
  ];

  return (
    <section className="grid gap-3">
      {board ? (
        <div className="rounded-md border border-line bg-paper px-4 py-3 shadow-sm">
          <div className="flex flex-wrap items-end justify-between gap-3">
            <div>
              <p className="text-2xl text-clay-deep">
                {t("hi")} {board.name}
              </p>
              <p className="text-sm text-ink-soft">
                {board.completion}% · {board.criteriaComplete ? t("matches") : t("nextStep")}
              </p>
              {!board.criteriaComplete ? (
                <Link href="/app/profile" className="mt-1 inline-block text-sm font-semibold text-clay-deep underline">
                  {t("completeProfile")}
                </Link>
              ) : null}
            </div>
            <Link href="/app/upgrade" className="text-sm font-semibold text-clay-deep underline">
              {t("learnMembership")}
            </Link>
          </div>
          <div className="mt-3 flex flex-wrap gap-2">
            {(
              [
                { label: "Mutual", action: "mutual" as const },
                { label: "Reverse", action: "reverse" as const },
                { label: "Filters", action: "filters" as const },
                { label: "Plus", action: "plus" as const },
                { label: "Meet", action: "meet" as const },
                { label: "Chat", action: "chat" as const },
              ] as const
            ).map((item) => {
              if (item.action === "meet") {
                return (
                  <Link key={item.label} href="/app/meet" className="rounded-full bg-cream px-3 py-1 text-xs font-semibold text-ink-soft ring-1 ring-line">
                    {item.label}
                  </Link>
                );
              }
              if (item.action === "chat") {
                return (
                  <Link key={item.label} href="/app/messages" className="rounded-full bg-cream px-3 py-1 text-xs font-semibold text-ink-soft ring-1 ring-line">
                    {item.label}
                  </Link>
                );
              }
              if (item.action === "plus") {
                return (
                  <Link key={item.label} href="/app/upgrade" className="rounded-full bg-cream px-3 py-1 text-xs font-semibold text-ink-soft ring-1 ring-line">
                    {item.label}
                  </Link>
                );
              }
              return (
                <button
                  key={item.label}
                  type="button"
                  onClick={() => {
                    if (item.action === "filters") {
                      setNote(t("filtersSoon"));
                      return;
                    }
                    if (!listsOpen) {
                      router.push("/app/profile");
                      return;
                    }
                    setMode(item.action);
                  }}
                  className="rounded-full bg-cream px-3 py-1 text-xs font-semibold text-ink-soft ring-1 ring-line"
                >
                  {item.label}
                </button>
              );
            })}
          </div>
          <dl className="mt-3 grid grid-cols-2 gap-2 text-sm sm:grid-cols-4">
            <Count label={t("messages")} value={board.messages} href="/app/messages" />
            <Count label={t("interests")} value={board.interests} href="/app/matches?tab=likes" />
            <Count label={t("views")} value={board.views} href="/app/matches?tab=views" />
            <Count label={t("favorites")} value={board.favorites} href="/app/matches?tab=favorites" />
          </dl>
        </div>
      ) : null}

      <div className="overflow-x-auto rounded-md border border-line bg-paper px-3 py-2.5 shadow-sm">
        <div className="flex min-w-max items-center gap-2">
          {modes.map((item) => {
            const active = mode === item.id;
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => setMode(item.id)}
                className={`inline-flex items-center gap-2 rounded-full px-3.5 py-1.5 text-sm font-medium transition ${
                  active ? "bg-clay-deep text-paper" : "bg-paper text-ink ring-1 ring-[#cfc4b4] hover:bg-cream"
                }`}
              >
                {item.locked ? <LockIcon color={active ? "#fffdf8" : "#9c1b4e"} /> : null}
                {item.label}
              </button>
            );
          })}
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2 border-b border-line pb-2">
        <span className="grid h-8 w-8 place-items-center text-ink-soft">
          <SlidersIcon />
        </span>
        {board?.plus ? (
          <>
            <FilterSelect label={t("bodyStyle")} value={bodyStyle} options={bodyOptions} onChange={setBodyStyle} />
            <FilterSelect label={t("education")} value={education} options={educationOptions} onChange={setEducation} />
          </>
        ) : (
          <>
            <button
              type="button"
              onClick={() => setNote(t("filtersSoon"))}
              className="inline-flex items-center gap-2 rounded-full bg-paper px-3 py-1.5 text-sm text-ink-soft ring-1 ring-[#cfc4b4]"
            >
              <LockIcon /> {t("bodyStyle")}
            </button>
            <button
              type="button"
              onClick={() => setNote(t("filtersSoon"))}
              className="inline-flex items-center gap-2 rounded-full bg-paper px-3 py-1.5 text-sm text-ink-soft ring-1 ring-[#cfc4b4]"
            >
              <LockIcon /> {t("education")}
            </button>
          </>
        )}
        <button
          type="button"
          onClick={() => setAgeOpen((value) => !value)}
          className={`inline-flex items-center gap-2 rounded-full px-3 py-1.5 text-sm ring-1 ${
            ageOpen ? "bg-cream text-clay-deep ring-clay" : "bg-paper text-ink ring-[#cfc4b4]"
          }`}
        >
          <CheckIcon /> {t("age")} {ageMin}–{ageMax}
        </button>
        {ageOpen ? (
          <div className="flex items-center gap-2 text-sm text-ink-soft">
            <label className="flex items-center gap-1">
              From
              <input
                type="number"
                min={18}
                max={ageMax}
                value={ageMin}
                onChange={(event) => setAgeMin(Number(event.target.value) || 18)}
                className="w-16 rounded border border-line bg-paper px-2 py-1"
              />
            </label>
            <label className="flex items-center gap-1">
              To
              <input
                type="number"
                min={ageMin}
                max={99}
                value={ageMax}
                onChange={(event) => setAgeMax(Number(event.target.value) || 80)}
                className="w-16 rounded border border-line bg-paper px-2 py-1"
              />
            </label>
          </div>
        ) : null}
      </div>

      {!userId ? (
        <p className="rounded-xl bg-paper px-4 py-3 text-sm text-ink-soft ring-1 ring-line">
          <Link href="/login" className="font-semibold text-clay-deep underline">
            Log in
          </Link>{" "}
          to browse live Wendo profiles.
        </p>
      ) : null}

      {note ? <p className="text-sm text-ink-soft">{note}</p> : null}

      {lockedList ? (
        <div className="rounded-xl border border-dashed border-gold bg-paper px-5 py-10 text-center">
          <p className="text-ink-soft">{t("lockedLists")}</p>
          <div className="mt-4 flex flex-wrap justify-center gap-3">
            <Link href="/app/profile" className="rounded-md bg-clay px-4 py-2 text-sm font-semibold text-paper">
              {t("completeProfile")}
            </Link>
          </div>
        </div>
      ) : visible.length === 0 && userId ? (
        <p className="rounded-xl border border-dashed border-gold bg-paper px-5 py-10 text-center text-ink-soft">{t("noMembers")}</p>
      ) : (
        <ul className="grid grid-cols-2 gap-3 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-6">
          {visible.map((card) => (
            <li key={card.user_id} className="overflow-hidden rounded-md bg-paper shadow-[0_1px_3px_rgba(0,0,0,0.12)] ring-1 ring-black/5">
              <div className="relative aspect-[3/4] bg-[#e7dccb]">
                <Link href={`/app/people/${card.user_id}`} className="absolute inset-0 z-0" aria-label={`Open ${card.display_name}`}>
                  <span className="sr-only">Open profile</span>
                </Link>
                {card.photoUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={card.photoUrl} alt="" className="h-full w-full object-cover" />
                ) : (
                  <div className="grid h-full place-items-center text-ink-soft">No photo</div>
                )}
                {isNewMember(card.created_at) ? (
                  <span className="absolute top-0 left-0 z-10 bg-sage px-2 py-1 text-[10px] font-bold tracking-wide text-paper">NEW</span>
                ) : null}
                {card.is_online ? <span className="absolute bottom-2 left-2 z-10 h-3 w-3 rounded-full bg-sage ring-2 ring-paper" title="Online" /> : null}
                <div className="absolute right-2 bottom-2 z-10 flex items-center gap-1 rounded-full bg-ink/70 px-1.5 py-1 text-paper">
                  <button type="button" title="Like" onClick={() => onLike(card)} className={`grid h-7 w-7 place-items-center ${liked.has(card.user_id) ? "text-clay" : ""}`}>
                    <HeartIcon filled={liked.has(card.user_id)} />
                  </button>
                  <button type="button" title="Message" onClick={() => onMessage(card)} className="grid h-7 w-7 place-items-center">
                    <ChatIcon />
                  </button>
                  <button type="button" title="Favorite" onClick={() => onFavorite(card)} className="grid h-7 w-7 place-items-center">
                    <StarIcon />
                  </button>
                  <Link
                    href={`/app/people/${card.user_id}`}
                    className="inline-flex items-center gap-0.5 pr-1 text-xs"
                    title="Photos"
                  >
                    <CameraIcon />
                    {card.photo_count ?? (card.photoUrl ? 1 : 0)}
                  </Link>
                </div>
              </div>
              <div className="space-y-1 px-3 pt-3 pb-2">
                <Link href={`/app/people/${card.user_id}`} className="block">
                  <h3 className="truncate text-lg font-semibold leading-tight text-ink">{card.display_name}</h3>
                  <p className="truncate text-sm text-ink-soft">{[card.age_years, card.city].filter(Boolean).join(" • ") || "Location kept broad"}</p>
                  <p className="truncate text-sm text-ink-soft">
                    {t("seeking")}: {seekingLine(card)}
                  </p>
                  <p className={`text-sm font-medium ${card.is_online ? "text-sage" : "text-ink-soft"}`}>
                    {formatLastSeen(card.is_online, card.last_seen_at)}
                  </p>
                </Link>
                <div className="flex gap-3 pt-1 text-xs font-semibold text-ink-soft">
                  <button type="button" onClick={() => onPass(card)}>
                    Pass
                  </button>
                  <button type="button" onClick={() => onBlock(card)}>
                    Block
                  </button>
                  <button type="button" onClick={() => onReport(card)} className="text-clay-deep">
                    Report
                  </button>
                </div>
              </div>
            </li>
          ))}
        </ul>
      )}

      {!lockedList && filtered.length > pageSize ? (
        <div className="flex items-center justify-center gap-3 text-sm">
          <button
            type="button"
            disabled={safePage <= 1}
            onClick={() => setPage((value) => Math.max(1, value - 1))}
            className="rounded-md bg-paper px-3 py-1.5 ring-1 ring-line disabled:opacity-40"
          >
            {t("prev")}
          </button>
          <span>
            {t("page")} {safePage} / {pageCount}
          </span>
          <button
            type="button"
            disabled={safePage >= pageCount}
            onClick={() => setPage((value) => value + 1)}
            className="rounded-md bg-paper px-3 py-1.5 ring-1 ring-line disabled:opacity-40"
          >
            {t("next")}
          </button>
        </div>
      ) : null}
    </section>
  );
}

function relevance(card: DiscoveryCard, ownCity: string | null, ownIntent: string): number {
  let score = 0;
  if (ownCity && card.city && card.city.toLowerCase() === ownCity.toLowerCase()) score += 30;
  if (ownIntent && card.relationship_intent === ownIntent) score += 20;
  if (card.is_online) score += 15;
  if (card.photoUrl || card.photo_path) score += 10;
  if (card.photo_verified_at) score += 5;
  const created = card.created_at ? Date.parse(card.created_at) : 0;
  if (created) {
    const days = (Date.now() - created) / 86_400_000;
    score += Math.max(0, 8 - days);
  }
  return score;
}

function Count({ label, value, href }: { label: string; value: number; href: string }) {
  return (
    <Link href={href} className="rounded-md bg-cream px-3 py-2">
      <dt className="text-ink-soft">{label}</dt>
      <dd className="text-lg font-semibold text-ink">{value}</dd>
    </Link>
  );
}

function FilterSelect({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: string;
  options: string[];
  onChange: (value: string) => void;
}) {
  return (
    <label className="inline-flex items-center gap-2 rounded-full bg-paper px-3 py-1.5 text-sm text-ink ring-1 ring-[#cfc4b4]">
      {label}
      <select value={value} onChange={(event) => onChange(event.target.value)} className="bg-transparent">
        {options.map((option) => (
          <option key={option || "any"} value={option}>
            {option || "Any"}
          </option>
        ))}
      </select>
    </label>
  );
}

function HeartIcon({ filled = false }: { filled?: boolean }) {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill={filled ? "currentColor" : "none"} aria-hidden="true">
      <path d="M12 21s-7-4.6-9.5-9A5.2 5.2 0 0 1 12 6a5.2 5.2 0 0 1 9.5 6C19 16.4 12 21 12 21z" stroke="currentColor" strokeWidth="1.7" />
    </svg>
  );
}

function ChatIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M5 6.5A2.5 2.5 0 0 1 7.5 4h9A2.5 2.5 0 0 1 19 6.5v7A2.5 2.5 0 0 1 16.5 16H10l-4 3.5V6.5z" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" />
    </svg>
  );
}

function StarIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="m12 3.5 2.4 4.9 5.4.8-3.9 3.8.9 5.4L12 15.8 7.2 18.4l.9-5.4-3.9-3.8 5.4-.8L12 3.5z" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" />
    </svg>
  );
}

function CameraIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="3.5" y="7" width="17" height="12" rx="2" stroke="currentColor" strokeWidth="1.7" />
      <circle cx="12" cy="13" r="3" stroke="currentColor" strokeWidth="1.7" />
    </svg>
  );
}

function LockIcon({ color = "currentColor" }: { color?: string }) {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="5" y="11" width="14" height="9" rx="2" stroke={color} strokeWidth="1.7" />
      <path d="M8 11V8a4 4 0 0 1 8 0v3" stroke={color} strokeWidth="1.7" />
    </svg>
  );
}

function CheckIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.7" />
      <path d="m8 12.5 2.5 2.5L16 9.5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
    </svg>
  );
}

function SlidersIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M4 7h10M18 7h2M4 17h2M10 17h10M14 4v6M8 14v6" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
    </svg>
  );
}
