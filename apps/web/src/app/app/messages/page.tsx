import { MessagesPanel } from "@/components/MemberPanels";

export default function MessagesPage() {
  return (
    <main className="grid gap-4">
      <h1 className="text-3xl text-clay-deep md:text-4xl">Messages</h1>
      <MessagesPanel />
    </main>
  );
}
