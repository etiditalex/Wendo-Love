"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { useMemberSession } from "@/hooks/useMemberSession";
import { loadPartnerResources, registerPremiumInterest } from "@/lib/member-data";

export default function MemberSupportPage() {
  const session = useMemberSession();
  const [partners, setPartners] = useState<Array<Record<string, unknown>>>([]);
  const [message, setMessage] = useState<string | null>(null);

  useEffect(() => {
    const supabase = createClient();
    if (!supabase) return;
    loadPartnerResources(supabase).then(setPartners);
  }, []);

  async function onPremium() {
    if (!session.userId) {
      setMessage("Sign in first.");
      return;
    }
    const supabase = createClient();
    if (!supabase) return;
    const error = await registerPremiumInterest(supabase, session.userId);
    setMessage(error ?? "Interest saved. Billing is not live in this pilot.");
  }

  return (
    <main className="grid max-w-2xl gap-6">
      <h1 className="text-5xl text-clay-deep">Support</h1>
      <p className="leading-7 text-ink-soft">
        Partner links open outside Wendo. Nothing here tracks a clinic visit.
      </p>
      <ul className="grid gap-3">
        {partners.length === 0 ? (
          <li className="rounded-2xl bg-paper px-4 py-3 text-sm ring-1 ring-line">Partner resources will appear after migrations are applied.</li>
        ) : (
          partners.map((item) => (
            <li key={String(item.id)} className="rounded-2xl bg-paper px-4 py-3 ring-1 ring-line">
              <p className="font-semibold">{String(item.title)}</p>
              <p className="mt-1 text-sm leading-6 text-ink-soft">{String(item.summary)}</p>
              {item.url ? (
                <a href={String(item.url)} target="_blank" rel="noreferrer" className="mt-2 inline-block text-sm font-semibold text-clay-deep underline">
                  Open link
                </a>
              ) : null}
            </li>
          ))
        )}
      </ul>
      <section className="grid gap-3 rounded-2xl bg-paper p-5 ring-1 ring-line">
        <h2 className="font-serif text-2xl">Wendo Plus interest</h2>
        <p className="text-sm text-ink-soft">Essentials stay free. Register interest for paid boosts later. No payment is taken here.</p>
        <button type="button" onClick={onPremium} className="w-fit rounded-full bg-clay px-4 py-2 text-sm font-semibold text-paper">
          Register interest
        </button>
      </section>
      <Link href="/support" className="font-semibold text-clay-deep underline">
        Open the public support page
      </Link>
      {message ? <p className="text-sm text-clay-deep">{message}</p> : null}
    </main>
  );
}
