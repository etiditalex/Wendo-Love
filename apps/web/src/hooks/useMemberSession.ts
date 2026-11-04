"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";

export type SessionState = {
  ready: boolean;
  configured: boolean;
  userId: string | null;
  email: string | null;
};

export function useMemberSession(): SessionState {
  const [state, setState] = useState<SessionState>({
    ready: false,
    configured: false,
    userId: null,
    email: null,
  });

  useEffect(() => {
    const supabase = createClient();
    if (!supabase) {
      setState({ ready: true, configured: false, userId: null, email: null });
      return;
    }
    supabase.auth.getSession().then(({ data }) => {
      setState({
        ready: true,
        configured: true,
        userId: data.session?.user.id ?? null,
        email: data.session?.user.email ?? null,
      });
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      setState({
        ready: true,
        configured: true,
        userId: session?.user.id ?? null,
        email: session?.user.email ?? null,
      });
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  return state;
}
