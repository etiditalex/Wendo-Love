import { MatchesPanel } from "@/components/MemberPanels";

export default function MatchesPage() {
  return (
    <main className="grid gap-4">
      <h1 className="text-3xl text-clay-deep md:text-4xl">Activity</h1>
      <MatchesPanel />
    </main>
  );
}
