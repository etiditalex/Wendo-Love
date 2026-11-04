"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";
import { createClient } from "@/lib/supabase/client";

export function LoginScreen() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [keepLoggedIn, setKeepLoggedIn] = useState(true);
  const [emailError, setEmailError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const [langOpen, setLangOpen] = useState(false);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage(null);
    if (!email.trim()) {
      setEmailError("Please enter your email address");
      return;
    }
    setEmailError(null);
    const supabase = createClient();
    if (!supabase) {
      setMessage("Add the Supabase URL and anon key in apps/web/.env.local before signing in.");
      return;
    }
    setPending(true);
    if (!keepLoggedIn) {
      await supabase.auth.signOut({ scope: "local" }).catch(() => undefined);
    }
    const { error } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });
    setPending(false);
    if (error) {
      setMessage(error.message);
      return;
    }
    router.push("/app");
  }

  async function onForgotPassword() {
    setMessage(null);
    if (!email.trim()) {
      setEmailError("Please enter your email address");
      return;
    }
    setEmailError(null);
    const supabase = createClient();
    if (!supabase) {
      setMessage("Add Supabase keys before resetting a password.");
      return;
    }
    setPending(true);
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), {
      redirectTo: `${window.location.origin}/auth/callback`,
    });
    setPending(false);
    setMessage(error ? error.message : "If that email is registered, a reset link is on the way.");
  }

  async function onGoogle() {
    setMessage(null);
    const supabase = createClient();
    if (!supabase) {
      setMessage("Add Supabase keys before Google sign-in.");
      return;
    }
    setPending(true);
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: `${window.location.origin}/auth/callback` },
    });
    setPending(false);
    if (error) setMessage(error.message);
  }

  return (
    <div className="relative min-h-dvh bg-ink text-paper">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/hero.jpg"
        alt=""
        className="fixed inset-0 -z-10 size-full object-cover object-[50%_28%] brightness-[0.55] contrast-[1.05]"
      />
      <div className="fixed inset-0 -z-10 bg-gradient-to-b from-ink/55 via-ink/35 to-ink/70" />

      <div className="relative z-10 flex min-h-dvh flex-col">
        <header className="flex items-center justify-between px-4 py-4 sm:px-6 lg:px-10">
          <Link href="/" className="block w-[120px] sm:w-[148px]">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/wendo_logo_white.png" alt="Wendo" className="h-auto w-full drop-shadow-[0_2px_10px_rgba(0,0,0,0.35)]" />
          </Link>

          <div className="relative">
            <button
              type="button"
              onClick={() => setLangOpen((open) => !open)}
              className="inline-flex items-center gap-2 rounded-md bg-ink/80 px-3 py-2 text-sm text-paper ring-1 ring-white/15"
            >
              <GlobeIcon />
              English
              <ChevronIcon />
            </button>
            {langOpen ? (
              <div className="absolute right-0 z-20 mt-1 min-w-full rounded-md bg-ink/95 py-1 text-sm ring-1 ring-white/15">
                <button type="button" className="block w-full px-3 py-2 text-left hover:bg-white/10" onClick={() => setLangOpen(false)}>
                  English
                </button>
                <button type="button" className="block w-full px-3 py-2 text-left text-paper/70" disabled>
                  Kiswahili soon
                </button>
              </div>
            ) : null}
          </div>
        </header>

        <main className="flex flex-1 justify-center px-4 pb-10 sm:items-center sm:px-6 sm:py-8">
          <form
            onSubmit={onSubmit}
            className="w-full max-w-[420px] rounded-sm bg-black/25 px-5 py-6 backdrop-blur-[2px] sm:px-8 sm:py-8"
            noValidate
          >
            <h1 className="text-center font-sans text-[1.85rem] font-semibold tracking-wide sm:text-[2.1rem]">Members Login</h1>

            <div className="mt-7 grid gap-4">
              <label className="grid gap-1.5">
                <span className="sr-only">Email</span>
                <input
                  name="email"
                  type="email"
                  autoComplete="email"
                  placeholder="Email"
                  value={email}
                  onChange={(event) => {
                    setEmail(event.target.value);
                    if (emailError) setEmailError(null);
                  }}
                  className="w-full rounded-md border-0 bg-paper px-4 py-3.5 text-base text-ink outline-none ring-2 ring-transparent placeholder:text-ink-soft/70 focus:ring-clay"
                />
                {emailError ? (
                  <span className="flex items-center gap-1.5 text-sm text-[#ff6b6b]">
                    <AlertIcon />
                    {emailError}
                  </span>
                ) : null}
              </label>

              <label className="relative grid gap-1.5">
                <span className="sr-only">Password</span>
                <input
                  name="password"
                  type={showPassword ? "text" : "password"}
                  autoComplete="current-password"
                  placeholder="Password"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  required
                  className="w-full rounded-md border-0 bg-paper px-4 py-3.5 pr-12 text-base text-ink outline-none ring-2 ring-transparent placeholder:text-ink-soft/70 focus:ring-clay"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((value) => !value)}
                  className="absolute top-3.5 right-3 text-ink-soft hover:text-ink"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  <EyeIcon off={showPassword} />
                </button>
              </label>
            </div>

            <div className="mt-3 flex justify-start">
              <button
                type="button"
                onClick={onForgotPassword}
                disabled={pending}
                className="text-sm font-medium text-paper underline-offset-2 hover:underline disabled:opacity-60"
              >
                Forgot Password
              </button>
            </div>

            <label className="mt-5 flex items-start gap-3 text-sm">
              <span className="relative mt-0.5 inline-flex h-5 w-5 shrink-0 items-center justify-center">
                <input
                  type="checkbox"
                  checked={keepLoggedIn}
                  onChange={(event) => setKeepLoggedIn(event.target.checked)}
                  className="peer absolute inset-0 opacity-0"
                />
                <span className="grid h-5 w-5 place-items-center rounded-[3px] bg-paper peer-checked:bg-sage">
                  {keepLoggedIn ? <CheckIcon /> : null}
                </span>
              </span>
              <span>
                <span className="font-medium">Keep me logged in.</span>
                <span className="mt-1 block text-[13px] leading-5 text-paper/80 italic">
                  Don&apos;t check this box if you&apos;re at a public or shared computer
                </span>
              </span>
            </label>

            {message ? <p className="mt-4 text-center text-sm text-[#ffd0da]">{message}</p> : null}

            <button
              type="submit"
              disabled={pending}
              className="mt-6 w-full rounded-md bg-gold py-3.5 text-lg font-semibold text-paper shadow-[0_3px_8px_rgba(0,0,0,0.35)] hover:bg-[#9a7548] disabled:opacity-60"
            >
              {pending ? "Signing in…" : "Login"}
            </button>

            <p className="mt-5 text-center text-sm text-paper/85">or</p>

            <button
              type="button"
              onClick={onGoogle}
              disabled={pending}
              className="mt-4 flex w-full items-center justify-center gap-3 rounded-md bg-paper px-4 py-3 text-sm font-medium text-ink shadow-sm hover:bg-cream disabled:opacity-60"
            >
              <GoogleIcon />
              Sign in with Google
            </button>

            <p className="mt-7 text-center text-sm sm:text-base">
              Not a member?{" "}
              <Link href="/join" className="font-semibold text-gold hover:underline">
                Join Now!
              </Link>
            </p>
          </form>
        </main>
      </div>
    </div>
  );
}

function GlobeIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.7" />
      <path d="M3 12h18M12 3c2.5 2.8 3.8 5.8 3.8 9S14.5 18.2 12 21c-2.5-2.8-3.8-5.8-3.8-9S9.5 5.8 12 3z" stroke="currentColor" strokeWidth="1.7" />
    </svg>
  );
}

function ChevronIcon() {
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="m6 9 6 6 6-6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    </svg>
  );
}

function AlertIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M12 2 1 21h22L12 2zm0 6.5a1.2 1.2 0 0 1 1.2 1.2v4.1a1.2 1.2 0 0 1-2.4 0v-4.1A1.2 1.2 0 0 1 12 8.5zm0 8.2a1.3 1.3 0 1 1 0 2.6 1.3 1.3 0 0 1 0-2.6z" />
    </svg>
  );
}

function EyeIcon({ off = false }: { off?: boolean }) {
  if (off) {
    return (
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path d="M3 3l18 18M10.5 10.6A3 3 0 0 0 13.4 13.5M9.9 5.2A10.5 10.5 0 0 1 12 5c5 0 9.3 3.1 11 7-0.6 1.5-1.6 2.9-2.9 4M6.1 6.2C4.3 7.5 2.9 9.2 2 12c1.7 3.9 6 7 10 7 1.4 0 2.8-.3 4-.8" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
      </svg>
    );
  }
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" stroke="currentColor" strokeWidth="1.7" />
      <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="1.7" />
    </svg>
  );
}

function CheckIcon() {
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="m5 12 5 5L20 7" stroke="#fffdf8" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function GoogleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden="true">
      <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.3 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3 0 5.8 1.1 7.9 3l5.7-5.7C34.2 6.1 29.4 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.2-.1-2.3-.4-3.5z" />
      <path fill="#FF3D00" d="m6.3 14.7 6.6 4.8C14.7 16 19 12 24 12c3 0 5.8 1.1 7.9 3l5.7-5.7C34.2 6.1 29.4 4 24 4 16.3 4 9.6 8.3 6.3 14.7z" />
      <path fill="#4CAF50" d="M24 44c5.2 0 10-2 13.5-5.2l-6.2-5.2C29.3 35.9 26.8 37 24 37c-5.2 0-9.6-3.3-11.3-8l-6.5 5C9.4 40 16.1 44 24 44z" />
      <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.3-2.3 4.2-4.1 5.6l.1.1 6.2 5.2C39.2 37.3 44 32 44 24c0-1.2-.1-2.3-.4-3.5z" />
    </svg>
  );
}
