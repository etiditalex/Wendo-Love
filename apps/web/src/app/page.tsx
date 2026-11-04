import Link from "next/link";
import { Roboto } from "next/font/google";

const roboto = Roboto({
  subsets: ["latin"],
  weight: ["300", "400", "500"],
  variable: "--font-roboto",
});

const benefits = [
  "Create a profile with a name you choose",
  "Chat opens only after a mutual like",
  "Private by default, for adults 18 and over",
];

const columns = [
  {
    title: "Why Wendo",
    body: "A consent-led place to meet for adults who want a respectful relationship, including people living with HIV and HIV-negative adults who choose that knowingly. Marriage and other clearly stated intentions are both welcome.",
  },
  {
    title: "Private by design",
    body: "HIV status is optional and stays off your public profile. The product never asks for a clinic, a patient number, or a treatment card, and it does not rank anyone by a diagnosis.",
  },
  {
    title: "Kenya first",
    body: "The pilot starts in Kenya and is shaped with community partners. It is a relationship platform, not a clinic, a testing service, or a patient registry.",
  },
];

const steps = [
  ["Create a profile", "Confirm you are 18 or over, choose a display name, and set what kind of relationship you want."],
  ["Discover", "Suggestions use interests and preferences you both chose. Status is never guessed."],
  ["Start talking", "A mutual like opens a private conversation, with block and report close by."],
];

export default function HomePage() {
  return (
    <div className={`${roboto.variable} landing bg-cream text-ink`}>
      <section className="flex h-dvh flex-col bg-clay-deep text-paper md:hidden">
        <header className="px-4 pt-2 pb-3">
          <div className="flex justify-end">
            <Link href="/login" className="px-2 py-2 text-base font-medium text-paper">
              Login
            </Link>
          </div>
          <Link href="/" className="mx-auto block w-[min(52vw,200px)]">
            <img src="/wendo_logo_white.png" alt="Wendo" className="h-auto w-full" />
          </Link>
        </header>
        <div className="flex min-h-0 flex-1 flex-col justify-between bg-cream text-ink">
          <div className="bg-clay-deep">
            <div className="relative h-[min(62dvh,calc(100vw*1.25))] w-full overflow-hidden [border-top-left-radius:50%_40px] [border-top-right-radius:50%_40px]">
              <img
                src="/hero.jpg"
                alt=""
                className="absolute inset-x-0 bottom-0 top-6 h-[calc(100%-1.5rem)] w-full object-cover object-[50%_24%]"
              />
            </div>
          </div>
          <div className="shrink-0 px-7 pt-5 pb-7 text-center">
            <h1 className="text-[1.6rem] leading-tight font-medium">Meet with dignity</h1>
            <Link
              href="/join"
              className="mt-4 block rounded-full bg-clay py-4 text-base text-paper hover:bg-clay-deep"
            >
              Join free today
            </Link>
          </div>
        </div>
      </section>

      <section className="relative hidden min-h-[100vh] overflow-hidden bg-ink text-paper md:block">
        <img
          src="/hero.jpg"
          alt=""
          className="absolute inset-0 size-full object-cover object-[46%_30%] brightness-[1.05] contrast-[1.04]"
        />
        <div
          className="absolute inset-0"
          style={{
            backgroundImage:
              "linear-gradient(90deg, rgba(28,25,23,0.48) 0%, rgba(28,25,23,0.14) 28%, transparent 58%)",
          }}
        />
        <div className="absolute inset-x-0 bottom-0 h-40 bg-gradient-to-t from-ink/45 to-transparent" />

        <div className="relative z-10 flex min-h-[100vh] flex-col">
          <header className="flex items-center justify-between px-8 py-6 lg:px-12">
            <Link href="/" className="block w-[148px] lg:w-[176px]">
              <img src="/wendo_logo_white.png" alt="Wendo" className="h-auto w-full drop-shadow-[0_2px_10px_rgba(0,0,0,0.35)]" />
            </Link>
            <Link
              href="/login"
              className="rounded-[4px] bg-clay px-5 py-2 text-[15px] text-paper shadow-[0_2px_4px_rgba(0,0,0,0.25)] hover:bg-clay-deep"
            >
              Login
            </Link>
          </header>

          <div className="mx-auto flex w-full max-w-6xl flex-1 items-center px-8 pb-32 lg:px-12">
            <div className="max-w-xl drop-shadow-[0_2px_18px_rgba(0,0,0,0.35)]">
              <h1 className="text-5xl leading-[1.05] font-light lg:text-6xl">Meet with dignity</h1>
              <p className="mt-4 text-xl font-normal lg:text-2xl">Connecting adults locally and beyond</p>
              <Link
                href="/join"
                className="mt-8 inline-block rounded-[4px] bg-clay px-5 py-2.5 text-[18px] text-paper shadow-[0_3px_6px_rgba(0,0,0,0.4)] hover:bg-clay-deep"
              >
                Join free today
              </Link>
            </div>
          </div>

          <ul className="absolute inset-x-0 bottom-0 grid gap-3 bg-black/35 px-8 py-4 md:grid-cols-3 lg:px-12">
            {benefits.map((benefit) => (
              <li key={benefit} className="flex items-center gap-3 text-sm md:text-base">
                <span className="h-3.5 w-3.5 shrink-0 rounded-full bg-gold" />
                {benefit}
              </li>
            ))}
          </ul>
        </div>
      </section>

      <nav className="bg-paper px-5 py-4 text-center text-sm text-ink-soft">
        {[
          ["/learn", "Learn"],
          ["/safety", "Safety"],
          ["/privacy", "Privacy"],
          ["/support", "Support"],
        ].map(([href, label], index) => (
          <span key={href}>
            {index > 0 ? <span className="px-2 text-gold">|</span> : null}
            <Link href={href} className="hover:text-clay-deep">
              {label}
            </Link>
          </span>
        ))}
      </nav>

      <section className="mx-auto grid max-w-6xl gap-10 px-5 py-16 md:grid-cols-3 md:px-10">
        {columns.map((column) => (
          <article key={column.title}>
            <h2 className="text-[1.4rem] leading-snug font-normal text-clay-deep">{column.title}</h2>
            <p className="mt-4 text-[15px] leading-7 text-ink-soft">{column.body}</p>
          </article>
        ))}
      </section>

      <section className="border-t border-line bg-paper">
        <div className="mx-auto max-w-6xl px-5 py-16 text-center md:px-10">
          <h2 className="text-[1.7rem] font-normal text-clay-deep">How it works</h2>
          <p className="mt-2 text-ink-soft">Get started in three steps.</p>
          <ol className="mt-10 grid gap-8 text-left md:grid-cols-3">
            {steps.map(([title, body], index) => (
              <li key={title}>
                <p className="text-3xl font-light text-gold">{index + 1}</p>
                <h3 className="mt-2 text-xl font-normal text-clay-deep">{title}</h3>
                <p className="mt-2 text-[15px] leading-7 text-ink-soft">{body}</p>
              </li>
            ))}
          </ol>
          <Link
            href="/join"
            className="mt-10 inline-block rounded-[4px] bg-clay px-5 py-2 text-paper shadow-[0_3px_6px_rgba(0,0,0,0.25)] hover:bg-clay-deep"
          >
            Create your profile
          </Link>
        </div>
      </section>

      <footer className="border-t border-line bg-paper text-sm text-ink-soft">
        <div className="mx-auto grid max-w-6xl gap-8 px-5 py-10 md:grid-cols-3 md:px-10">
          <div>
            <img src="/wendo_logo.png" alt="Wendo" className="h-14 w-auto" />
            <p className="mt-3 leading-6">Love. Dignity. Connection. Adults 18 and over.</p>
          </div>
          <div>
            <p className="text-clay-deep">Information</p>
            <ul className="mt-2 space-y-1">
              <li><Link href="/learn">Learn</Link></li>
              <li><Link href="/safety">Dating safety</Link></li>
              <li><Link href="/support">Support</Link></li>
            </ul>
          </div>
          <div>
            <p className="text-clay-deep">Legal</p>
            <ul className="mt-2 space-y-1">
              <li><Link href="/privacy">Privacy</Link></li>
              <li><Link href="/join">Join</Link></li>
              <li><Link href="/login">Login</Link></li>
            </ul>
          </div>
        </div>
        <p className="border-t border-line px-5 py-4 text-center leading-6">
          This is a relationship platform, not a clinic, testing service, or patient registry.
        </p>
      </footer>
    </div>
  );
}

