"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import {
  type DiscoveryCard,
  addFavorite,
  blockPerson,
  formatLastSeen,
  intentLabel,
  isNewMember,
  loadDiscoveryCards,
  openConversation,
  passPerson,
  reportPerson,
  sendLike,
} from "@/lib/member-data";

type Mode = "forYou" | "mutual" | "online" | "newest" | "latestPhotos" | "inArea";

const modes: { id: Mode; label: string; icon: "heart" | "lock" | "chat" | "user" | "camera" | "pin" }[] = [
  { id: "forYou", label: "Matches", icon: "heart" },
  { id: "mutual", label: "Mutual Matches", icon: "lock" },
  { id: "online", label: "Online", icon: "chat" },
  { id: "newest", label: "Newest members", icon: "user" },
  { id: "latestPhotos", label: "Latest Photos", icon: "camera" },
  { id: "inArea", label: "In My Area", icon: "pin" },
];

export function DesktopDiscover() {
  const [cards, setCards] = useState<DiscoveryCard[]>([]);
  const [liked, setLiked] = useState<Set<string>>(new Set());
  const [mode, setMode] = useState<Mode>("forYou");
  const [note, setNote] = useState("Loading members…");
  const [userId, setUserId] = useState<string | null>(null);
  const [ownCity, setOwnCity] = useState<string | null>(null);
  const [ageOpen, setAgeOpen] = useState(false);
  const [ageMin, setAgeMin] = useState(18);
  const [ageMax, setAgeMax] = useState(80);

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
      const [{ data: me }, list] = await Promise.all([
        supabase.from("profiles").select("city").eq("user_id", id).maybeSingle(),
        loadDiscoveryCards(supabase, id),
      ]);
      setOwnCity((me?.city as string | null) ?? null);
      setCards(list);
      setNote(list.length === 0 ? "No profiles to show yet." : "");
    });
  }, []);

  const visible = useMemo(() => {
    let list = [...cards];
    list = list.filter((card) => {
      if (card.age_years == null) return true;
      return card.age_years >= ageMin && card.age_years <= ageMax;
    });
    if (mode === "online") list = list.filter((card) => card.is_online);
    if (mode === "inArea" && ownCity) {
      const city = ownCity.toLowerCase();
      list = list.filter((card) => (card.city ?? "").toLowerCase().includes(city) || city.includes((card.city ?? "").toLowerCase()));
    }
    if (mode === "newest" || mode === "latestPhotos") {
      list.sort((a, b) => String(b.created_at ?? "").localeCompare(String(a.created_at ?? "")));
    }
    if (mode === "mutual") {
      list = list.filter((card) => liked.has(card.user_id));
    }
    if (mode === "latestPhotos") {
      list = list.filter((card) => Boolean(card.photoUrl || card.photo_path));
    }
    return list;
  }, [cards, mode, ageMin, ageMax, ownCity, liked]);

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
    if (matchId) window.location.href = `/app/messages?match=${matchId}`;
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

  return (
    <section className="grid gap-3">
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
                  active
                    ? "bg-clay-deep text-paper"
                    : "bg-paper text-ink ring-1 ring-[#cfc4b4] hover:bg-cream"
                }`}
              >
                <ModeIcon name={item.icon} active={active} />
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
        <button
          type="button"
          className="inline-flex items-center gap-2 rounded-full bg-paper px-3 py-1.5 text-sm text-ink-soft ring-1 ring-[#cfc4b4]"
          disabled
          title="Coming soon"
        >
          <LockIcon /> Body style
        </button>
        <button
          type="button"
          className="inline-flex items-center gap-2 rounded-full bg-paper px-3 py-1.5 text-sm text-ink-soft ring-1 ring-[#cfc4b4]"
          disabled
          title="Coming soon"
        >
          <LockIcon /> Education
        </button>
        <button
          type="button"
          onClick={() => setAgeOpen((value) => !value)}
          className={`inline-flex items-center gap-2 rounded-full px-3 py-1.5 text-sm ring-1 ${
            ageOpen ? "bg-cream text-clay-deep ring-clay" : "bg-paper text-ink ring-[#cfc4b4]"
          }`}
        >
          <CheckIcon /> Age {ageMin}–{ageMax}
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

      {visible.length === 0 && userId ? (
        <p className="rounded-xl border border-dashed border-gold bg-paper px-5 py-10 text-center text-ink-soft">
          No members in this view yet. Try another filter.
        </p>
      ) : (
        <ul className="grid grid-cols-2 gap-3 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-6">
          {visible.map((card) => (
            <li key={card.user_id} className="overflow-hidden rounded-md bg-paper shadow-[0_1px_3px_rgba(0,0,0,0.12)] ring-1 ring-black/5">
              <div className="relative aspect-[3/4] bg-[#e7dccb]">
                {card.photoUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={card.photoUrl} alt="" className="h-full w-full object-cover" />
                ) : (
                  <div className="grid h-full place-items-center text-ink-soft">No photo</div>
                )}
                {isNewMember(card.created_at) ? (
                  <span className="absolute top-0 left-0 bg-sage px-2 py-1 text-[10px] font-bold tracking-wide text-paper">
                    NEW
                  </span>
                ) : null}
                {card.is_online ? (
                  <span className="absolute bottom-2 left-2 h-3 w-3 rounded-full bg-sage ring-2 ring-paper" title="Online" />
                ) : null}
              </div>
              <div className="space-y-1 px-3 pt-3 pb-2">
                <h3 className="truncate text-lg font-semibold leading-tight text-ink">{card.display_name}</h3>
                <p className="truncate text-sm text-ink-soft">
                  {[card.age_years, card.city].filter(Boolean).join(" • ") || "Location kept broad"}
                </p>
                <p className="truncate text-sm text-ink-soft">
                  Seeking: {intentLabel(card.relationship_intent)}
                  {card.age_preference_min && card.age_preference_max
                    ? `, ${card.age_preference_min}–${card.age_preference_max}`
                    : ""}
                </p>
                <p className={`text-sm font-medium ${card.is_online ? "text-sage" : "text-ink-soft"}`}>
                  {formatLastSeen(card.is_online, card.last_seen_at)}
                </p>
              </div>
              <div className="flex items-center justify-around border-t border-[#ece5da] bg-[#f7f3ec] px-2 py-2 text-ink-soft">
                <button
                  type="button"
                  title="Like"
                  onClick={() => onLike(card)}
                  className={`grid h-8 w-8 place-items-center rounded-full hover:bg-paper ${liked.has(card.user_id) ? "text-clay" : ""}`}
                >
                  <HeartIcon filled={liked.has(card.user_id)} />
                </button>
                <button
                  type="button"
                  title="Message"
                  onClick={() => onMessage(card)}
                  className="grid h-8 w-8 place-items-center rounded-full hover:bg-paper"
                >
                  <ChatIcon />
                </button>
                <button
                  type="button"
                  title="Favorite"
                  onClick={() => onFavorite(card)}
                  className="grid h-8 w-8 place-items-center rounded-full hover:bg-paper"
                >
                  <StarIcon />
                </button>
                <button
                  type="button"
                  title="Pass"
                  onClick={() => onPass(card)}
                  className="grid h-8 w-8 place-items-center rounded-full hover:bg-paper text-xs font-semibold"
                >
                  Pass
                </button>
                <button
                  type="button"
                  title="Block"
                  onClick={() => onBlock(card)}
                  className="grid h-8 w-8 place-items-center rounded-full hover:bg-paper text-xs font-semibold"
                >
                  Block
                </button>
                <button
                  type="button"
                  title="Report"
                  onClick={() => onReport(card)}
                  className="grid h-8 w-8 place-items-center rounded-full hover:bg-paper text-xs font-semibold text-clay-deep"
                >
                  Report
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function ModeIcon({ name, active }: { name: (typeof modes)[number]["icon"]; active: boolean }) {
  const stroke = active ? "#fffdf8" : "#9c1b4e";
  if (name === "heart") {
    return (
      <svg width="14" height="14" viewBox="0 0 24 24" fill={active ? stroke : "none"} aria-hidden="true">
        <path d="M12 21s-7-4.6-9.5-9A5.2 5.2 0 0 1 12 6a5.2 5.2 0 0 1 9.5 6C19 16.4 12 21 12 21z" stroke={stroke} strokeWidth="1.7" />
      </svg>
    );
  }
  if (name === "lock") return <LockIcon color={stroke} />;
  if (name === "chat") return <ChatIcon color={stroke} />;
  if (name === "camera") return <CameraIcon color={stroke} />;
  if (name === "pin") {
    return (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path d="M12 21s6-5.2 6-10a6 6 0 1 0-12 0c0 4.8 6 10 6 10z" stroke={stroke} strokeWidth="1.7" />
        <circle cx="12" cy="11" r="2.2" stroke={stroke} strokeWidth="1.7" />
      </svg>
    );
  }
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="8" r="3.2" stroke={stroke} strokeWidth="1.7" />
      <path d="M5 19c1.6-3.2 4-4.8 7-4.8S17.4 15.8 19 19" stroke={stroke} strokeWidth="1.7" strokeLinecap="round" />
    </svg>
  );
}

function HeartIcon({ filled = false }: { filled?: boolean }) {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill={filled ? "currentColor" : "none"} aria-hidden="true">
      <path d="M12 21s-7-4.6-9.5-9A5.2 5.2 0 0 1 12 6a5.2 5.2 0 0 1 9.5 6C19 16.4 12 21 12 21z" stroke="currentColor" strokeWidth="1.7" />
    </svg>
  );
}

function ChatIcon({ color = "currentColor" }: { color?: string }) {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M5 6.5A2.5 2.5 0 0 1 7.5 4h9A2.5 2.5 0 0 1 19 6.5v7A2.5 2.5 0 0 1 16.5 16H10l-4 3.5V6.5z" stroke={color} strokeWidth="1.7" strokeLinejoin="round" />
    </svg>
  );
}

function StarIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="m12 3.5 2.4 4.9 5.4.8-3.9 3.8.9 5.4L12 15.8 7.2 18.4l.9-5.4-3.9-3.8 5.4-.8L12 3.5z" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" />
    </svg>
  );
}

function CameraIcon({ color = "currentColor" }: { color?: string }) {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="3.5" y="7" width="17" height="12" rx="2" stroke={color} strokeWidth="1.7" />
      <path d="M8 7 9.4 4.8h5.2L16 7" stroke={color} strokeWidth="1.7" strokeLinejoin="round" />
      <circle cx="12" cy="13" r="3" stroke={color} strokeWidth="1.7" />
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
