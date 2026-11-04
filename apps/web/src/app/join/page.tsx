import { JoinForm } from "@/components/AuthForms";
import { SiteFooter, SiteHeader } from "@/components/SiteChrome";

export default function JoinPage() {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto grid max-w-xl gap-6 px-6 py-14">
        <h1 className="text-5xl text-clay-deep">Join</h1>
        <p className="text-ink-soft">Adults 18 and over. Use a name you are comfortable showing.</p>
        <JoinForm />
      </main>
      <SiteFooter />
    </>
  );
}
