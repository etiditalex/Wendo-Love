"use client";

import { FormEvent, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { useMemberSession } from "@/hooks/useMemberSession";
import {
  loadMeetingCheckins,
  loadTrustedContacts,
  saveMeetingCheckin,
  saveTrustedContact,
  updateMeetingCheckinStatus,
} from "@/lib/member-data";

export default function MeetPage() {
  const session = useMemberSession();
  const [contacts, setContacts] = useState<Array<Record<string, unknown>>>([]);
  const [checkins, setCheckins] = useState<Array<Record<string, unknown>>>([]);
  const [message, setMessage] = useState<string | null>(null);

  async function reload(userId: string) {
    const supabase = createClient();
    if (!supabase) return;
    setContacts(await loadTrustedContacts(supabase, userId));
    setCheckins(await loadMeetingCheckins(supabase, userId));
  }

  useEffect(() => {
    if (!session.userId) return;
    reload(session.userId);
  }, [session.userId]);

  async function onContact(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    const form = new FormData(event.currentTarget);
    const error = await saveTrustedContact(
      supabase,
      session.userId,
      String(form.get("name") ?? ""),
      String(form.get("phone") ?? ""),
    );
    setMessage(error ?? "Trusted contact saved. Only you can see this.");
    if (!error) {
      event.currentTarget.reset();
      await reload(session.userId);
    }
  }

  async function onCheckin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!session.userId) return;
    const supabase = createClient();
    if (!supabase) return;
    const form = new FormData(event.currentTarget);
    const error = await saveMeetingCheckin(supabase, session.userId, String(form.get("place") ?? ""));
    setMessage(error ?? "Check-in started.");
    if (!error) {
      event.currentTarget.reset();
      await reload(session.userId);
    }
  }

  function openVideo() {
    const room = `wendo-${session.userId ?? "guest"}`.replace(/[^a-zA-Z0-9-]/g, "");
    window.open(`https://meet.jit.si/${room}`, "_blank", "noopener,noreferrer");
  }

  return (
    <main className="grid max-w-2xl gap-6">
      <h1 className="text-5xl text-clay-deep">Meet safely</h1>
      <p className="text-sm leading-6 text-ink-soft">
        Meet first in a public place. Trusted contacts and check-ins stay private to you. Video calls are optional.
      </p>
      <section className="grid gap-3 rounded-2xl bg-paper p-5 ring-1 ring-line">
        <h2 className="font-serif text-2xl">Trusted contact</h2>
        <form onSubmit={onContact} className="grid gap-3">
          <input name="name" required placeholder="Name" className="rounded-xl border border-line bg-cream px-3 py-2" />
          <input name="phone" required placeholder="Phone" className="rounded-xl border border-line bg-cream px-3 py-2" />
          <button type="submit" className="w-fit rounded-full bg-clay px-4 py-2 text-sm font-semibold text-paper">
            Save contact
          </button>
        </form>
        <ul className="grid gap-2 text-sm">
          {contacts.map((row) => (
            <li key={String(row.id)}>
              {String(row.display_name)} · {String(row.phone)}
            </li>
          ))}
        </ul>
      </section>
      <section className="grid gap-3 rounded-2xl bg-paper p-5 ring-1 ring-line">
        <h2 className="font-serif text-2xl">Meeting check-in</h2>
        <form onSubmit={onCheckin} className="grid gap-3">
          <input name="place" placeholder="Public place note" className="rounded-xl border border-line bg-cream px-3 py-2" />
          <button type="submit" className="w-fit rounded-full bg-clay-deep px-4 py-2 text-sm font-semibold text-paper">
            I am heading out
          </button>
        </form>
        <ul className="grid gap-2 text-sm">
          {checkins.slice(0, 5).map((row) => (
            <li key={String(row.id)} className="flex items-center justify-between gap-2">
              <span>
                {String(row.place_note || "Check-in")} · {String(row.status)}
              </span>
              {row.status === "started" || row.status === "planned" ? (
                <button
                  type="button"
                  className="underline"
                  onClick={async () => {
                    if (!session.userId) return;
                    const supabase = createClient();
                    if (!supabase) return;
                    await updateMeetingCheckinStatus(supabase, session.userId, String(row.id), "safe");
                    await reload(session.userId);
                  }}
                >
                  I am safe
                </button>
              ) : null}
            </li>
          ))}
        </ul>
      </section>
      <section className="grid gap-3 rounded-2xl bg-paper p-5 ring-1 ring-line">
        <h2 className="font-serif text-2xl">Optional video call</h2>
        <p className="text-sm text-ink-soft">Opens a private Jitsi room outside Wendo.</p>
        <button type="button" onClick={openVideo} className="w-fit rounded-full bg-paper px-4 py-2 text-sm ring-1 ring-line">
          Open video room
        </button>
      </section>
      {message ? <p className="text-sm text-clay-deep">{message}</p> : null}
    </main>
  );
}
