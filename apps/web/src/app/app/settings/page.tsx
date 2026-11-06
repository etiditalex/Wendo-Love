"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { SettingsPanel } from "@/components/MemberPanels";

export default function SettingsPage() {
  const router = useRouter();

  useEffect(() => {
    const hash = window.location.hash.replace("#", "");
    if (hash === "privacy" || hash === "notifications") {
      document.getElementById(hash)?.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }, []);

  return (
    <main className="grid max-w-xl gap-4">
      <button
        type="button"
        onClick={() => {
          if (window.history.length > 1) router.back();
          else router.push("/app");
        }}
        className="w-fit text-sm font-semibold text-clay-deep underline"
      >
        ← Back
      </button>
      <h1 className="text-4xl text-clay-deep md:text-5xl">Profile settings</h1>
      <p className="text-sm leading-6 text-ink-soft">
        Privacy, pause account, favorites, and export — same gear-menu destination as on KenyanCupid. Email and password
        changes stay available from the phone app for now.
      </p>
      <section id="privacy" className="scroll-mt-24 grid gap-2 rounded-2xl bg-paper p-5 ring-1 ring-line">
        <h2 className="font-serif text-2xl text-ink">Privacy</h2>
        <p className="text-sm leading-6 text-ink-soft">
          Pause discovery, blur photos until mutual match, and export your data in the panel below. These controls stay
          private to your account.
        </p>
      </section>
      <section id="notifications" className="scroll-mt-24 grid gap-2 rounded-2xl bg-paper p-5 ring-1 ring-line">
        <h2 className="font-serif text-2xl text-ink">Notifications</h2>
        <p className="text-sm leading-6 text-ink-soft">
          Push and email notification toggles live in the phone app under Settings → Notifications. Web alerts for new
          messages appear while you keep this tab open.
        </p>
        <Link href="/app/messages" className="text-sm font-semibold text-clay-deep underline">
          Open messages
        </Link>
      </section>
      <SettingsPanel />
    </main>
  );
}
