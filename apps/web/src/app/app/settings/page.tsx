"use client";

import { SettingsPanel } from "@/components/MemberPanels";

export default function SettingsPage() {
  return (
    <main className="grid max-w-xl gap-4">
      <h1 className="text-4xl text-clay-deep md:text-5xl">Account settings</h1>
      <p className="text-sm leading-6 text-ink-soft">
        Same place as the gear icon on KenyanCupid — privacy, pause account, favorites, and export. Email and password
        changes stay available from the phone app for now.
      </p>
      <div id="privacy" />
      <div id="notifications" />
      <SettingsPanel />
    </main>
  );
}
