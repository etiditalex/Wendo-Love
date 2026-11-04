import type { SupabaseClient } from "@supabase/supabase-js";
import { product } from "@/lib/domain";

export type DiscoveryCard = {
  user_id: string;
  display_name: string;
  city: string | null;
  bio?: string | null;
  relationship_intent: string;
  relationship_intents?: string[] | null;
  age_years?: number | null;
  photo_path?: string | null;
  photoUrl?: string | null;
  is_online?: boolean | null;
  last_seen_at?: string | null;
  photo_verified?: boolean | null;
  age_preference_min?: number | null;
  age_preference_max?: number | null;
  gender?: string | null;
  seeking_genders?: string[] | null;
  photo_count?: number;
  like_count?: number;
  body_type?: string | null;
  education?: string | null;
  photo_verified_at?: string | null;
  created_at?: string | null;
};

export type HomeBoard = {
  name: string;
  completion: number;
  criteriaComplete: boolean;
  plus: boolean;
  messages: number;
  interests: number;
  views: number;
  favorites: number;
  city: string | null;
  intent: string;
  mutualIds: string[];
  reverseIds: string[];
  outgoingLikeIds: string[];
};

export type InboxCounts = {
  likes: number;
  messages: number;
};

export type MatchThread = {
  matchId: string;
  otherUserId: string;
  name: string;
  city: string;
  preview: string;
  age?: number | null;
  lastAt?: string | null;
  lastSenderId?: string | null;
  online: boolean;
  mutual: boolean;
  photoUrl?: string | null;
};

export type ChatLine = {
  id: string;
  senderId: string;
  body: string;
  createdAt: string;
};

export type ReceivedLike = {
  userId: string;
  name: string;
  city: string;
  photoUrl?: string | null;
};

export type OwnProfile = {
  display_name: string;
  city: string | null;
  bio: string | null;
  relationship_intent: string;
  languages: string[];
  interests: string[];
  family_goals: string | null;
  children_preference: string | null;
  communication_boundaries: string | null;
  age_preference_min: number;
  age_preference_max: number;
  gender?: string | null;
  seeking_genders?: string[];
  education?: string | null;
  body_type?: string | null;
  date_of_birth: string | null;
  blur_until_mutual?: boolean;
};

export function intentLabel(id: string | null | undefined): string {
  if (!id) return "Open to connection";
  return product.relationshipIntents.find((intent) => intent.id === id)?.label ?? id;
}

export function genderLabel(id: string | null | undefined): string {
  if (!id) return "";
  return product.genders.find((gender) => gender.id === id)?.label ?? id;
}

export function seekingLine(card: Pick<DiscoveryCard, "seeking_genders" | "age_preference_min" | "age_preference_max" | "relationship_intent">): string {
  const people = (card.seeking_genders ?? []).map((id) => genderLabel(id)).filter(Boolean);
  const ages =
    card.age_preference_min && card.age_preference_max
      ? `${card.age_preference_min}–${card.age_preference_max}`
      : "";
  if (people.length > 0) return `${people.join(", ")}${ages ? `, ${ages}` : ""}`;
  const intent = intentLabel(card.relationship_intent);
  return ages ? `${intent}, ${ages}` : intent;
}

/** Shared optional video room (Jitsi). Same match id → same room for both people. */
export function videoRoomUrlForMatch(matchId: string): string {
  const cleaned = matchId.replace(/[^a-zA-Z0-9-]/g, "");
  const room = cleaned ? `wendo-${cleaned}` : "wendo-room";
  return `https://meet.jit.si/${room}`;
}

export function formatLastSeen(isOnline?: boolean | null, lastSeenAt?: string | null): string {
  if (isOnline) return "I'm Online";
  if (!lastSeenAt) return "Recently active";
  const then = new Date(lastSeenAt).getTime();
  if (Number.isNaN(then)) return "Recently active";
  const mins = Math.max(0, Math.round((Date.now() - then) / 60000));
  if (mins < 60) return mins <= 1 ? "1 minute ago" : `${mins} minutes ago`;
  const hours = Math.round(mins / 60);
  if (hours < 24) return hours === 1 ? "1 hour ago" : `${hours} hours ago`;
  const days = Math.round(hours / 24);
  return days === 1 ? "1 day ago" : `${days} days ago`;
}

export function isNewMember(createdAt?: string | null): boolean {
  if (!createdAt) return false;
  const then = new Date(createdAt).getTime();
  if (Number.isNaN(then)) return false;
  return Date.now() - then < 1000 * 60 * 60 * 24 * 14;
}

async function signedPhoto(client: SupabaseClient, path: string | null | undefined): Promise<string | null> {
  if (!path) return null;
  const { data } = await client.storage.from("profile-photos").createSignedUrl(path, 60 * 60);
  return data?.signedUrl ?? null;
}

export async function loadDiscoveryCards(client: SupabaseClient, userId: string): Promise<DiscoveryCard[]> {
  const { data, error } = await client.rpc("discovery_cards");
  const fromRpc = error ? [] : ((data as DiscoveryCard[]) ?? []);

  const profileColumns =
    "user_id, display_name, city, bio, relationship_intent, relationship_intents, age_preference_min, age_preference_max, gender, seeking_genders, body_type, education, is_online, last_seen_at, created_at, photo_verified_at";
  const baseColumns =
    "user_id, display_name, city, bio, relationship_intent, relationship_intents, age_preference_min, age_preference_max, is_online, last_seen_at, created_at, photo_verified_at";
  const firstProfiles = await client
    .from("profiles")
    .select(profileColumns)
    .neq("user_id", userId)
    .eq("onboarding_completed", true)
    .eq("account_paused", false);
  const profiles = firstProfiles.error
    ? (
        await client
          .from("profiles")
          .select(baseColumns)
          .neq("user_id", userId)
          .eq("onboarding_completed", true)
          .eq("account_paused", false)
      ).data
    : firstProfiles.data;

  const byId = new Map(fromRpc.map((card) => [card.user_id, card]));
  const rows = ((profiles as Array<Record<string, unknown>> | null) ?? []).map((profile) => {
    const id = String(profile.user_id);
    const rpc = byId.get(id);
    return {
      ...rpc,
      user_id: id,
      display_name: String(rpc?.display_name ?? profile.display_name ?? "Member"),
      city: (rpc?.city ?? profile.city ?? null) as string | null,
      bio: (rpc?.bio ?? profile.bio ?? null) as string | null,
      relationship_intent: String(rpc?.relationship_intent ?? profile.relationship_intent ?? "unsure"),
      relationship_intents: (rpc?.relationship_intents ?? profile.relationship_intents ?? null) as string[] | null,
      age_years: rpc?.age_years ?? null,
      photo_path: rpc?.photo_path ?? null,
      is_online: Boolean(rpc?.is_online ?? profile.is_online),
      last_seen_at: (rpc?.last_seen_at ?? profile.last_seen_at ?? null) as string | null,
      photo_verified: Boolean(rpc?.photo_verified ?? profile.photo_verified_at),
      age_preference_min: (profile.age_preference_min as number | null) ?? null,
      age_preference_max: (profile.age_preference_max as number | null) ?? null,
      gender: (profile.gender as string | null) ?? null,
      seeking_genders: Array.isArray(profile.seeking_genders) ? profile.seeking_genders.map(String) : [],
      body_type: (profile.body_type as string | null) ?? null,
      education: (profile.education as string | null) ?? null,
      photo_verified_at: (profile.photo_verified_at as string | null) ?? null,
      created_at: (profile.created_at as string | null) ?? null,
    } satisfies DiscoveryCard;
  });

  const list = rows.length > 0 ? rows : fromRpc;
  const { data: stats } = await client.rpc("discovery_card_stats");
  const statById = new Map(
    ((stats as Array<{ user_id: string; photo_count: number; like_count: number }> | null) ?? []).map((row) => [
      row.user_id,
      row,
    ]),
  );
  return Promise.all(
    list.map(async (card) => {
      const stat = statById.get(card.user_id);
      return {
        ...card,
        photo_count: stat?.photo_count ?? (card.photo_path ? 1 : 0),
        like_count: stat?.like_count ?? 0,
        photoUrl: await signedPhoto(client, card.photo_path),
      };
    }),
  );
}

export async function loadHomeBoard(client: SupabaseClient, userId: string): Promise<HomeBoard> {
  const profileSelect =
    "display_name, city, bio, gender, seeking_genders, relationship_intent, premium_until, age_preference_min, age_preference_max";
  let profile: Record<string, unknown> | null = null;
  const first = await client.from("profiles").select(profileSelect).eq("user_id", userId).maybeSingle();
  if (first.error) {
    const fallback = await client
      .from("profiles")
      .select("display_name, city, bio, relationship_intent, premium_until, age_preference_min, age_preference_max")
      .eq("user_id", userId)
      .maybeSingle();
    profile = (fallback.data as Record<string, unknown> | null) ?? null;
  } else {
    profile = (first.data as Record<string, unknown> | null) ?? null;
  }

  const [{ count: photos }, { data: incoming }, { data: outgoing }, { data: matches }, { count: favorites }, { count: views }, inbox] =
    await Promise.all([
      client.from("profile_photos").select("id", { count: "exact", head: true }).eq("user_id", userId),
      client.from("likes").select("from_user").eq("to_user", userId),
      client.from("likes").select("to_user").eq("from_user", userId),
      client.from("matches").select("user_a, user_b").or(`user_a.eq.${userId},user_b.eq.${userId}`).is("unmatched_at", null),
      client.from("favorites").select("favorite_id", { count: "exact", head: true }).eq("owner_id", userId),
      client.from("profile_views").select("viewer_id", { count: "exact", head: true }).eq("viewed_id", userId),
      loadInboxCounts(client, userId),
    ]);

  const seeking = Array.isArray(profile?.seeking_genders) ? profile.seeking_genders.map(String) : [];
  const checks = [
    Boolean(profile?.display_name),
    Boolean(profile?.city),
    Boolean(profile?.bio),
    Boolean(profile?.gender),
    seeking.length > 0,
    (photos ?? 0) > 0,
  ];
  const completion = Math.round((checks.filter(Boolean).length / checks.length) * 100);
  const criteriaComplete = Boolean(profile?.city) && Boolean(profile?.gender) && seeking.length > 0 && (photos ?? 0) > 0;
  const until = profile?.premium_until ? new Date(String(profile.premium_until)).getTime() : 0;
  const mutualIds = ((matches as Array<{ user_a: string; user_b: string }> | null) ?? []).map((row) =>
    row.user_a === userId ? row.user_b : row.user_a,
  );
  const mutual = new Set(mutualIds);
  const outgoingLikeIds = ((outgoing as Array<{ to_user: string }> | null) ?? []).map((row) => row.to_user);
  const reverseIds = ((incoming as Array<{ from_user: string }> | null) ?? [])
    .map((row) => row.from_user)
    .filter((id) => !mutual.has(id));

  return {
    name: String(profile?.display_name ?? "there").split(" ")[0] || "there",
    completion,
    criteriaComplete,
    plus: until > Date.now(),
    messages: inbox.messages,
    interests: ((incoming as Array<unknown> | null) ?? []).length,
    views: views ?? 0,
    favorites: favorites ?? 0,
    city: (profile?.city as string | null) ?? null,
    intent: String(profile?.relationship_intent ?? "unsure"),
    mutualIds,
    reverseIds,
    outgoingLikeIds,
  };
}

export async function loadInboxCounts(client: SupabaseClient, userId: string): Promise<InboxCounts> {
  const [{ count: likes }, { data: matches }] = await Promise.all([
    client.from("likes").select("from_user", { count: "exact", head: true }).eq("to_user", userId),
    client.from("matches").select("id").or(`user_a.eq.${userId},user_b.eq.${userId}`).is("unmatched_at", null),
  ]);

  let messages = 0;
  const matchIds = ((matches as Array<{ id: string }> | null) ?? []).map((row) => row.id);
  if (matchIds.length > 0) {
    const { count } = await client
      .from("messages")
      .select("id", { count: "exact", head: true })
      .in("match_id", matchIds)
      .neq("sender_id", userId);
    messages = count ?? 0;
  }

  return { likes: likes ?? 0, messages };
}

export async function loadOwnAvatar(client: SupabaseClient, userId: string): Promise<string | null> {
  const { data } = await client
    .from("profile_photos")
    .select("storage_path")
    .eq("user_id", userId)
    .order("sort_order", { ascending: true })
    .limit(1)
    .maybeSingle();
  return signedPhoto(client, data?.storage_path as string | undefined);
}

export async function sendLike(client: SupabaseClient, fromUser: string, toUser: string): Promise<string | null> {
  const { error } = await client.from("likes").insert({ from_user: fromUser, to_user: toUser });
  if (error && !/duplicate|unique/i.test(error.message)) return error.message;
  return null;
}

export async function markPresence(client: SupabaseClient, online: boolean): Promise<void> {
  const user = (await client.auth.getUser()).data.user;
  if (!user) return;
  await client
    .from("profiles")
    .update({
      is_online: online,
      last_seen_at: new Date().toISOString(),
      presence: online ? "online" : "busy",
    })
    .eq("user_id", user.id);
}

export async function openConversation(client: SupabaseClient, otherUserId: string): Promise<string | null> {
  const { data, error } = await client.rpc("open_conversation", { other_user: otherUserId });
  if (error) return null;
  return typeof data === "string" ? data : null;
}

export async function loadMatchThreads(client: SupabaseClient, userId: string): Promise<MatchThread[]> {
  const { data: matches } = await client
    .from("matches")
    .select("id, user_a, user_b, is_mutual, unmatched_at");
  const rows = (matches as Array<Record<string, unknown>> | null) ?? [];
  const others = new Map<string, string>();
  const mutualIds = new Set<string>();
  for (const row of rows) {
    const id = String(row.id ?? "");
    if (!id || row.unmatched_at) continue;
    if (row.user_a === userId && typeof row.user_b === "string") others.set(id, row.user_b);
    if (row.user_b === userId && typeof row.user_a === "string") others.set(id, row.user_a);
    if (row.is_mutual === true) mutualIds.add(id);
  }
  if (others.size === 0) return [];

  const otherIds = [...new Set(others.values())];
  const { data: profiles } = await client
    .from("profiles")
    .select("user_id, display_name, city, is_online, last_seen_at")
    .in("user_id", otherIds);
  const names = new Map(
    ((profiles as Array<Record<string, unknown>> | null) ?? []).map((row) => [String(row.user_id), row]),
  );

  const matchIds = [...others.keys()];
  const { data: messages } = await client
    .from("messages")
    .select("match_id, sender_id, body, created_at")
    .in("match_id", matchIds)
    .order("created_at");
  const preview = new Map<string, string>();
  const lastAt = new Map<string, string>();
  const lastSender = new Map<string, string>();
  for (const row of (messages as Array<Record<string, unknown>> | null) ?? []) {
    const matchId = String(row.match_id ?? "");
    if (!matchId || typeof row.body !== "string") continue;
    preview.set(matchId, row.body);
    lastAt.set(matchId, String(row.created_at ?? ""));
    if (typeof row.sender_id === "string") lastSender.set(matchId, row.sender_id);
  }

  const { data: photos } = await client
    .from("profile_photos")
    .select("user_id, storage_path, sort_order")
    .in("user_id", otherIds)
    .order("sort_order", { ascending: true });
  const photoPath = new Map<string, string>();
  for (const row of (photos as Array<Record<string, unknown>> | null) ?? []) {
    const id = String(row.user_id ?? "");
    if (!id || photoPath.has(id) || typeof row.storage_path !== "string") continue;
    photoPath.set(id, row.storage_path);
  }

  const threads = await Promise.all(
    [...others.entries()].map(async ([matchId, otherUserId]) => {
      const profile = names.get(otherUserId);
      return {
        matchId,
        otherUserId,
        name: String(profile?.display_name || "Member"),
        city: String(profile?.city || ""),
        preview: preview.get(matchId) ?? "",
        lastAt: lastAt.get(matchId) ?? null,
        lastSenderId: lastSender.get(matchId) ?? null,
        online: profile?.is_online === true,
        mutual: mutualIds.has(matchId),
        photoUrl: await signedPhoto(client, photoPath.get(otherUserId)),
      } satisfies MatchThread;
    }),
  );

  threads.sort((a, b) => String(b.lastAt ?? "").localeCompare(String(a.lastAt ?? "")));
  return threads;
}

export async function loadMessages(client: SupabaseClient, matchId: string): Promise<ChatLine[]> {
  const { data } = await client
    .from("messages")
    .select("id, sender_id, body, created_at")
    .eq("match_id", matchId)
    .order("created_at");
  return ((data as Array<Record<string, unknown>> | null) ?? []).flatMap((row) => {
    if (typeof row.id !== "string" || typeof row.sender_id !== "string" || typeof row.body !== "string") return [];
    return [
      {
        id: row.id,
        senderId: row.sender_id,
        body: row.body,
        createdAt: String(row.created_at ?? new Date().toISOString()),
      },
    ];
  });
}

export async function sendMessage(client: SupabaseClient, matchId: string, body: string): Promise<ChatLine | null> {
  const user = (await client.auth.getUser()).data.user;
  const text = body.trim();
  if (!user || !text) return null;
  const { data, error } = await client
    .from("messages")
    .insert({ match_id: matchId, sender_id: user.id, body: text })
    .select("id, sender_id, body, created_at")
    .single();
  if (error || !data) return null;
  return {
    id: String(data.id),
    senderId: String(data.sender_id),
    body: String(data.body),
    createdAt: String(data.created_at),
  };
}

export async function loadReceivedLikes(client: SupabaseClient, userId: string): Promise<ReceivedLike[]> {
  const { data: likes } = await client.from("likes").select("from_user").eq("to_user", userId);
  const ids = ((likes as Array<{ from_user: string }> | null) ?? []).map((row) => row.from_user);
  if (ids.length === 0) return [];
  const { data: profiles } = await client.from("profiles").select("user_id, display_name, city").in("user_id", ids);
  const { data: photos } = await client
    .from("profile_photos")
    .select("user_id, storage_path, sort_order")
    .in("user_id", ids)
    .order("sort_order", { ascending: true });
  const photoPath = new Map<string, string>();
  for (const row of (photos as Array<Record<string, unknown>> | null) ?? []) {
    const id = String(row.user_id ?? "");
    if (!id || photoPath.has(id) || typeof row.storage_path !== "string") continue;
    photoPath.set(id, row.storage_path);
  }
  return Promise.all(
    ((profiles as Array<Record<string, unknown>> | null) ?? []).map(async (row) => {
      const id = String(row.user_id);
      return {
        userId: id,
        name: String(row.display_name || "Member"),
        city: String(row.city || ""),
        photoUrl: await signedPhoto(client, photoPath.get(id)),
      } satisfies ReceivedLike;
    }),
  );
}

export async function loadOwnProfile(client: SupabaseClient, userId: string): Promise<OwnProfile | null> {
  const full =
    "display_name, city, bio, relationship_intent, languages, interests, family_goals, children_preference, communication_boundaries, age_preference_min, age_preference_max, gender, seeking_genders, education, body_type, blur_until_mutual";
  const basic =
    "display_name, city, bio, relationship_intent, languages, interests, family_goals, children_preference, communication_boundaries, age_preference_min, age_preference_max, blur_until_mutual";
  const [{ data: identity }, profileResult] = await Promise.all([
    client.from("private_identity").select("date_of_birth").eq("user_id", userId).maybeSingle(),
    client.from("profiles").select(full).eq("user_id", userId).maybeSingle(),
  ]);
  const profile = (profileResult.error
    ? (await client.from("profiles").select(basic).eq("user_id", userId).maybeSingle()).data
    : profileResult.data) as Record<string, unknown> | null;
  if (!profile) return null;
  return {
    display_name: String(profile.display_name ?? ""),
    city: (profile.city as string | null) ?? null,
    bio: (profile.bio as string | null) ?? null,
    relationship_intent: String(profile.relationship_intent ?? "unsure"),
    languages: Array.isArray(profile.languages) ? profile.languages.map(String) : [],
    interests: Array.isArray(profile.interests) ? profile.interests.map(String) : [],
    family_goals: (profile.family_goals as string | null) ?? null,
    children_preference: (profile.children_preference as string | null) ?? null,
    communication_boundaries: (profile.communication_boundaries as string | null) ?? null,
    age_preference_min: Number(profile.age_preference_min ?? 18),
    age_preference_max: Number(profile.age_preference_max ?? 80),
    gender: (profile.gender as string | null) ?? null,
    seeking_genders: Array.isArray(profile.seeking_genders) ? profile.seeking_genders.map(String) : [],
    education: (profile.education as string | null) ?? null,
    body_type: (profile.body_type as string | null) ?? null,
    date_of_birth: (identity?.date_of_birth as string | null) ?? null,
    blur_until_mutual: Boolean(profile.blur_until_mutual),
  };
}

export async function uploadProfilePhoto(
  client: SupabaseClient,
  userId: string,
  file: File,
): Promise<string | null> {
  const path = `${userId}/0.jpg`;
  const { error: uploadError } = await client.storage.from("profile-photos").upload(path, file, {
    contentType: file.type || "image/jpeg",
    upsert: true,
  });
  if (uploadError) return uploadError.message;
  const { data: existing } = await client
    .from("profile_photos")
    .select("id")
    .eq("user_id", userId)
    .eq("sort_order", 0)
    .limit(1);
  if (!existing || existing.length === 0) {
    const { error } = await client.from("profile_photos").insert({
      user_id: userId,
      storage_path: path,
      sort_order: 0,
    });
    if (error) return error.message;
  } else {
    const { error } = await client.from("profile_photos").update({ storage_path: path }).eq("id", existing[0].id);
    if (error) return error.message;
  }
  return null;
}

export async function blockPerson(client: SupabaseClient, userId: string, otherUserId: string): Promise<string | null> {
  const { error } = await client.from("blocks").insert({ blocker_id: userId, blocked_id: otherUserId });
  if (error && !/duplicate|unique/i.test(error.message)) return error.message;
  return null;
}

export async function reportPerson(
  client: SupabaseClient,
  userId: string,
  otherUserId: string,
  reason: string,
  details = "",
): Promise<string | null> {
  const { error } = await client.from("reports").insert({
    reporter_id: userId,
    reported_user_id: otherUserId,
    reason,
    ...(details.trim() ? { details: details.trim() } : {}),
  });
  if (error) return error.message;
  return null;
}

export async function passPerson(client: SupabaseClient, userId: string, otherUserId: string): Promise<string | null> {
  const { error } = await client.from("passes").upsert({ from_user: userId, to_user: otherUserId });
  if (error) return error.message;
  return null;
}

export async function addFavorite(client: SupabaseClient, userId: string, otherUserId: string): Promise<string | null> {
  const { error } = await client.from("favorites").insert({ owner_id: userId, favorite_id: otherUserId });
  if (error && !/duplicate|unique/i.test(error.message)) return error.message;
  return null;
}

export async function loadFavoritePeople(client: SupabaseClient, userId: string): Promise<ReceivedLike[]> {
  const { data: rows } = await client.from("favorites").select("favorite_id").eq("owner_id", userId);
  const ids = ((rows as Array<{ favorite_id: string }> | null) ?? []).map((row) => row.favorite_id);
  if (ids.length === 0) return [];
  const { data: profiles } = await client.from("profiles").select("user_id, display_name, city").in("user_id", ids);
  const { data: photos } = await client
    .from("profile_photos")
    .select("user_id, storage_path, sort_order")
    .in("user_id", ids)
    .order("sort_order", { ascending: true });
  const photoPath = new Map<string, string>();
  for (const row of (photos as Array<Record<string, unknown>> | null) ?? []) {
    const id = String(row.user_id ?? "");
    if (!id || photoPath.has(id) || typeof row.storage_path !== "string") continue;
    photoPath.set(id, row.storage_path);
  }
  return Promise.all(
    ((profiles as Array<Record<string, unknown>> | null) ?? []).map(async (row) => {
      const id = String(row.user_id);
      return {
        userId: id,
        name: String(row.display_name || "Member"),
        city: String(row.city || ""),
        photoUrl: await signedPhoto(client, photoPath.get(id)),
      } satisfies ReceivedLike;
    }),
  );
}

export async function loadProfileViewers(client: SupabaseClient, userId: string): Promise<ReceivedLike[]> {
  const { data: rows } = await client.from("profile_views").select("viewer_id").eq("viewed_id", userId);
  const ids = ((rows as Array<{ viewer_id: string }> | null) ?? []).map((row) => row.viewer_id);
  if (ids.length === 0) return [];
  const { data: profiles } = await client.from("profiles").select("user_id, display_name, city").in("user_id", ids);
  return ((profiles as Array<Record<string, unknown>> | null) ?? []).map((row) => ({
    userId: String(row.user_id),
    name: String(row.display_name || "Member"),
    city: String(row.city || ""),
  }));
}

export async function recordProfileView(client: SupabaseClient, otherUserId: string): Promise<void> {
  try {
    await client.rpc("record_profile_view", { other_user: otherUserId });
  } catch {
    /* optional */
  }
}

export async function exportOwnAccount(client: SupabaseClient): Promise<Record<string, unknown> | null> {
  const { data, error } = await client.rpc("export_own_account");
  if (error || !data || typeof data !== "object") return null;
  return data as Record<string, unknown>;
}

export async function isStaffMember(client: SupabaseClient, userId: string): Promise<boolean> {
  const { data } = await client.from("staff_roles").select("role").eq("user_id", userId).maybeSingle();
  return Boolean(data);
}

export async function loadModerationQueue(client: SupabaseClient): Promise<Array<Record<string, unknown>>> {
  const { data, error } = await client.rpc("moderation_queue");
  if (error || !Array.isArray(data)) return [];
  return data as Array<Record<string, unknown>>;
}

export async function loadPhotoVerifyQueue(client: SupabaseClient): Promise<Array<Record<string, unknown>>> {
  const { data, error } = await client.rpc("photo_verify_queue");
  if (error || !Array.isArray(data)) return [];
  return data as Array<Record<string, unknown>>;
}

export async function setReportStatus(client: SupabaseClient, reportId: string, status: string): Promise<string | null> {
  const { error } = await client.rpc("set_report_status", { report_id: reportId, next_status: status });
  return error?.message ?? null;
}

export async function approvePhotoVerify(client: SupabaseClient, userId: string): Promise<string | null> {
  const { error } = await client.rpc("approve_photo_verify", { target_user: userId });
  return error?.message ?? null;
}

export async function loadPartnerResources(client: SupabaseClient): Promise<Array<Record<string, unknown>>> {
  const { data, error } = await client
    .from("partner_resources")
    .select("id, kind, title, summary, url, region, sort_order")
    .eq("active", true)
    .order("sort_order");
  if (error || !data) return [];
  return data as Array<Record<string, unknown>>;
}

export async function saveTrustedContact(
  client: SupabaseClient,
  userId: string,
  name: string,
  phone: string,
): Promise<string | null> {
  const { error } = await client.from("trusted_contacts").insert({
    user_id: userId,
    display_name: name.trim(),
    phone: phone.trim(),
  });
  return error?.message ?? null;
}

export async function loadTrustedContacts(client: SupabaseClient, userId: string): Promise<Array<Record<string, unknown>>> {
  const { data, error } = await client
    .from("trusted_contacts")
    .select("id, display_name, phone")
    .eq("user_id", userId)
    .order("created_at");
  if (error || !data) return [];
  return data as Array<Record<string, unknown>>;
}

export async function saveMeetingCheckin(
  client: SupabaseClient,
  userId: string,
  placeNote: string,
): Promise<string | null> {
  const { error } = await client.from("meeting_checkins").insert({
    user_id: userId,
    place_note: placeNote.trim() || null,
    planned_at: new Date().toISOString(),
    status: "started",
  });
  return error?.message ?? null;
}

export async function loadMeetingCheckins(client: SupabaseClient, userId: string): Promise<Array<Record<string, unknown>>> {
  const { data, error } = await client
    .from("meeting_checkins")
    .select("id, place_note, status, created_at")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });
  if (error || !data) return [];
  return data as Array<Record<string, unknown>>;
}

export async function updateMeetingCheckinStatus(
  client: SupabaseClient,
  userId: string,
  id: string,
  status: string,
): Promise<string | null> {
  const { error } = await client
    .from("meeting_checkins")
    .update({ status, updated_at: new Date().toISOString() })
    .eq("id", id)
    .eq("user_id", userId);
  return error?.message ?? null;
}

export async function registerPremiumInterest(client: SupabaseClient, userId: string): Promise<string | null> {
  const { error } = await client.from("premium_interest").upsert({
    user_id: userId,
    plan: "wendo_plus",
    updated_at: new Date().toISOString(),
  });
  return error?.message ?? null;
}

export async function saveBlurUntilMutual(client: SupabaseClient, userId: string, value: boolean): Promise<string | null> {
  const { error } = await client.from("profiles").update({ blur_until_mutual: value }).eq("user_id", userId);
  return error?.message ?? null;
}
