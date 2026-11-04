import { BoundaryNote, SiteFooter, SiteHeader } from "@/components/SiteChrome";

export default function SupportPage() {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto grid max-w-3xl gap-6 px-6 py-14">
        <p className="text-sm font-semibold tracking-[0.18em] text-gold uppercase">Support</p>
        <h1 className="text-5xl text-clay-deep">Community, without a clinic list</h1>
        <p className="leading-8 text-ink-soft">
          Moderated events, a referral directory, and links to counseling will sit here after
          partners are vetted. A clinic should never hand over a patient list to recruit members,
          and this product will not track whether someone visits a clinic.
        </p>
        <BoundaryNote />
      </main>
      <SiteFooter />
    </>
  );
}
