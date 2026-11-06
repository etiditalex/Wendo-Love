"use client";

import { useRouter } from "next/navigation";
import { ProfilePanel } from "@/components/MemberPanels";

export default function ProfilePage() {
  const router = useRouter();
  return (
    <main className="grid max-w-xl gap-4">
      <button
        type="button"
        onClick={() => {
          if (window.history.length > 1) router.back();
          else router.push("/app");
        }}
        className="w-fit text-sm font-semibold text-clay-deep underline"
      >
        ← Back
      </button>
      <h1 className="text-5xl text-clay-deep">Edit profile</h1>
      <p className="text-sm leading-6 text-ink-soft">
        Match criteria, photos, and the details others see. Occupation, faith, smoking, and alcohol stay off this first
        form — add them later only as optional fields you choose to show.
      </p>
      <ProfilePanel />
    </main>
  );
}
