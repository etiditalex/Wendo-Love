import { BoundaryNote, SiteFooter, SiteHeader } from "@/components/SiteChrome";

export default function LearnPage() {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto grid max-w-3xl gap-6 px-6 py-14">
        <p className="text-sm font-semibold tracking-[0.18em] text-gold uppercase">Learn</p>
        <h1 className="text-5xl text-clay-deep">Evidence, without a diagnosis</h1>
        <p className="text-lg leading-8 text-ink-soft">
          The World Health Organization explains that a person living with HIV who is on
          antiretroviral therapy and maintains an undetectable viral load does not transmit HIV
          sexually. That fact, often called U=U, belongs in this product as education.
        </p>
        <ul className="grid gap-3 text-sm leading-6">
          {[
            "Treatment, PrEP, condoms, STI screening, and testing windows are topics for clinician-reviewed pages.",
            "An older test result is not a verified HIV-negative badge. Status can change, and tests have window periods.",
            "Questions about your own health go to a licensed clinician. This app will not certify a result.",
          ].map((item) => (
            <li key={item} className="rounded-2xl bg-paper px-4 py-3 ring-1 ring-line">
              {item}
            </li>
          ))}
        </ul>
        <p>
          <a className="font-semibold text-clay-deep underline" href="https://www.who.int/news-room/fact-sheets/detail/hiv-aids/">
            WHO HIV and AIDS fact sheet
          </a>
        </p>
        <BoundaryNote />
      </main>
      <SiteFooter />
    </>
  );
}
