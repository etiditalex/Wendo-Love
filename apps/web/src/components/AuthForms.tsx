"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { consentVersion, isAdult, product } from "@/lib/domain";
import { createClient } from "@/lib/supabase/client";

const joinDraftKey = "upendo.joinDraft";

export function JoinForm() {
  const router = useRouter();
  const [message, setMessage] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage(null);
    const form = new FormData(event.currentTarget);
    const dateOfBirth = String(form.get("dateOfBirth") ?? "");
    const terms = form.get("terms") === "on";
    const privacy = form.get("privacy") === "on";
    const rules = form.get("rules") === "on";

    if (!isAdult(dateOfBirth)) {
      setMessage("Wendo is for adults 18 and over.");
      return;
    }
    if (!terms || !privacy || !rules) {
      setMessage("Accept the terms, privacy notice, and community rules to continue.");
      return;
    }

    const draft = {
      displayName: String(form.get("displayName") ?? ""),
      dateOfBirth,
      city: String(form.get("city") ?? ""),
      relationshipIntent: String(form.get("relationshipIntent") ?? "unsure"),
      consentVersion,
    };
    window.sessionStorage.setItem(joinDraftKey, JSON.stringify(draft));

    const supabase = createClient();
    if (!supabase) {
      setMessage("Account creation is ready in the app. Add the Supabase URL and anon key in apps/web/.env.local, then submit again. Your date of birth stays in this browser until then and is not sent to a server.");
      return;
    }

    setPending(true);
    const email = String(form.get("email") ?? "");
    const password = String(form.get("password") ?? "");
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`,
        data: { display_name: draft.displayName },
      },
    });
    setPending(false);
    if (error) {
      setMessage(error.message);
      return;
    }
    router.push("/app/profile");
  }

  return (
    <form onSubmit={onSubmit} className="grid gap-4">
      <Field label="Email" name="email" type="email" required />
      <Field label="Password" name="password" type="password" required minLength={8} />
      <Field label="Display name or pseudonym" name="displayName" required minLength={2} maxLength={40} />
      <Field label="Date of birth" name="dateOfBirth" type="date" required />
      <p className="text-sm text-ink-soft">
        We use this only to confirm you are 18 or over. It is stored later in a private identity
        record, separate from your public profile, and it is not placed in the login token.
      </p>
      <Field label="City or broad area" name="city" placeholder="Nairobi" />
      <label className="grid gap-1 text-sm">
        <span className="font-semibold">Relationship intent</span>
        <select name="relationshipIntent" className="rounded-xl border border-line bg-paper px-3 py-2" defaultValue="marriage">
          {product.relationshipIntents.map((intent) => (
            <option key={intent.id} value={intent.id}>
              {intent.label}
            </option>
          ))}
        </select>
      </label>
      <Check name="terms" label="I accept the terms of use." />
      <Check name="privacy" label="I accept the privacy notice." />
      <Check name="rules" label="I accept the community rules." />
      <p className="rounded-2xl bg-cream px-4 py-3 text-sm leading-6 text-ink-soft">
        HIV status is not part of creating an account. You can leave it unset, and it is never
        shown on your profile unless you later choose to share it with a mutual match.
      </p>
      {message ? <p className="text-sm text-clay-deep">{message}</p> : null}
      <button
        type="submit"
        disabled={pending}
        className="rounded-full bg-clay px-5 py-3 font-semibold text-paper hover:bg-clay-deep disabled:opacity-60"
      >
        {pending ? "Creating account…" : "Create account"}
      </button>
    </form>
  );
}

export function LoginForm() {
  const router = useRouter();
  const [message, setMessage] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const supabase = createClient();
    if (!supabase) {
      setMessage("Add the Supabase URL and anon key in apps/web/.env.local before signing in.");
      return;
    }
    setPending(true);
    const { error } = await supabase.auth.signInWithPassword({
      email: String(form.get("email") ?? ""),
      password: String(form.get("password") ?? ""),
    });
    setPending(false);
    if (error) {
      setMessage(error.message);
      return;
    }
    router.push("/app");
  }

  return (
    <form onSubmit={onSubmit} className="grid gap-4">
      <Field label="Email" name="email" type="email" required />
      <Field label="Password" name="password" type="password" required />
      {message ? <p className="text-sm text-clay-deep">{message}</p> : null}
      <button
        type="submit"
        disabled={pending}
        className="rounded-full bg-clay px-5 py-3 font-semibold text-paper hover:bg-clay-deep disabled:opacity-60"
      >
        {pending ? "Signing in…" : "Log in"}
      </button>
      <p className="text-sm text-ink-soft">
        Phone codes, passkeys, and multi-factor authentication are part of the product and will be
        connected to Supabase Auth in the next build. This scaffold signs in with email and password.
      </p>
    </form>
  );
}

function Field({
  label,
  name,
  type = "text",
  ...props
}: {
  label: string;
  name: string;
  type?: string;
  required?: boolean;
  minLength?: number;
  maxLength?: number;
  placeholder?: string;
}) {
  return (
    <label className="grid gap-1 text-sm">
      <span className="font-semibold">{label}</span>
      <input
        name={name}
        type={type}
        {...props}
        className="rounded-xl border border-line bg-paper px-3 py-2"
      />
    </label>
  );
}

function Check({ name, label }: { name: string; label: string }) {
  return (
    <label className="flex items-start gap-2 text-sm">
      <input name={name} type="checkbox" className="mt-1" />
      <span>{label}</span>
    </label>
  );
}

export { joinDraftKey };
