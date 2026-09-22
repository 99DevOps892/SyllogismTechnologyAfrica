"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import {
  mali,
  fetchMaliLookups,
  listMaliGroups,
  createMaliGroup,
  listMaliMembers,
  addMaliMember,
  listMaliCycles,
  openMaliCycle,
  listMaliContributions,
  recordMaliContribution,
  subscribeMaliStore,
  type MaliLookups,
  type MaliGroup,
  type MaliMember,
  type MaliCycle,
  type MaliContribution,
} from "../../lib/mali";

type Status = { kind: "info" | "error"; text: string };
interface AuthUser {
  id: string;
  email: string | null;
}

const codeChip: React.CSSProperties = {
  fontFamily: "ui-monospace,monospace", fontSize: 11, color: "#cbd5e1",
  background: "#1e293b", borderRadius: 999, padding: "2px 8px",
};
const inputStyle: React.CSSProperties = {
  background: "#0f172a", border: "1px solid #334155", color: "#e2e8f0",
  borderRadius: 6, padding: "6px 8px", fontSize: 13, width: "100%", boxSizing: "border-box",
};
const labelStyle: React.CSSProperties = { fontSize: 11, color: "#94a3b8", display: "block", margin: "0 0 3px" };
const btn: React.CSSProperties = {
  background: "#2563eb", border: "none", color: "#fff", borderRadius: 6,
  padding: "6px 12px", fontSize: 13, cursor: "pointer", marginTop: 8,
};

export default function MaliDashboard() {
  const configured = Boolean(process.env.NEXT_PUBLIC_MALI_SUPABASE_URL && process.env.NEXT_PUBLIC_MALI_SUPABASE_ANON_KEY);

  const [user, setUser] = useState<AuthUser | null>(null);
  const [lookups, setLookups] = useState<MaliLookups | null>(null);
  const [groups, setGroups] = useState<MaliGroup[]>([]);
  const [members, setMembers] = useState<MaliMember[]>([]);
  const [cycles, setCycles] = useState<MaliCycle[]>([]);
  const [contributions, setContributions] = useState<MaliContribution[]>([]);
  const [status, setStatus] = useState<Status>({ kind: "info", text: "Loading…" });
  const [live, setLive] = useState(false);

  const refresh = useCallback(async () => {
    const results = await Promise.allSettled([
      fetchMaliLookups(mali),
      listMaliGroups(mali),
      listMaliMembers(mali),
      listMaliCycles(mali),
      listMaliContributions(mali),
    ]);
    const [okLookups, okGroups, okMembers, okCycles, okContrib] = results.map((r) => r.status === "fulfilled");
    if (results[1].status === "fulfilled") setGroups(results[1].value);
    if (results[2].status === "fulfilled") setMembers(results[2].value);
    if (results[3].status === "fulfilled") setCycles(results[3].value);
    if (results[4].status === "fulfilled") setContributions(results[4].value);
    if (okLookups && results[0].status === "fulfilled") setLookups(results[0].value);
    if (okGroups && okMembers && okCycles && okContrib && okLookups) {
      setStatus({ kind: "info", text: "Connected to MALI store (read view)." });
    } else {
      setStatus({ kind: "error", text: "Some reads failed — check your session / RLS." });
    }
  }, []);

  useEffect(() => {
    if (!configured) return;
    void refresh();
    const { data } = mali.auth.onAuthStateChange((_event, session) => {
      if (session?.user) setUser({ id: session.user.id, email: session.user.email ?? null });
      else setUser(null);
    });
    mali.auth.getSession().then(({ data: sd }) => {
      if (sd.session?.user) setUser({ id: sd.session.user.id, email: sd.session.user.email ?? null });
    });
    const channel = subscribeMaliStore(mali, () => {
      setLive(true);
      void refresh();
    });
    channel
      .on("system", { event: "exit" }, () => setLive(false))
      .on("system", { event: "error" }, () => setLive(false));
    return () => {
      data.subscription.unsubscribe();
      void mali.removeChannel(channel);
    };
  }, [refresh, configured]);

  // ---- auth ----
  async function signIn(e: React.FormEvent) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget as HTMLFormElement);
    const email = String(fd.get("email") ?? "");
    const password = String(fd.get("password") ?? "");
    const { error } = await mali.auth.signInWithPassword({ email, password });
    if (error) setStatus({ kind: "error", text: "Sign in: " + error.message });
    else { setStatus({ kind: "info", text: "Signed in." }); void refresh(); }
  }

  async function signUp(e: React.FormEvent) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget as HTMLFormElement);
    const email = String(fd.get("email") ?? "");
    const password = String(fd.get("password") ?? "");
    const { error } = await mali.auth.signUp({ email, password });
    if (error) setStatus({ kind: "error", text: "Sign up: " + error.message });
    else setStatus({ kind: "info", text: "Sign-up submitted (check your inbox if confirmation is enabled)." });
  }

  async function signOut() {
    await mali.auth.signOut();
    setUser(null);
    setStatus({ kind: "info", text: "Signed out." });
    void refresh();
  }

  // ---- write path (creator / member, RLS-guarded) ----
  async function onCreateGroup(e: React.FormEvent) {
    e.preventDefault();
    if (!user) { setStatus({ kind: "error", text: "Sign in first — group creation requires an authenticated creator." }); return; }
    const fd = new FormData(e.currentTarget as HTMLFormElement);
    try {
      await createMaliGroup(mali, {
        name: String(fd.get("name") ?? ""),
        description: String(fd.get("description") ?? "") || null,
        currency: String(fd.get("currency") ?? "XOF") || "XOF",
        created_by: user.id,
      });
      setStatus({ kind: "info", text: "Group created." });
      void refresh();
    } catch (err) { setStatus({ kind: "error", text: "createGroup: " + (err as Error).message }); }
  }

  async function onAddMember(e: React.FormEvent) {
    e.preventDefault();
    if (!user) { setStatus({ kind: "error", text: "Sign in first." }); return; }
    const fd = new FormData(e.currentTarget as HTMLFormElement);
    try {
      await addMaliMember(mali, {
        group_id: String(fd.get("group_id") ?? ""),
        full_name: String(fd.get("full_name") ?? ""),
        phone: String(fd.get("phone") ?? "") || null,
        role: String(fd.get("role") ?? "member") || "member",
      });
      setStatus({ kind: "info", text: "Member added." });
      void refresh();
    } catch (err) { setStatus({ kind: "error", text: "addMember: " + (err as Error).message }); }
  }

  async function onOpenCycle(e: React.FormEvent) {
    e.preventDefault();
    if (!user) { setStatus({ kind: "error", text: "Sign in first." }); return; }
    const fd = new FormData(e.currentTarget as HTMLFormElement);
    try {
      await openMaliCycle(mali, {
        group_id: String(fd.get("group_id") ?? ""),
        name: String(fd.get("name") ?? ""),
        saving_type: Number(fd.get("saving_type")),
        contribution: Number(fd.get("contribution")),
        currency: String(fd.get("currency") ?? "XOF") || "XOF",
        pot_target: Number(fd.get("pot_target")) || null,
        is_rotating: fd.get("is_rotating") === "on",
        created_by: user.id,
      });
      setStatus({ kind: "info", text: "Cycle opened." });
      void refresh();
    } catch (err) { setStatus({ kind: "error", text: "openCycle: " + (err as Error).message }); }
  }

  async function onRecordContribution(e: React.FormEvent) {
    e.preventDefault();
    if (!user) { setStatus({ kind: "error", text: "Sign in first." }); return; }
    const fd = new FormData(e.currentTarget as HTMLFormElement);
    try {
      await recordMaliContribution(mali, {
        cycle_id: String(fd.get("cycle_id") ?? ""),
        member_id: String(fd.get("member_id") ?? ""),
        amount: Number(fd.get("amount")),
        channel_id: fd.get("channel_id") ? Number(fd.get("channel_id")) : null,
        ref_no: String(fd.get("ref_no") ?? "") || null,
      });
      setStatus({ kind: "info", text: "Contribution recorded." });
      void refresh();
    } catch (err) { setStatus({ kind: "error", text: "recordContribution: " + (err as Error).message }); }
  }

  const groupById = useMemo(() => new Map(groups.map((g) => [g.id, g])), [groups]);
  const cycleById = useMemo(() => new Map(cycles.map((c) => [c.id, c])), [cycles]);
  const memberById = useMemo(() => new Map(members.map((m) => [m.id, m])), [members]);
  const savingName = (id: number) => lookups?.savingTypes.find((s) => Number(s.id) === id)?.name ?? String(id);
  const channelName = (id: number | null) => lookups?.paymentChannels.find((c) => Number(c.id) === id)?.name ?? "—";

  return (
    <main style={{ fontFamily: "system-ui,sans-serif", padding: 24, maxWidth: 1080, color: "#e2e8f0", background: "#020617", minHeight: "100vh" }}>
      <h1 style={{ fontSize: 20, margin: "0 0 2px" }}>MALI Access Union · Group Savings — Live</h1>
      <p style={{ color: "#94a3b8", fontSize: 13, margin: "0 0 14px" }}>
        Store: <code style={codeChip}>vfkqjapegrhdsrlmmiih</code> · RLS on · Realtime{" "}
        {configured ? (live
          ? <span style={{ color: "#22c55e", fontWeight: 600 }}>● LIVE</span>
          : <span style={{ color: "#eab308", fontWeight: 600 }}>connecting…</span>)
          : <span style={{ color: "#f87171", fontWeight: 600 }}>not configured</span>}
        {" · "}
        {user ? <span style={{ color: "#4ade80" }}>signed in as {user.email ?? user.id.slice(0, 8)}</span> : <span style={{ color: "#94a3b8" }}>anonymous (writes need sign-in)</span>}
      </p>

      {!configured && (
        <div style={{ border: "1px solid #b91c1c", background: "#450a0a", borderRadius: 8, padding: 10, fontSize: 13, marginBottom: 14 }}>
          Missing NEXT_PUBLIC_MALI_SUPABASE_URL / NEXT_PUBLIC_MALI_SUPABASE_ANON_KEY — create <code>apps/web/.env.local</code>.
        </div>
      )}

      {status.kind === "error" ? (
        <div style={{ border: "1px solid #b91c1c", background: "#450a0a", borderRadius: 8, padding: 8, fontSize: 12, marginBottom: 14 }}>{status.text}</div>
      ) : (
        <div style={{ border: "1px solid #14532d", background: "#052e16", borderRadius: 8, padding: 8, fontSize: 12, marginBottom: 14 }}>{status.text}</div>
      )}

      {/* AUTH + LOOKUPS */}
      <section style={{ display: "grid", gap: 14, gridTemplateColumns: "repeat(auto-fit,minmax(300px,1fr))", marginBottom: 14 }}>
        <div style={{ border: "1px solid #334155", borderRadius: 8, padding: 12 }}>
          <h2 style={{ fontSize: 13, margin: "0 0 8px" }}>Account</h2>
          {user ? (
            <button onClick={signOut} style={{ ...btn, background: "#475569" }}>Sign out {user.email ?? ""}</button>
          ) : (
            <form onSubmit={signIn} style={{ display: "grid", gap: 8 }}>
              <div><label style={labelStyle}>Email</label><input name="email" type="email" required style={inputStyle} /></div>
              <div><label style={labelStyle}>Password</label><input name="password" type="password" required style={inputStyle} /></div>
              <div style={{ display: "flex", gap: 8 }}>
                <button type="submit" style={btn}>Sign in</button>
                <button onClick={signUp} style={{ ...btn, background: "#059669" }}>Sign up</button>
              </div>
            </form>
          )}
        </div>

        <div style={{ border: "1px solid #334155", borderRadius: 8, padding: 12 }}>
          <h2 style={{ fontSize: 13, margin: "0 0 8px" }}>Lookups (seeded)</h2>
          {lookups ? (
            <div style={{ display: "grid", gap: 6, fontSize: 12 }}>
              <div><strong style={{ color: "#94a3b8" }}>Saving types: </strong>{lookups.savingTypes.map((s) => s.name).join(", ")}</div>
              <div><strong style={{ color: "#94a3b8" }}>Cycle states: </strong>{lookups.cycleStates.map((s) => s.label).join(", ")}</div>
              <div><strong style={{ color: "#94a3b8" }}>Channels: </strong>{lookups.paymentChannels.map((c) => c.name).join(", ")}</div>
              <div><strong style={{ color: "#94a3b8" }}>Ethnic groups: </strong>{lookups.ethnicGroups.map((c) => c.name).join(", ")}</div>
            </div>
          ) : <p style={{ fontSize: 12, color: "#64748b" }}>…</p>}
        </div>
      </section>

      {/* WRITE FORMS */}
      <section style={{ display: "grid", gap: 14, gridTemplateColumns: "repeat(auto-fit,minmax(280px,1fr))", marginBottom: 14 }}>
        <form onSubmit={onCreateGroup} style={{ border: "1px solid #334155", borderRadius: 8, padding: 12 }}>
          <h2 style={{ fontSize: 13, margin: "0 0 8px" }}>1 · Create group</h2>
          <div style={{ display: "grid", gap: 8 }}>
            <div><label style={labelStyle}>Name</label><input name="name" required style={inputStyle} /></div>
            <div><label style={labelStyle}>Description</label><textarea name="description" rows={2} style={inputStyle} /></div>
            <div><label style={labelStyle}>Currency</label><input name="currency" defaultValue="XOF" style={inputStyle} /></div>
            <button type="submit" style={btn}>Create group</button>
          </div>
        </form>

        <form onSubmit={onAddMember} style={{ border: "1px solid #334155", borderRadius: 8, padding: 12 }}>
          <h2 style={{ fontSize: 13, margin: "0 0 8px" }}>2 · Add member</h2>
          <div style={{ display: "grid", gap: 8 }}>
            <div>
              <label style={labelStyle}>Group</label>
              <select name="group_id" required style={inputStyle}>
                {groups.map((g) => <option key={g.id} value={g.id}>{g.name}</option>)}
                {groups.length === 0 && <option value="">(create a group first)</option>}
              </select>
            </div>
            <div><label style={labelStyle}>Full name</label><input name="full_name" required style={inputStyle} /></div>
            <div><label style={labelStyle}>Phone</label><input name="phone" style={inputStyle} /></div>
            <div>
              <label style={labelStyle}>Role</label>
              <select name="role" defaultValue="member" style={inputStyle}>
                <option value="member">member</option><option value="president">president</option>
                <option value="treasurer">treasurer</option><option value="secretary">secretary</option>
              </select>
            </div>
            <button type="submit" style={btn}>Add member</button>
          </div>
        </form>

        <form onSubmit={onOpenCycle} style={{ border: "1px solid #334155", borderRadius: 8, padding: 12 }}>
          <h2 style={{ fontSize: 13, margin: "0 0 8px" }}>3 · Open cycle</h2>
          <div style={{ display: "grid", gap: 8 }}>
            <div>
              <label style={labelStyle}>Group</label>
              <select name="group_id" required style={inputStyle}>
                {groups.map((g) => <option key={g.id} value={g.id}>{g.name}</option>)}
                {groups.length === 0 && <option value="">(create a group first)</option>}
              </select>
            </div>
            <div><label style={labelStyle}>Cycle name</label><input name="name" required style={inputStyle} /></div>
            <div>
              <label style={labelStyle}>Saving type</label>
              <select name="saving_type" required style={inputStyle}>
                {(lookups?.savingTypes ?? []).map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
              <div><label style={labelStyle}>Contribution (XOF)</label><input name="contribution" type="number" min="1" required style={inputStyle} /></div>
              <div><label style={labelStyle}>Pot target</label><input name="pot_target" type="number" min="0" style={inputStyle} /></div>
            </div>
            <label style={{ fontSize: 12 }}><input name="is_rotating" type="checkbox" /> rotating pot</label>
            <button type="submit" style={btn}>Open cycle</button>
          </div>
        </form>

        <form onSubmit={onRecordContribution} style={{ border: "1px solid #334155", borderRadius: 8, padding: 12 }}>
          <h2 style={{ fontSize: 13, margin: "0 0 8px" }}>4 · Record contribution</h2>
          <div style={{ display: "grid", gap: 8 }}>
            <div>
              <label style={labelStyle}>Cycle</label>
              <select name="cycle_id" required style={inputStyle}>
                {cycles.map((c) => <option key={c.id} value={c.id}>{groupById.get(c.group_id)?.name ?? "?"} / {c.name}</option>)}
                {cycles.length === 0 && <option value="">(open a cycle first)</option>}
              </select>
            </div>
            <div>
              <label style={labelStyle}>Member</label>
              <select name="member_id" required style={inputStyle}>
                {members.filter((m) => m.is_active !== false).map((m) => <option key={m.id} value={m.id}>{m.full_name}</option>)}
                {members.length === 0 && <option value="">(add a member first)</option>}
              </select>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
              <div><label style={labelStyle}>Amount (XOF)</label><input name="amount" type="number" min="1" required style={inputStyle} /></div>
              <div>
                <label style={labelStyle}>Channel</label>
                <select name="channel_id" style={inputStyle}>
                  <option value="">—</option>
                  {(lookups?.paymentChannels ?? []).map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              </div>
            </div>
            <div><label style={labelStyle}>Ref no (mobile-money receipt)</label><input name="ref_no" style={inputStyle} /></div>
            <button type="submit" style={btn}>Record contribution</button>
          </div>
        </form>
      </section>

      {/* LIVE LISTS */}
      <section style={{ display: "grid", gap: 14, gridTemplateColumns: "repeat(auto-fit,minmax(420px,1fr))" }}>
        <div style={{ border: "1px solid #334155", borderRadius: 8, padding: 12 }}>
          <h2 style={{ fontSize: 13, margin: "0 0 8px" }}>Groups ({groups.length})</h2>
          <table style={{ width: "100%", fontSize: 12, borderCollapse: "collapse" }}>
            <thead><tr style={{ color: "#94a3b8", textAlign: "left" }}>
              <th style={{ padding: "4px 6px" }}>Name</th><th>Cur</th><th>Active</th><th>Created</th>
            </tr></thead>
            <tbody>
              {groups.map((g) => (
                <tr key={g.id} style={{ borderTop: "1px solid #1e293b" }}>
                  <td style={{ padding: "4px 6px" }}>{g.name}</td>
                  <td>{g.currency}</td>
                  <td>{g.is_active ? "yes" : "no"}</td>
                  <td style={{ color: "#64748b" }}>{g.created_at.slice(0, 10)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div style={{ border: "1px solid #334155", borderRadius: 8, padding: 12 }}>
          <h2 style={{ fontSize: 13, margin: "0 0 8px" }}>Members ({members.length})</h2>
          <table style={{ width: "100%", fontSize: 12, borderCollapse: "collapse" }}>
            <thead><tr style={{ color: "#94a3b8", textAlign: "left" }}>
              <th style={{ padding: "4px 6px" }}>Name</th><th>Group</th><th>Role</th><th>Phone</th>
            </tr></thead>
            <tbody>
              {members.map((m) => (
                <tr key={m.id} style={{ borderTop: "1px solid #1e293b" }}>
                  <td style={{ padding: "4px 6px" }}>{m.full_name}</td>
                  <td>{groupById.get(m.group_id)?.name ?? "?"}</td>
                  <td>{m.role}</td>
                  <td style={{ color: "#64748b" }}>{m.phone ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div style={{ border: "1px solid #334155", borderRadius: 8, padding: 12 }}>
          <h2 style={{ fontSize: 13, margin: "0 0 8px" }}>Cycles ({cycles.length})</h2>
          <table style={{ width: "100%", fontSize: 12, borderCollapse: "collapse" }}>
            <thead><tr style={{ color: "#94a3b8", textAlign: "left" }}>
              <th style={{ padding: "4px 6px" }}>Name</th><th>Group</th><th>Type</th><th>Contrib</th><th>Rotating</th>
            </tr></thead>
            <tbody>
              {cycles.map((c) => (
                <tr key={c.id} style={{ borderTop: "1px solid #1e293b" }}>
                  <td style={{ padding: "4px 6px" }}>{c.name}</td>
                  <td>{groupById.get(c.group_id)?.name ?? "?"}</td>
                  <td>{savingName(c.saving_type)}</td>
                  <td>{c.contribution} {c.currency}</td>
                  <td>{c.is_rotating ? "yes" : "no"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div style={{ border: "1px solid #334155", borderRadius: 8, padding: 12 }}>
          <h2 style={{ fontSize: 13, margin: "0 0 8px" }}>Contributions ({contributions.length})</h2>
          <table style={{ width: "100%", fontSize: 12, borderCollapse: "collapse" }}>
            <thead><tr style={{ color: "#94a3b8", textAlign: "left" }}>
              <th style={{ padding: "4px 6px" }}>Member</th><th>Cycle</th><th>Amount</th><th>Channel</th><th>Paid</th>
            </tr></thead>
            <tbody>
              {contributions.map((c) => (
                <tr key={c.id} style={{ borderTop: "1px solid #1e293b" }}>
                  <td style={{ padding: "4px 6px" }}>{memberById.get(c.member_id)?.full_name ?? "?"}</td>
                  <td>{cycleById.get(c.cycle_id)?.name ?? "?"}</td>
                  <td>{c.amount} {c.currency}</td>
                  <td>{channelName(c.channel_id)}</td>
                  <td style={{ color: "#64748b" }}>{c.paid_on}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}