import { SettingsPanel } from "@/components/MemberPanels";

export default function SettingsPage() {
  return (
    <main className="grid max-w-xl gap-4">
      <h1 className="text-5xl text-clay-deep">Privacy controls</h1>
      <SettingsPanel />
    </main>
  );
}
