import Link from "next/link";

export default function MemberLearnPage() {
  return (
    <main className="grid max-w-2xl gap-4">
      <h1 className="text-5xl text-clay-deep">Learn</h1>
      <p className="leading-7 text-ink-soft">
        The same education lives on the public site so it can be read without an account.
      </p>
      <Link href="/learn" className="font-semibold text-clay-deep underline">
        Open the learn page
      </Link>
    </main>
  );
}
