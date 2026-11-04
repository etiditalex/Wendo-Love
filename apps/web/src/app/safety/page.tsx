import { SiteFooter, SiteHeader } from "@/components/SiteChrome";

export default function SafetyPage() {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto grid max-w-3xl gap-6 px-6 py-14">
        <p className="text-sm font-semibold tracking-[0.18em] text-gold uppercase">Safety</p>
        <h1 className="text-5xl text-clay-deep">Adults only, with a way out</h1>
        <ul className="grid gap-3 text-sm leading-6">
          {[
            "Every member passes an 18+ age gate. Photo or identity checks, if added later, keep as little data as possible.",
            "Block, report, mute, and unmatch are first-class actions. Reports cover harassment, scams, impersonation, outing threats, and coercion.",
            "There is no public member directory and no import of phone or social contacts.",
            "Screenshots cannot be fully prevented. The product will say that plainly.",
            "If you are in immediate danger, contact local emergency services. This pilot does not promise a staffed 24/7 crisis line.",
          ].map((item) => (
            <li key={item} className="rounded-2xl bg-paper px-4 py-3 ring-1 ring-line">
              {item}
            </li>
          ))}
        </ul>
      </main>
      <SiteFooter />
    </>
  );
}
