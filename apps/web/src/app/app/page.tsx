import { DiscoverPanel } from "@/components/MemberPanels";
import { DesktopDiscover } from "@/components/DesktopDiscover";

export default function DiscoverPage() {
  return (
    <>
      <main className="grid gap-4 md:hidden">
        <h1 className="text-5xl text-clay-deep">Discover</h1>
        <DiscoverPanel />
      </main>
      <div className="hidden md:block">
        <DesktopDiscover />
      </div>
    </>
  );
}
