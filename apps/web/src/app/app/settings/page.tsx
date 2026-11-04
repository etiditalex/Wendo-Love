"use client";

import { SettingsPanel } from "@/components/MemberPanels";

export default function SettingsPage() {
  return (
    <main className="grid max-w-xl gap-4">
      <h1 className="text-4xl text-clay-deep md:text-5xl">Profile settings</h1>
      <p className="text-sm leading-6 text-ink-soft">
        Privacy, pause account, favorites, and export — same gear-menu destination as on KenyanCupid. Email and password
        changes stay available from the phone app for now.
      </p>
      <div id="privacy" />
      <div id="notifications" />
      <SettingsPanel />
    </main>
  );
}
