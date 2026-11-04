import { BoundaryNote, SiteFooter, SiteHeader } from "@/components/SiteChrome";

export default function PrivacyPage() {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto grid max-w-3xl gap-6 px-6 py-14">
        <p className="text-sm font-semibold tracking-[0.18em] text-gold uppercase">Privacy</p>
        <h1 className="text-5xl text-clay-deep">Private by default</h1>
        <p className="leading-8 text-ink-soft">
          HIV status is highly sensitive. Before the pilot processes it, Kenyan counsel and the
          Office of the Data Protection Commissioner guidance need to be in place, including a data
          protection impact assessment. This scaffold is built so that review has somewhere strict
          to land.
        </p>
        <ul className="grid gap-3 text-sm leading-6">
          {[
            "Account identity and optional health fields are different tables. Discovery cannot read the health table.",
            "Location shown to other members is a city or a broad radius.",
            "You can use a pseudonym, pause the account, and later export or delete it.",
            "HIV status and other health data are not sold, and they are not used for advertising.",
            "Notifications are designed to stay discreet. The wording will not mention HIV on a lock screen.",
          ].map((item) => (
            <li key={item} className="rounded-2xl bg-paper px-4 py-3 ring-1 ring-line">
              {item}
            </li>
          ))}
        </ul>
        <BoundaryNote />
      </main>
      <SiteFooter />
    </>
  );
}
