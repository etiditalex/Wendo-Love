"use client";

import { ChangeEvent, FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { consentVersion, isAdult, product } from "@/lib/domain";
import { createClient } from "@/lib/supabase/client";
import { useMemberSession } from "@/hooks/useMemberSession";
import {
  type ChatLine,
  type DiscoveryCard,
  type MatchThread,
  type OwnProfile,
  type ReceivedLike,
  addFavorite,
  approvePhotoVerify,
  blockPerson,
  exportOwnAccount,
  formatLastSeen,
  intentLabel,
  isStaffMember,
  loadDiscoveryCards,
  loadFavoritePeople,
  loadMatchThreads,
  loadMessages,
  loadModerationQueue,
  loadOwnProfile,
  loadPhotoVerifyQueue,
  loadProfileViewers,
  loadReceivedLikes,
  openConversation,
  passPerson,
  recordProfileView,
  reportPerson,
  saveBlurUntilMutual,
  sendLike,
  sendMessage,
  setReportStatus,
  uploadProfilePhoto,
  videoRoomUrlForMatch,
} from "@/lib/member-data";
import { joinDraftKey } from "./AuthForms";

export function SignedOutNote() {
  const session = useMemberSession();
  if (!session.ready) return <p className="text-sm text-ink-soft">Checking session…</p>;
  if (!session.configured) {
    return (
      <p className="rounded-2xl bg-paper px-4 py-3 text-sm leading-6 text-ink-soft ring-1 ring-line">
        Supabase is not connected yet. Copy <code>apps/web/.env.example</code> to{" "}
        <code>.env.local</code> and add the project URL and anon key.
      </p>
    );
  }
  if (!session.userId) {
    return (
      <p className="text-sm text-ink-soft">
        <Link href="/login" className="font-semibold text-clay-deep underline">
          Log in
        </Link>{" "}
        with the same account you use in the Wendo app. Profiles, likes, and chats stay in sync.
      </p>
    );
  }
  return <p className="text-sm text-ink-soft">Signed in as {session.email}. Same live database as the phone app.</p>;
}

export function DiscoverPanel() {
  const session = useMemberSession();
  const [cards, setCards] = useState<DiscoveryCard[]>([]);
  const [note, setNote] = useState("Loading members…");
  const [liked, setLiked] = useState<Set<string>>(new Set());

  useEffect(() => {
    if (!session.userId) {
      if (session.ready) setNote("Log in to see live Wendo profiles.");
      return;
    }
    const supabase = createClient();
    if (!supabase) return;
    loadDiscoveryCards(supabase, session.userId).then((list) => {
      setCards(list);
      setNote(list.length === 0 ? "No suggestions yet." : "Live members from the same Wendo database as the app.");
    });
  }, [session.ready, session.userId]);

  async function onLike(card: DiscoveryCard) {
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    const error = await sendLike(supabase, session.userId, card.user_id);
    if (!error) setLiked((prev) => new Set(prev).add(card.user_id));
  }

  async function onMessage(card: DiscoveryCard) {
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    await recordProfileView(supabase, card.user_id);
    const matchId = await openConversation(supabase, card.user_id);
    if (matchId) window.location.href = `/app/messages?match=${matchId}`;
  }

  async function onPass(card: DiscoveryCard) {
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    const error = await passPerson(supabase, session.userId, card.user_id);
    if (!error) setCards((prev) => prev.filter((row) => row.user_id !== card.user_id));
  }

  async function onBlock(card: DiscoveryCard) {
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    const error = await blockPerson(supabase, session.userId, card.user_id);
    if (!error) setCards((prev) => prev.filter((row) => row.user_id !== card.user_id));
  }

  async function onReport(card: DiscoveryCard) {
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    const reason = window.prompt("Report reason: harassment, scam, impersonation, outing_threat, coercion, spam, or other", "other");
    if (!reason) return;
    await reportPerson(supabase, session.userId, card.user_id, reason);
    setNote("Report sent for review.");
  }

  async function onFavorite(card: DiscoveryCard) {
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    await addFavorite(supabase, session.userId, card.user_id);
    setNote("Saved to your private favorites.");
  }

  return (
    <section className="grid gap-4">
      <SignedOutNote />
      <p className="text-sm leading-6 text-ink-soft">{note}</p>
      {cards.length === 0 ? (
        <Empty title="No suggestions yet" body="Finish your profile in the app or on web. People appear here from the shared database." />
      ) : (
        <ul className="grid gap-3">
          {cards.map((card) => (
            <li key={card.user_id} className="overflow-hidden rounded-2xl bg-paper ring-1 ring-line">
              {card.photoUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={card.photoUrl} alt="" className="h-48 w-full object-cover" />
              ) : null}
              <div className="p-5">
                <h3 className="font-serif text-2xl">{card.display_name}</h3>
                <p className="text-sm text-ink-soft">
                  {card.age_years != null ? `${card.age_years} · ` : ""}
                  {card.city || "Location kept broad"} · {intentLabel(card.relationship_intent)}
                </p>
                {card.bio ? <p className="mt-2 text-sm leading-6">{card.bio}</p> : null}
                <p className="mt-1 text-sm text-ink-soft">{formatLastSeen(card.is_online, card.last_seen_at)}</p>
                <div className="mt-4 flex flex-wrap gap-2">
                  <button
                    type="button"
                    onClick={() => onLike(card)}
                    className={`rounded-full px-4 py-2 text-sm font-semibold ${
                      liked.has(card.user_id) ? "bg-clay text-paper" : "bg-cream text-clay-deep ring-1 ring-line"
                    }`}
                  >
                    {liked.has(card.user_id) ? "Liked" : "Like"}
                  </button>
                  <button
                    type="button"
                    onClick={() => onMessage(card)}
                    className="rounded-full bg-clay-deep px-4 py-2 text-sm font-semibold text-paper"
                  >
                    Message
                  </button>
                  <button type="button" onClick={() => onFavorite(card)} className="rounded-full bg-cream px-4 py-2 text-sm ring-1 ring-line">
                    Favorite
                  </button>
                  <button type="button" onClick={() => onPass(card)} className="rounded-full bg-cream px-4 py-2 text-sm ring-1 ring-line">
                    Pass
                  </button>
                  <button type="button" onClick={() => onBlock(card)} className="rounded-full bg-cream px-4 py-2 text-sm ring-1 ring-line">
                    Block
                  </button>
                  <button type="button" onClick={() => onReport(card)} className="rounded-full bg-cream px-4 py-2 text-sm text-clay-deep ring-1 ring-line">
                    Report
                  </button>
                </div>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export function ProfilePanel() {
  const session = useMemberSession();
  const [message, setMessage] = useState<string | null>(null);
  const [draft, setDraft] = useState<JoinDraft | null>(null);
  const [profile, setProfile] = useState<OwnProfile | null>(null);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    const raw = window.sessionStorage.getItem(joinDraftKey);
    if (raw) {
      try {
        setDraft(JSON.parse(raw) as JoinDraft);
      } catch {
        setDraft(null);
      }
    }
  }, []);

  useEffect(() => {
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    loadOwnProfile(supabase, session.userId).then((row) => {
      setProfile(row);
      setLoaded(true);
    });
  }, [session.userId]);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const dateOfBirth = String(form.get("dateOfBirth") ?? "");
    if (!isAdult(dateOfBirth)) {
      setMessage("Members must be 18 or over.");
      return;
    }
    const supabase = createClient();
    if (!supabase || !session.userId) {
      setMessage("Sign in before this profile can be saved.");
      return;
    }

    const next = {
      user_id: session.userId,
      display_name: String(form.get("displayName") ?? ""),
      city: String(form.get("city") ?? "") || null,
      bio: String(form.get("bio") ?? "") || null,
      relationship_intent: String(form.get("relationshipIntent") ?? "unsure"),
      languages: splitList(form.get("languages")),
      interests: splitList(form.get("interests")),
      family_goals: String(form.get("familyGoals") ?? "") || null,
      children_preference: String(form.get("childrenPreference") ?? "") || null,
      communication_boundaries: String(form.get("boundaries") ?? "") || null,
      age_preference_min: Number(form.get("ageMin") ?? 18),
      age_preference_max: Number(form.get("ageMax") ?? 80),
      gender: String(form.get("gender") ?? "") || null,
      seeking_genders: form.getAll("seeking").map(String),
      education: String(form.get("education") ?? "") || null,
      body_type: String(form.get("bodyType") ?? "") || null,
      onboarding_completed: true,
    };

    const { error: identityError } = await supabase.from("private_identity").upsert({
      user_id: session.userId,
      date_of_birth: dateOfBirth,
      country_code: "KE",
    });
    if (identityError) {
      setMessage(identityError.message);
      return;
    }
    const saved = await supabase.from("profiles").upsert(next);
    let profileError = saved.error;
    if (profileError && /gender|seeking_genders|education|schema cache|column/i.test(profileError.message)) {
      const { gender: _gender, seeking_genders: _seeking, education: _education, ...rest } = next;
      const retry = await supabase.from("profiles").upsert(rest);
      profileError = retry.error;
      if (!profileError) {
        setMessage("Profile saved. Apply the latest database migration before gender, seeking, and education can be stored.");
        return;
      }
    }
    if (profileError) {
      setMessage(profileError.message);
      return;
    }
    await supabase.from("consents").insert([
      { user_id: session.userId, consent_type: "terms", version: consentVersion },
      { user_id: session.userId, consent_type: "privacy", version: consentVersion },
      { user_id: session.userId, consent_type: "community_rules", version: consentVersion },
    ]);
    window.sessionStorage.removeItem(joinDraftKey);
    setMessage("Profile saved. Changes show in the phone app too.");
    setProfile({
      display_name: next.display_name,
      city: next.city,
      bio: next.bio,
      relationship_intent: next.relationship_intent,
      languages: next.languages,
      interests: next.interests,
      family_goals: next.family_goals,
      children_preference: next.children_preference,
      communication_boundaries: next.communication_boundaries,
      age_preference_min: next.age_preference_min,
      age_preference_max: next.age_preference_max,
      gender: next.gender,
      seeking_genders: next.seeking_genders,
      education: next.education,
      body_type: next.body_type,
      date_of_birth: dateOfBirth,
    });
  }

  const values = {
    displayName: profile?.display_name || draft?.displayName || "",
    dateOfBirth: profile?.date_of_birth || draft?.dateOfBirth || "",
    city: profile?.city || draft?.city || "",
    relationshipIntent: profile?.relationship_intent || draft?.relationshipIntent || "marriage",
    bio: profile?.bio || "",
    languages: profile?.languages.join(", ") || "",
    interests: profile?.interests.join(", ") || "",
    familyGoals: profile?.family_goals || "",
    childrenPreference: profile?.children_preference || "",
    boundaries: profile?.communication_boundaries || "",
    ageMin: String(profile?.age_preference_min ?? 18),
    ageMax: String(profile?.age_preference_max ?? 80),
    gender: profile?.gender || "",
    seeking: profile?.seeking_genders ?? [],
    education: profile?.education || "",
    bodyType: profile?.body_type || "",
  };

  async function onPhoto(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file || !session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    const error = await uploadProfilePhoto(supabase, session.userId, file);
    setMessage(error ?? "Photo uploaded. It shows on Home for other members.");
  }

  return (
    <form key={`${loaded}-${values.displayName}`} onSubmit={onSubmit} className="grid gap-4">
      <SignedOutNote />
      <label className="grid gap-1 text-sm">
        <span className="font-semibold">Profile photo</span>
        <input type="file" accept="image/*" onChange={onPhoto} className="rounded-xl border border-line bg-paper px-3 py-2" />
      </label>
      <TextField label="Display name" name="displayName" defaultValue={values.displayName} required />
      <TextField label="Date of birth" name="dateOfBirth" type="date" defaultValue={values.dateOfBirth} required />
      <TextField label="City or broad area" name="city" defaultValue={values.city} />
      <label className="grid gap-1 text-sm">
        <span className="font-semibold">I am</span>
        <select name="gender" defaultValue={values.gender} className="rounded-xl border border-line bg-paper px-3 py-2">
          <option value="">Prefer not to say yet</option>
          <option value="woman">A woman</option>
          <option value="man">A man</option>
          <option value="nonbinary">Nonbinary</option>
        </select>
      </label>
      <fieldset className="grid gap-2 text-sm">
        <legend className="font-semibold">I hope to meet</legend>
        {product.genders.map((gender) => (
          <label key={gender.id} className="flex items-center gap-2">
            <input type="checkbox" name="seeking" value={gender.id} defaultChecked={values.seeking.includes(gender.id)} />
            {gender.label}
          </label>
        ))}
      </fieldset>
      <label className="grid gap-1 text-sm">
        <span className="font-semibold">Education</span>
        <select name="education" defaultValue={values.education} className="rounded-xl border border-line bg-paper px-3 py-2">
          <option value="">Prefer not to say</option>
          <option value="secondary">Secondary</option>
          <option value="diploma">Diploma</option>
          <option value="degree">Degree</option>
          <option value="postgraduate">Postgraduate</option>
        </select>
      </label>
      <label className="grid gap-1 text-sm">
        <span className="font-semibold">Body style</span>
        <select name="bodyType" defaultValue={values.bodyType} className="rounded-xl border border-line bg-paper px-3 py-2">
          <option value="">Prefer not to say</option>
          <option value="slim">Slim</option>
          <option value="average">Average</option>
          <option value="athletic">Athletic</option>
          <option value="curvy">Curvy</option>
        </select>
      </label>
      <label className="grid gap-1 text-sm">
        <span className="font-semibold">Relationship intent</span>
        <select
          name="relationshipIntent"
          defaultValue={values.relationshipIntent}
          className="rounded-xl border border-line bg-paper px-3 py-2"
        >
          {product.relationshipIntents.map((intent) => (
            <option key={intent.id} value={intent.id}>
              {intent.label}
            </option>
          ))}
        </select>
      </label>
      <TextField label="Bio" name="bio" defaultValue={values.bio} />
      <TextField label="Languages, comma separated" name="languages" placeholder="Swahili, English" defaultValue={values.languages} />
      <TextField label="Interests, comma separated" name="interests" defaultValue={values.interests} />
      <TextField label="Family goals" name="familyGoals" defaultValue={values.familyGoals} />
      <TextField label="Children preference" name="childrenPreference" defaultValue={values.childrenPreference} />
      <TextField label="Communication boundaries" name="boundaries" defaultValue={values.boundaries} />
      <div className="grid grid-cols-2 gap-3">
        <TextField label="Preferred age from" name="ageMin" type="number" defaultValue={values.ageMin} />
        <TextField label="Preferred age to" name="ageMax" type="number" defaultValue={values.ageMax} />
      </div>
      {message ? <p className="text-sm text-clay-deep">{message}</p> : null}
      <button type="submit" className="rounded-full bg-clay px-5 py-3 font-semibold text-paper hover:bg-clay-deep">
        Save profile
      </button>
    </form>
  );
}

export function SettingsPanel() {
  const session = useMemberSession();
  const [message, setMessage] = useState<string | null>(null);
  const [blur, setBlur] = useState(false);
  const [exportJson, setExportJson] = useState<string | null>(null);
  const [favorites, setFavorites] = useState<ReceivedLike[]>([]);
  const [viewers, setViewers] = useState<ReceivedLike[]>([]);
  const [staff, setStaff] = useState(false);
  const [reports, setReports] = useState<Array<Record<string, unknown>>>([]);
  const [verifies, setVerifies] = useState<Array<Record<string, unknown>>>([]);

  useEffect(() => {
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    loadOwnProfile(supabase, session.userId).then((row) => {
      if (row) setBlur(Boolean(row.blur_until_mutual));
    });
    loadFavoritePeople(supabase, session.userId).then(setFavorites);
    loadProfileViewers(supabase, session.userId).then(setViewers);
    isStaffMember(supabase, session.userId).then(async (ok) => {
      setStaff(ok);
      if (!ok) return;
      setReports(await loadModerationQueue(supabase));
      setVerifies(await loadPhotoVerifyQueue(supabase));
    });
  }, [session.userId]);

  async function saveHealth(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    if (form.get("healthConsent") !== "on") {
      setMessage("Optional health information needs its own consent.");
      return;
    }
    const supabase = createClient();
    if (!supabase || !session.userId) {
      setMessage("Sign in before saving this private field.");
      return;
    }
    const { error } = await supabase.from("health_profiles").upsert({
      user_id: session.userId,
      self_described_status: String(form.get("status")),
      disclosure_preference: String(form.get("disclosure")),
      consent_version: consentVersion,
    });
    setMessage(error ? error.message : "Saved privately. This does not appear on discovery.");
  }

  async function setPaused(paused: boolean) {
    const supabase = createClient();
    if (!supabase || !session.userId) {
      setMessage("Sign in before pausing the account.");
      return;
    }
    const { error } = await supabase.from("profiles").update({ account_paused: paused }).eq("user_id", session.userId);
    setMessage(error ? error.message : paused ? "Account paused. Hidden from discovery on app and web." : "Account resumed.");
  }

  async function onBlur(next: boolean) {
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    setBlur(next);
    const error = await saveBlurUntilMutual(supabase, session.userId, next);
    setMessage(error ?? (next ? "Photos blur until mutual match." : "Photos show clearly before a match."));
  }

  async function onExport() {
    const supabase = createClient();
    if (!supabase) return;
    const data = await exportOwnAccount(supabase);
    if (!data) {
      setMessage("Export could not run. Apply the latest migrations.");
      return;
    }
    setExportJson(JSON.stringify(data, null, 2));
    setMessage("Export ready. Copy the JSON below.");
  }

  return (
    <div className="grid gap-6">
      <SignedOutNote />
      <section className="grid gap-3 rounded-2xl bg-paper p-5 ring-1 ring-line">
        <h2 className="font-serif text-2xl">Optional HIV status</h2>
        <p className="text-sm leading-6 text-ink-soft">
          Self-described, optional, and stored apart from your profile. Leave it unset if you prefer.
        </p>
        <form onSubmit={saveHealth} className="grid gap-3">
          <label className="grid gap-1 text-sm">
            <span className="font-semibold">Status</span>
            <select name="status" required className="rounded-xl border border-line bg-cream px-3 py-2" defaultValue="">
              <option value="" disabled>
                Choose only if you want this saved
              </option>
              {product.hivStatusOptions.map((option) => (
                <option key={option.id} value={option.id}>
                  {option.label}
                </option>
              ))}
            </select>
          </label>
          <label className="grid gap-1 text-sm">
            <span className="font-semibold">Sharing</span>
            <select name="disclosure" className="rounded-xl border border-line bg-cream px-3 py-2" defaultValue="never">
              {product.disclosurePreferences.map((option) => (
                <option key={option.id} value={option.id}>
                  {option.label}
                </option>
              ))}
            </select>
          </label>
          <label className="flex items-start gap-2 text-sm">
            <input name="healthConsent" type="checkbox" className="mt-1" />
            <span>I consent to storing this optional health information separately from my profile.</span>
          </label>
          <button type="submit" className="w-fit rounded-full bg-sage px-4 py-2 text-sm font-semibold text-paper">
            Save private status
          </button>
        </form>
      </section>
      <section className="grid gap-3 rounded-2xl bg-paper p-5 ring-1 ring-line">
        <h2 className="font-serif text-2xl">Photo privacy</h2>
        <label className="flex items-center gap-3 text-sm">
          <input type="checkbox" checked={blur} onChange={(event) => onBlur(event.target.checked)} />
          Blur photos until mutual match
        </label>
      </section>
      <section className="grid gap-3 rounded-2xl bg-paper p-5 ring-1 ring-line">
        <h2 className="font-serif text-2xl">Favorites</h2>
        {favorites.length === 0 ? (
          <p className="text-sm text-ink-soft">No favorites yet.</p>
        ) : (
          <ul className="grid gap-2 text-sm">
            {favorites.map((row) => (
              <li key={row.userId}>
                {row.name}
                {row.city ? ` · ${row.city}` : ""}
              </li>
            ))}
          </ul>
        )}
      </section>
      <section className="grid gap-3 rounded-2xl bg-paper p-5 ring-1 ring-line">
        <h2 className="font-serif text-2xl">Who viewed you</h2>
        {viewers.length === 0 ? (
          <p className="text-sm text-ink-soft">No views recorded yet.</p>
        ) : (
          <ul className="grid gap-2 text-sm">
            {viewers.map((row) => (
              <li key={row.userId}>
                {row.name}
                {row.city ? ` · ${row.city}` : ""}
              </li>
            ))}
          </ul>
        )}
      </section>
      <section className="flex flex-wrap gap-3">
        <button type="button" onClick={() => setPaused(true)} className="rounded-full bg-paper px-4 py-2 text-sm ring-1 ring-line">
          Pause account
        </button>
        <button type="button" onClick={() => setPaused(false)} className="rounded-full bg-paper px-4 py-2 text-sm ring-1 ring-line">
          Resume account
        </button>
        <button type="button" onClick={onExport} className="rounded-full bg-clay-deep px-4 py-2 text-sm font-semibold text-paper">
          Export my data
        </button>
      </section>
      {exportJson ? (
        <pre className="max-h-80 overflow-auto rounded-2xl bg-ink p-4 text-xs text-paper">{exportJson}</pre>
      ) : null}
      {staff ? (
        <section className="grid gap-4 rounded-2xl bg-paper p-5 ring-1 ring-line">
          <h2 className="font-serif text-2xl">Moderation</h2>
          <div className="grid gap-2">
            <h3 className="font-semibold">Reports</h3>
            {reports.length === 0 ? <p className="text-sm text-ink-soft">Queue empty.</p> : null}
            {reports.map((row) => (
              <div key={String(row.id)} className="flex flex-wrap items-center justify-between gap-2 rounded-xl bg-cream px-3 py-2 text-sm">
                <span>
                  {String(row.reported_name)} · {String(row.reason)} · {String(row.status)}
                </span>
                <span className="flex gap-2">
                  <button
                    type="button"
                    className="underline"
                    onClick={async () => {
                      const supabase = createClient();
                      if (!supabase) return;
                      await setReportStatus(supabase, String(row.id), "reviewing");
                      setReports(await loadModerationQueue(supabase));
                      setMessage("Marked reviewing");
                    }}
                  >
                    Reviewing
                  </button>
                  <button
                    type="button"
                    className="underline"
                    onClick={async () => {
                      const supabase = createClient();
                      if (!supabase) return;
                      await setReportStatus(supabase, String(row.id), "closed");
                      setReports(await loadModerationQueue(supabase));
                      setMessage("Closed");
                    }}
                  >
                    Close
                  </button>
                </span>
              </div>
            ))}
          </div>
          <div className="grid gap-2">
            <h3 className="font-semibold">Photo verify</h3>
            {verifies.length === 0 ? <p className="text-sm text-ink-soft">No pending checks.</p> : null}
            {verifies.map((row) => (
              <div key={String(row.user_id)} className="flex items-center justify-between rounded-xl bg-cream px-3 py-2 text-sm">
                <span>{String(row.display_name)}</span>
                <button
                  type="button"
                  className="underline"
                  onClick={async () => {
                    const supabase = createClient();
                    if (!supabase) return;
                    await approvePhotoVerify(supabase, String(row.user_id));
                    setVerifies(await loadPhotoVerifyQueue(supabase));
                    setMessage("Photo check approved.");
                  }}
                >
                  Approve
                </button>
              </div>
            ))}
          </div>
        </section>
      ) : null}
      {message ? <p className="text-sm text-clay-deep">{message}</p> : null}
    </div>
  );
}

type ActivityTab = "likes" | "views" | "favorites" | "mutual";

export function MatchesPanel() {
  const session = useMemberSession();
  const [tab, setTab] = useState<ActivityTab>("likes");
  const [likes, setLikes] = useState<ReceivedLike[]>([]);
  const [views, setViews] = useState<ReceivedLike[]>([]);
  const [favorites, setFavorites] = useState<ReceivedLike[]>([]);
  const [threads, setThreads] = useState<MatchThread[]>([]);
  const [note, setNote] = useState("Loading…");

  useEffect(() => {
    if (typeof window === "undefined") return;
    const next = new URLSearchParams(window.location.search).get("tab");
    if (next === "likes" || next === "views" || next === "favorites" || next === "mutual") setTab(next);
  }, []);

  useEffect(() => {
    if (!session.userId) {
      if (session.ready) setNote("Log in to see likes, views, favorites, and mutual matches.");
      return;
    }
    const supabase = createClient();
    if (!supabase) return;
    Promise.all([
      loadReceivedLikes(supabase, session.userId),
      loadProfileViewers(supabase, session.userId),
      loadFavoritePeople(supabase, session.userId),
      loadMatchThreads(supabase, session.userId),
    ]).then(([incoming, viewers, saved, matchThreads]) => {
      setLikes(incoming);
      setViews(viewers);
      setFavorites(saved);
      setThreads(matchThreads.filter((thread) => thread.mutual));
      setNote("");
    });
  }, [session.ready, session.userId]);

  async function onLikeBack(userId: string) {
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    await sendLike(supabase, session.userId, userId);
    const matchId = await openConversation(supabase, userId);
    if (matchId) window.location.href = `/app/messages?match=${matchId}`;
  }

  function selectTab(next: ActivityTab) {
    setTab(next);
    if (typeof window !== "undefined") {
      const url = new URL(window.location.href);
      url.searchParams.set("tab", next);
      window.history.replaceState({}, "", url.toString());
    }
  }

  const tabs: { id: ActivityTab; label: string; count: number }[] = [
    { id: "likes", label: "Liked you", count: likes.length },
    { id: "views", label: "Views", count: views.length },
    { id: "favorites", label: "Favorites", count: favorites.length },
    { id: "mutual", label: "Mutual", count: threads.length },
  ];

  return (
    <div className="grid gap-6">
      <SignedOutNote />
      {note ? <p className="text-sm text-ink-soft">{note}</p> : null}
      <div className="flex flex-wrap gap-2">
        {tabs.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => selectTab(item.id)}
            className={`rounded-full px-3.5 py-1.5 text-sm font-semibold ${
              tab === item.id ? "bg-clay text-paper" : "bg-paper text-ink ring-1 ring-line"
            }`}
          >
            {item.label} ({item.count})
          </button>
        ))}
      </div>

      {tab === "likes" ? (
        <section className="grid gap-3">
          {likes.length === 0 ? (
            <Empty title="No incoming likes yet" body="When someone likes you in the app or on web, they show here." />
          ) : (
            <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {likes.map((like) => (
                <li key={like.userId} className="overflow-hidden rounded-2xl bg-paper ring-1 ring-line">
                  <Link href={`/app/people/${like.userId}`}>
                    {like.photoUrl ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={like.photoUrl} alt="" className="h-40 w-full object-cover" />
                    ) : (
                      <div className="grid h-40 place-items-center bg-cream text-ink-soft">No photo</div>
                    )}
                  </Link>
                  <div className="p-4">
                    <Link href={`/app/people/${like.userId}`} className="font-semibold hover:underline">
                      {like.name}
                    </Link>
                    <p className="text-sm text-ink-soft">{like.city || "Location kept broad"}</p>
                    <button
                      type="button"
                      onClick={() => onLikeBack(like.userId)}
                      className="mt-3 rounded-full bg-clay px-4 py-2 text-sm font-semibold text-paper"
                    >
                      Like back
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>
      ) : null}

      {tab === "views" ? (
        <section className="grid gap-3">
          {views.length === 0 ? (
            <Empty title="No profile views yet" body="Members who open your profile appear here." />
          ) : (
            <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {views.map((viewer) => (
                <li key={viewer.userId}>
                  <Link
                    href={`/app/people/${viewer.userId}`}
                    className="flex items-center gap-3 rounded-2xl bg-paper p-4 ring-1 ring-line hover:bg-cream"
                  >
                    <div className="grid h-12 w-12 place-items-center rounded-full bg-cream text-ink-soft">👁</div>
                    <div className="min-w-0">
                      <p className="font-semibold">{viewer.name}</p>
                      <p className="truncate text-sm text-ink-soft">{viewer.city || "Location kept broad"}</p>
                    </div>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </section>
      ) : null}

      {tab === "favorites" ? (
        <section className="grid gap-3">
          {favorites.length === 0 ? (
            <Empty title="No favorites yet" body="Star someone from Home or a profile to keep them here privately." />
          ) : (
            <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {favorites.map((person) => (
                <li key={person.userId}>
                  <Link
                    href={`/app/people/${person.userId}`}
                    className="flex items-center gap-3 rounded-2xl bg-paper p-4 ring-1 ring-line hover:bg-cream"
                  >
                    <div className="h-12 w-12 overflow-hidden rounded-full bg-cream">
                      {person.photoUrl ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={person.photoUrl} alt="" className="h-full w-full object-cover" />
                      ) : null}
                    </div>
                    <div className="min-w-0">
                      <p className="font-semibold">{person.name}</p>
                      <p className="truncate text-sm text-ink-soft">{person.city || "Location kept broad"}</p>
                    </div>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </section>
      ) : null}

      {tab === "mutual" ? (
        <section className="grid gap-3">
          {threads.length === 0 ? (
            <Empty title="No mutual matches yet" body="A mutual like in the app or on web opens a conversation here." />
          ) : (
            <ul className="grid gap-3">
              {threads.map((thread) => (
                <li key={thread.matchId}>
                  <Link
                    href={`/app/messages?match=${thread.matchId}`}
                    className="flex items-center gap-3 rounded-2xl bg-paper p-4 ring-1 ring-line hover:bg-cream"
                  >
                    <div className="h-14 w-14 overflow-hidden rounded-full bg-cream">
                      {thread.photoUrl ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={thread.photoUrl} alt="" className="h-full w-full object-cover" />
                      ) : null}
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="font-semibold">{thread.name}</p>
                      <p className="truncate text-sm text-ink-soft">{thread.preview || "Say hello"}</p>
                    </div>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </section>
      ) : null}
    </div>
  );
}

type MessageFolder = "received" | "sent" | "favorites" | "all";

export function MessagesPanel() {
  const session = useMemberSession();
  const [threads, setThreads] = useState<MatchThread[]>([]);
  const [favoriteIds, setFavoriteIds] = useState<Set<string>>(new Set());
  const [folder, setFolder] = useState<MessageFolder>("all");
  const [activeMatch, setActiveMatch] = useState<string | null>(null);
  const [lines, setLines] = useState<ChatLine[]>([]);
  const [draft, setDraft] = useState("");
  const [note, setNote] = useState("Loading conversations…");

  useEffect(() => {
    if (typeof window === "undefined") return;
    const match = new URLSearchParams(window.location.search).get("match");
    if (match) setActiveMatch(match);
  }, []);

  useEffect(() => {
    if (!session.userId) {
      if (session.ready) setNote("Log in to open chats from the app.");
      return;
    }
    const supabase = createClient();
    if (!supabase) return;
    Promise.all([loadMatchThreads(supabase, session.userId), loadFavoritePeople(supabase, session.userId)]).then(
      ([list, saved]) => {
        setThreads(list);
        setFavoriteIds(new Set(saved.map((person) => person.userId)));
        setNote(list.length === 0 ? "No conversations yet." : "");
        if (!activeMatch && list[0]) setActiveMatch(list[0].matchId);
      },
    );
  }, [session.ready, session.userId, activeMatch]);

  const visibleThreads = threads.filter((thread) => {
    if (folder === "favorites") return favoriteIds.has(thread.otherUserId);
    if (folder === "received") return Boolean(thread.lastSenderId && thread.lastSenderId !== session.userId);
    if (folder === "sent") return Boolean(thread.lastSenderId && thread.lastSenderId === session.userId);
    return true;
  });

  useEffect(() => {
    if (!activeMatch) return;
    const supabase = createClient();
    if (!supabase) return;
    loadMessages(supabase, activeMatch).then(setLines);
    const channel = supabase
      .channel(`web-messages-${activeMatch}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "messages", filter: `match_id=eq.${activeMatch}` },
        (payload) => {
          const row = payload.new as Record<string, unknown>;
          const id = row.id;
          const senderId = row.sender_id;
          const body = row.body;
          if (typeof id !== "string" || typeof senderId !== "string" || typeof body !== "string") return;
          setLines((prev) => {
            if (prev.some((line) => line.id === id)) return prev;
            return [
              ...prev,
              {
                id,
                senderId,
                body,
                createdAt: String(row.created_at ?? new Date().toISOString()),
              },
            ];
          });
        },
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [activeMatch]);

  async function onSend(event: FormEvent) {
    event.preventDefault();
    if (!activeMatch || !draft.trim()) return;
    const supabase = createClient();
    if (!supabase) return;
    const line = await sendMessage(supabase, activeMatch, draft);
    if (line) {
      setLines((prev) => [...prev, line]);
      setDraft("");
    }
  }

  async function onVideo() {
    if (!activeMatch) return;
    const url = videoRoomUrlForMatch(activeMatch);
    const ok = window.confirm(
      "Start a video call? A join link will be posted in this chat, then a private Jitsi room opens outside Wendo.",
    );
    if (!ok) return;
    const supabase = createClient();
    if (!supabase) return;
    const line = await sendMessage(supabase, activeMatch, `Video call invite: ${url}`);
    if (line) setLines((prev) => [...prev, line]);
    window.open(url, "_blank", "noopener,noreferrer");
  }

  const active = threads.find((thread) => thread.matchId === activeMatch) ?? null;
  const folders: { id: MessageFolder; label: string }[] = [
    { id: "all", label: "All" },
    { id: "received", label: "Received" },
    { id: "sent", label: "Sent" },
    { id: "favorites", label: "Favorites" },
  ];

  return (
    <div className="grid gap-4">
      <SignedOutNote />
      <div className="flex flex-wrap gap-2">
        {folders.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => setFolder(item.id)}
            className={`rounded-full px-3.5 py-1.5 text-sm font-semibold ${
              folder === item.id ? "bg-clay text-paper" : "bg-paper text-ink ring-1 ring-line"
            }`}
          >
            {item.label}
          </button>
        ))}
      </div>
      <div className="grid gap-4 lg:grid-cols-[280px_1fr]">
      <aside className="rounded-2xl bg-paper ring-1 ring-line">
        <div className="border-b border-line px-4 py-3 font-semibold">Chats</div>
        {note ? <p className="px-4 py-3 text-sm text-ink-soft">{note}</p> : null}
        <ul className="divide-y divide-line">
          {visibleThreads.map((thread) => (
            <li key={thread.matchId}>
              <button
                type="button"
                onClick={() => {
                  setActiveMatch(thread.matchId);
                  const url = new URL(window.location.href);
                  url.searchParams.set("match", thread.matchId);
                  window.history.replaceState({}, "", url.toString());
                }}
                className={`flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-cream ${
                  activeMatch === thread.matchId ? "bg-cream" : ""
                }`}
              >
                <div className="h-11 w-11 overflow-hidden rounded-full bg-cream">
                  {thread.photoUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={thread.photoUrl} alt="" className="h-full w-full object-cover" />
                  ) : null}
                </div>
                <div className="min-w-0">
                  <p className="truncate font-medium">{thread.name}</p>
                  <p className="truncate text-xs text-ink-soft">{thread.preview || "No messages yet"}</p>
                </div>
              </button>
            </li>
          ))}
        </ul>
        {visibleThreads.length === 0 && !note ? (
          <p className="px-4 py-3 text-sm text-ink-soft">No chats in this folder.</p>
        ) : null}
      </aside>

      <section className="flex min-h-[420px] flex-col rounded-2xl bg-paper ring-1 ring-line">
        <div className="flex items-center justify-between gap-3 border-b border-line px-4 py-3">
          <p className="font-semibold">{active ? active.name : "Select a conversation"}</p>
          {activeMatch ? (
            <button
              type="button"
              onClick={onVideo}
              className="rounded-full bg-cream px-3 py-1.5 text-sm font-semibold text-clay-deep ring-1 ring-line"
            >
              Video call
            </button>
          ) : null}
        </div>
        <div className="flex-1 space-y-2 overflow-y-auto px-4 py-4">
          {lines.map((line) => {
            const mine = line.senderId === session.userId;
            const isVideoInvite = line.body.startsWith("Video call invite:");
            const link = isVideoInvite ? line.body.replace(/^Video call invite:\s*/, "").trim() : null;
            return (
              <div key={line.id} className={`flex ${mine ? "justify-end" : "justify-start"}`}>
                <div className={`max-w-[80%] rounded-2xl px-3 py-2 text-sm ${mine ? "bg-clay text-paper" : "bg-cream text-ink"}`}>
                  {link ? (
                    <a href={link} target="_blank" rel="noreferrer" className="underline">
                      Join video call
                    </a>
                  ) : (
                    <p>{line.body}</p>
                  )}
                </div>
              </div>
            );
          })}
        </div>
        {activeMatch ? (
          <form onSubmit={onSend} className="flex gap-2 border-t border-line p-3">
            <input
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              placeholder="Write a message"
              className="flex-1 rounded-full border border-line bg-cream px-4 py-2 text-sm"
            />
            <button type="submit" className="rounded-full bg-clay-deep px-4 py-2 text-sm font-semibold text-paper">
              Send
            </button>
          </form>
        ) : null}
      </section>
      </div>
    </div>
  );
}

function Empty({ title, body }: { title: string; body: string }) {
  return (
    <div className="rounded-3xl border border-dashed border-gold bg-paper px-6 py-10">
      <h2 className="font-serif text-3xl">{title}</h2>
      <p className="mt-2 max-w-xl text-sm leading-6 text-ink-soft">{body}</p>
    </div>
  );
}

function TextField({
  label,
  name,
  type = "text",
  defaultValue,
  required,
  placeholder,
}: {
  label: string;
  name: string;
  type?: string;
  defaultValue?: string;
  required?: boolean;
  placeholder?: string;
}) {
  return (
    <label className="grid gap-1 text-sm">
      <span className="font-semibold">{label}</span>
      <input
        name={name}
        type={type}
        defaultValue={defaultValue}
        required={required}
        placeholder={placeholder}
        className="rounded-xl border border-line bg-paper px-3 py-2"
      />
    </label>
  );
}

function splitList(value: FormDataEntryValue | null): string[] {
  return String(value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

type JoinDraft = {
  displayName?: string;
  dateOfBirth?: string;
  city?: string;
  relationshipIntent?: string;
};
