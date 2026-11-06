"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { useMemberSession } from "@/hooks/useMemberSession";
import { useLang } from "@/components/LanguageProvider";
import {
  type MemberProfile,
  addFavorite,
  blockPerson,
  formatLastSeen,
  loadMemberProfile,
  openConversation,
  passPerson,
  recordProfileView,
  reportPerson,
  seekingLine,
  sendLike,
} from "@/lib/member-data";

export default function MemberProfilePage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const session = useMemberSession();
  const { t } = useLang();
  const otherId = useMemo(() => String(params?.id ?? ""), [params]);
  const [profile, setProfile] = useState<MemberProfile | null>(null);
  const [photoIndex, setPhotoIndex] = useState(0);
  const [liked, setLiked] = useState(false);
  const [note, setNote] = useState("Loading profile…");

  useEffect(() => {
    if (!session.userId || !otherId) {
      if (session.ready) setNote("Log in to view member profiles.");
      return;
    }
    const supabase = createClient();
    if (!supabase) return;
    let cancelled = false;
    (async () => {
      await recordProfileView(supabase, otherId);
      const next = await loadMemberProfile(supabase, session.userId!, otherId);
      if (cancelled) return;
      setProfile(next);
      setNote(next ? "" : "This member could not be loaded.");
      setPhotoIndex(0);
    })();
    return () => {
      cancelled = true;
    };
  }, [session.ready, session.userId, otherId]);

  async function onLike() {
    if (!session.userId || !profile) return;
    const supabase = createClient();
    if (!supabase) return;
    const error = await sendLike(supabase, session.userId, profile.user_id);
    if (!error) {
      setLiked(true);
      setNote("Like sent.");
    }
  }

  async function onMessage() {
    if (!profile) return;
    const supabase = createClient();
    if (!supabase) return;
    const matchId = await openConversation(supabase, profile.user_id);
    if (matchId) router.push(`/app/messages?match=${matchId}`);
    else setNote("Chat opens after you both like each other.");
  }

  async function onFavorite() {
    if (!session.userId || !profile) return;
    const supabase = createClient();
    if (!supabase) return;
    await addFavorite(supabase, session.userId, profile.user_id);
    setNote("Saved to your private favorites.");
  }

  async function onPass() {
    if (!session.userId || !profile) return;
    const supabase = createClient();
    if (!supabase) return;
    const error = await passPerson(supabase, session.userId, profile.user_id);
    if (!error) router.push("/app");
  }

  async function onBlock() {
    if (!session.userId || !profile) return;
    const supabase = createClient();
    if (!supabase) return;
    const error = await blockPerson(supabase, session.userId, profile.user_id);
    if (!error) router.push("/app");
  }

  async function onReport() {
    if (!session.userId || !profile) return;
    const supabase = createClient();
    if (!supabase) return;
    const reason = window.prompt(
      "Report reason: harassment, scam, impersonation, outing_threat, coercion, spam, or other",
      "other",
    );
    if (!reason) return;
    await reportPerson(supabase, session.userId, profile.user_id, reason);
    setNote("Report sent for review.");
  }

  const photos = profile?.photoUrls?.length ? profile.photoUrls : profile?.photoUrl ? [profile.photoUrl] : [];
  const activePhoto = photos[photoIndex] ?? null;

  return (
    <main className="mx-auto grid max-w-4xl gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <button
          type="button"
          onClick={() => {
            if (typeof window !== "undefined" && window.history.length > 1) router.back();
            else router.push("/app");
          }}
          className="text-sm font-semibold text-clay-deep underline"
        >
          ← Back
        </button>
        <Link href="/app" className="text-sm font-semibold text-clay-deep underline">
          Home
        </Link>
      </div>

      {note ? <p className="text-sm text-ink-soft">{note}</p> : null}

      {!profile ? null : (
        <section className="grid gap-4 overflow-hidden rounded-2xl bg-paper ring-1 ring-line md:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)]">
          <div className="relative min-h-[360px] bg-[#e7dccb]">
            {activePhoto ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={activePhoto} alt="" className="h-full w-full object-cover" />
            ) : (
              <div className="grid h-full min-h-[360px] place-items-center text-ink-soft">No photo</div>
            )}
            {photos.length > 1 ? (
              <div className="absolute inset-x-0 bottom-3 flex justify-center gap-2">
                {photos.map((url, index) => (
                  <button
                    key={url}
                    type="button"
                    aria-label={`Photo ${index + 1}`}
                    onClick={() => setPhotoIndex(index)}
                    className={`h-2.5 w-2.5 rounded-full ${index === photoIndex ? "bg-paper" : "bg-paper/50"}`}
                  />
                ))}
              </div>
            ) : null}
            {photos.length > 1 ? (
              <>
                <button
                  type="button"
                  aria-label="Previous photo"
                  onClick={() => setPhotoIndex((value) => (value - 1 + photos.length) % photos.length)}
                  className="absolute top-1/2 left-2 grid h-9 w-9 -translate-y-1/2 place-items-center rounded-full bg-ink/55 text-paper"
                >
                  ‹
                </button>
                <button
                  type="button"
                  aria-label="Next photo"
                  onClick={() => setPhotoIndex((value) => (value + 1) % photos.length)}
                  className="absolute top-1/2 right-2 grid h-9 w-9 -translate-y-1/2 place-items-center rounded-full bg-ink/55 text-paper"
                >
                  ›
                </button>
              </>
            ) : null}
          </div>

          <div className="grid gap-3 p-5">
            <div>
              <h1 className="text-3xl font-semibold text-ink">{profile.display_name}</h1>
              <p className="text-ink-soft">
                {[profile.age_years, profile.city].filter(Boolean).join(" • ") || "Location kept broad"}
              </p>
              <p className={`mt-1 text-sm font-medium ${profile.is_online ? "text-sage" : "text-ink-soft"}`}>
                {formatLastSeen(profile.is_online, profile.last_seen_at)}
              </p>
            </div>
            <p className="text-sm text-ink-soft">
              {t("seeking")}: {seekingLine(profile)}
            </p>
            {profile.bio ? <p className="text-sm leading-6 text-ink">{profile.bio}</p> : null}
            <p className="text-xs text-ink-soft">
              {[profile.body_type, profile.education, photos.length ? `${photos.length} photos` : null]
                .filter(Boolean)
                .join(" · ")}
            </p>
            <div className="flex flex-wrap gap-2 pt-2">
              <button
                type="button"
                onClick={onLike}
                className={`rounded-full px-4 py-2 text-sm font-semibold text-paper ${liked ? "bg-clay-deep" : "bg-clay"}`}
              >
                {liked ? "Liked" : "Like"}
              </button>
              <button
                type="button"
                onClick={onMessage}
                className="rounded-full bg-paper px-4 py-2 text-sm font-semibold text-clay-deep ring-1 ring-line"
              >
                Message
              </button>
              <button
                type="button"
                onClick={onFavorite}
                className="rounded-full bg-paper px-4 py-2 text-sm font-semibold text-ink ring-1 ring-line"
              >
                Favorite
              </button>
            </div>
            <div className="flex flex-wrap gap-3 pt-1 text-xs font-semibold text-ink-soft">
              <button type="button" onClick={onPass}>
                Pass
              </button>
              <button type="button" onClick={onBlock}>
                Block
              </button>
              <button type="button" onClick={onReport} className="text-clay-deep">
                Report
              </button>
            </div>
          </div>
        </section>
      )}
    </main>
  );
}
