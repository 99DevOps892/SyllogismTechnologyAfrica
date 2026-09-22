"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

export default function Home() {
  const [session, setSession] = useState<null | string>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session?.user?.email ?? null);
    });
  }, []);

  return (
    <main style={{ fontFamily: "sans-serif", padding: 24 }}>
      <h1>SyllogismTechnologyAfrica</h1>
      <p>Status: {session ? `Signed in as ${session}` : "Signed out"}</p>
      <button
        onClick={async () => {
          const email = prompt("Email");
          const password = prompt("Password");
          if (!email || !password) return;
          const { error } = await supabase.auth.signUp({ email, password });
          alert(error ? error.message : "Check your email to confirm signup");
        }}
      >
        Sign up
      </button>
    </main>
  );
}