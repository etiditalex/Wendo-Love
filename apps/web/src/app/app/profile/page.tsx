import { ProfilePanel } from "@/components/MemberPanels";

export default function ProfilePage() {
  return (
    <main className="grid max-w-xl gap-4">
      <h1 className="text-5xl text-clay-deep">Edit profile</h1>
      <p className="text-sm leading-6 text-ink-soft">
        Match criteria, photos, and the details others see. Occupation, faith, smoking, and alcohol stay off this first
        form — add them later only as optional fields you choose to show.
      </p>
      <ProfilePanel />
    </main>
  );
}
