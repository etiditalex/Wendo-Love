"use client";

import Link from "next/link";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { registerPremiumInterest } from "@/lib/member-data";
import { useMemberSession } from "@/hooks/useMemberSession";
import { useLang } from "@/components/LanguageProvider";

export default function UpgradePage() {
  const session = useMemberSession();
  const { t } = useLang();
  const [message, setMessage] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function onInterest() {
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    setPending(true);
    const error = await registerPremiumInterest(supabase, session.userId);
    setPending(false);
    setMessage(error ?? "Interest saved. Live card payments are not switched on yet.");
  }

  return (
    <main className="mx-auto grid max-w-xl gap-4">
      <h1 className="text-4xl text-clay-deep">{t("upgrade")}</h1>
      <p className="leading-7 text-ink-soft">
        Wendo Plus is the paid layer: mutual matches, reverse matches, and the body-style and education filters.
        You can also open mutual and reverse matches for free by completing your match criteria — gender, who you
        hope to meet, a city, and a photo.
      </p>
      <p className="leading-7 text-ink-soft">{t("lockedFilters")}</p>
      <div className="flex flex-wrap gap-3">
        <button
          type="button"
          onClick={onInterest}
          disabled={pending || !session.userId}
          className="rounded-md bg-clay px-4 py-2 font-semibold text-paper hover:bg-clay-deep disabled:opacity-60"
        >
          {pending ? "Saving…" : "Register Wendo Plus interest"}
        </button>
        <Link href="/app/profile" className="rounded-md bg-paper px-4 py-2 font-semibold text-clay-deep ring-1 ring-line">
          {t("completeProfile")}
        </Link>
      </div>
      {message ? <p className="text-sm text-clay-deep">{message}</p> : null}
    </main>
  );
}
