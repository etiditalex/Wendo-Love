"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { loadHomeBoard } from "@/lib/member-data";
import { useMemberSession } from "@/hooks/useMemberSession";
import { useLang } from "@/components/LanguageProvider";

export default function UpgradePage() {
  const session = useMemberSession();
  const { t } = useLang();
  const [complete, setComplete] = useState(false);

  useEffect(() => {
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    loadHomeBoard(supabase, session.userId).then((board) => setComplete(Boolean(board.criteriaComplete)));
  }, [session.userId]);

  return (
    <main className="mx-auto grid max-w-xl gap-4">
      <h1 className="text-4xl text-clay-deep">{t("upgrade")}</h1>
      <p className="leading-7 text-ink-soft">{t("plusInactive")}</p>
      <p className="leading-7 text-ink-soft">{t("lockedFilters")}</p>
      <div className="rounded-xl bg-paper p-4 ring-1 ring-line">
        <p className="font-semibold text-ink">Match criteria unlock Mutual and Reverse for free</p>
        <ul className="mt-2 grid gap-1 text-sm text-ink-soft">
          <li>• City / area</li>
          <li>• I am (gender)</li>
          <li>• I hope to meet</li>
          <li>• Profile photo</li>
        </ul>
        <p className="mt-3 text-sm text-ink-soft">
          {complete
            ? "Your match criteria look complete — Mutual and Reverse are unlocked on Home."
            : "Open Edit Profile and fill those four fields, then return to Home."}
        </p>
      </div>
      <Link href="/app/profile" className="rounded-md bg-clay px-4 py-2 text-center font-semibold text-paper hover:bg-clay-deep">
        {complete ? "Open profile" : t("completeProfile")}
      </Link>
    </main>
  );
}
