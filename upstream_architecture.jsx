import { useState, useEffect, useRef } from "react";

const C = {
  navy: "#0d3b5e", water: "#1a6fa8", sky: "#2e86ab",
  flow: "#5bc8f5", mint: "#a8e6cf", mintLight: "#edfbf4",
  dark: "#0a0a0a", body: "#2c2c2c", dim: "#8a8a8a", faint: "#b0bac4",
  bg: "#f4f7fb", bgDeep: "#edf1f7", white: "#ffffff",
  green: "#059669", greenLight: "#ecfdf5",
  amber: "#d97706", amberLight: "#fffbeb",
  red: "#dc2626", redLight: "#fef2f2",
  purple: "#6d28d9", purpleLight: "#ede9fe",
};

const FONT = "'DM Sans', system-ui, sans-serif";
const DISPLAY = "'DM Serif Display', Georgia, serif";

// ── Node definitions ──────────────────────────────────────────────────────────
const NODES = {
  // Layer 0 — Facilities
  fac1: { id: "fac1", label: "Maplewood SD", sub: "Activated Sludge", layer: 0, col: 0, icon: "🏭", color: C.water },
  fac2: { id: "fac2", label: "Pinecrest WD", sub: "Extended Aeration", layer: 0, col: 1, icon: "🏭", color: C.water },
  fac3: { id: "fac3", label: "Ridgeline SD", sub: "MBR System", layer: 0, col: 2, icon: "🏭", color: C.water },
  // Layer 1 — Bridge / Connectors
  scada1: { id: "scada1", label: "OPC-DA Bridge", sub: "opcua · Modbus TCP", layer: 1, col: 0, icon: "⚡", color: C.sky },
  scada2: { id: "scada2", label: "OPC-DA Bridge", sub: "FactoryTalk historian", layer: 1, col: 1, icon: "⚡", color: C.sky },
  scada3: { id: "scada3", label: "Rev. Tunnel", sub: "No inbound firewall", layer: 1, col: 2, icon: "🔒", color: C.purple },
  // Layer 2 — Core infrastructure
  ingest: { id: "ingest", label: "Ingest API", sub: "FastAPI · /api/ingest", layer: 2, col: 0.5, icon: "📥", color: C.navy },
  db:     { id: "db",     label: "Supabase Postgres", sub: "metrics · observations · alerts", layer: 2, col: 1.5, icon: "🗄️", color: C.navy },
  // Layer 3 — AI layer
  brief:  { id: "brief",  label: "Briefing Agent", sub: "5:50 AM cron · streams to dashboard", layer: 3, col: 0, icon: "🧠", color: C.purple },
  anomaly:{ id: "anomaly",label: "Anomaly Detector", sub: "statistical baseline + LLM context", layer: 3, col: 1, icon: "📡", color: C.purple },
  onboard:{ id: "onboard",label: "Onboarding Agent", sub: "tag mapping · config generation", layer: 3, col: 2, icon: "🤝", color: C.purple },
  // Layer 4 — Dashboard + Operators
  dash:   { id: "dash",   label: "Upstream Dashboard", sub: "React · TanStack Query · 30s poll", layer: 4, col: 0.5, icon: "🖥️", color: C.green },
  ops:    { id: "ops",    label: "Operators + Board", sub: "mobile · alerts · briefings", layer: 4, col: 1.5, icon: "👤", color: C.green },
};

// ── Edges (flows) ─────────────────────────────────────────────────────────────
const EDGES = [
  // Facilities → bridges
  { from: "fac1", to: "scada1", label: "sensor tags", type: "data" },
  { from: "fac2", to: "scada2", label: "historian", type: "data" },
  { from: "fac3", to: "scada3", label: "tunnel", type: "secure" },
  // Bridges → ingest
  { from: "scada1", to: "ingest", label: "POST every 5m", type: "data" },
  { from: "scada2", to: "ingest", label: "POST every 5m", type: "data" },
  { from: "scada3", to: "ingest", label: "WS push", type: "secure" },
  // Ingest → DB
  { from: "ingest", to: "db", label: "normalize + store", type: "data" },
  // DB → AI agents
  { from: "db", to: "brief",   label: "24h window", type: "ai" },
  { from: "db", to: "anomaly", label: "real-time", type: "ai" },
  // Onboard → DB
  { from: "onboard", to: "db", label: "facility config", type: "ai" },
  // AI → dashboard
  { from: "brief",   to: "dash", label: "stream SSE", type: "ai" },
  { from: "anomaly", to: "dash", label: "alerts + context", type: "ai" },
  // DB → dashboard
  { from: "db", to: "dash", label: "React Query 30s", type: "data" },
  // Dashboard → operators
  { from: "dash", to: "ops", label: "web · mobile · SMS", type: "output" },
  // Operator feedback loop
  { from: "ops", to: "db", label: "observations · feedback", type: "feedback" },
];

const EDGE_COLORS = {
  data:     C.flow,
  secure:   C.purple,
  ai:       C.amber,
  output:   C.green,
  feedback: C.mint,
};

const LAYER_LABELS = [
  { label: "Water Utilities", sub: "Facilities running SCADA / PLCs", y: 0 },
  { label: "Bridge Layer", sub: "On-premise connectors (no inbound firewall change)", y: 1 },
  { label: "Core Infrastructure", sub: "Ingest API + Postgres (Supabase)", y: 2 },
  { label: "AI Agent Layer", sub: "Briefing · Anomaly · Onboarding agents", y: 3 },
  { label: "Operator Interface", sub: "Dashboard + mobile alerts", y: 4 },
];

// ── Detail cards ──────────────────────────────────────────────────────────────
const DETAILS = {
  fac1: {
    title: "Maplewood Sanitary District",
    items: [
      "Allen-Bradley PLCs via OPC-DA",
      "Tags: FIT-101.PV, AT-DO1.PV, AT-PH1.PV…",
      "5-min polling interval",
      "1 facility, 18 active tags",
    ],
    insight: "Your first pilot facility — real SCADA data, real operator feedback loop.",
  },
  scada1: {
    title: "OPC-DA Bridge",
    items: [
      "Python script: opcua + pymodbus",
      "Runs on facility VPS or Raspberry Pi",
      "Polls SCADA tags every 5 minutes",
      "Normalizes engineering units to SI",
      "POST to /api/ingest with facility_id",
    ],
    insight: "Easiest deployment. Requires one outbound port (443). No inbound firewall change.",
  },
  scada3: {
    title: "Reverse Tunnel Bridge",
    items: [
      "Bridge dials OUT to your WebSocket server",
      "Zero inbound firewall changes required",
      "Used when IT policy prohibits open ports",
      "Works through NAT / corporate proxies",
      "Reconnects automatically on drop",
    ],
    insight: "Best for facilities with post-Oldsmar security policies. The 'zero IT friction' pitch.",
  },
  ingest: {
    title: "Ingest API",
    items: [
      "FastAPI (Python) or Hono (TS edge)",
      "POST /api/ingest — validates schema",
      "Deduplicates & timestamps readings",
      "Writes to Supabase via edge function",
      "Rate-limited per facility_id",
    ],
    insight: "One endpoint, all facilities. The facility_id in every row is what separates tenants.",
  },
  db: {
    title: "Supabase Postgres",
    items: [
      "tables: facilities, metrics, alerts, observations",
      "Row-level security: operator sees own facility only",
      "Real-time subscriptions for live dashboard",
      "pg_cron for nightly baseline recalc",
      "Cross-facility queries for Upstream team only",
    ],
    insight: "Row-level security is your multi-tenancy. Each utility can't see each other's data. You can see all of it — that's your moat.",
  },
  brief: {
    title: "Briefing Agent",
    items: [
      "Cron job: 5:50 AM local facility time",
      "Context: 24h metrics + active alerts + weather",
      "Model: claude-sonnet-4-6 streaming",
      "Prompt enforces citations (no hallucination)",
      "Stored in DB, served on demand via SSE",
    ],
    insight: "Never let the agent make factual claims it can't source to a DB row. Every number in the briefing must trace back to your data.",
  },
  anomaly: {
    title: "Anomaly Detector",
    items: [
      "Stage 1: Statistical baseline (rolling percentiles)",
      "Stage 2: Deviation flags (z-score > 2.5)",
      "Stage 3: LLM enriches with process context",
      "Operator feedback updates confidence score",
      "Alert fires immediately, AI context arrives +30s",
    ],
    insight: "Never gate the alert on the LLM response. Raw alert goes out in <60s. AI context follows. Latency kills trust.",
  },
  onboard: {
    title: "Onboarding Agent",
    items: [
      "Conversational wizard: 'What's your DO tag called?'",
      "Agent maps answers → standard schema",
      "Proposes guardrail defaults from facility type",
      "Human review step before any config commit",
      "Generates bridge config YAML automatically",
    ],
    insight: "Human-in-the-loop is non-negotiable here. The agent proposes, a human approves. Never autonomous config changes to SCADA.",
  },
  dash: {
    title: "Upstream Dashboard",
    items: [
      "React 18 + Vite + TanStack Query",
      "30s polling via /api/metrics/live",
      "Zustand: UI state + facility state + agent state",
      "Recharts: all time series, trends",
      "Deployed to Vercel — auto-deploys from main",
    ],
    insight: "The dashboard is the trust interface. Every design decision should make operators more confident in the data, not just more informed.",
  },
  ops: {
    title: "Operators + Board",
    items: [
      "Operators: daily obs log, alert confirmation",
      "Board: public dashboard URL (no login)",
      "On-call: SMS alert within 60s of detection",
      "Mobile: 3-second status check on any device",
      "Feedback loop: every dismiss/confirm trains trust score",
    ],
    insight: "The operator feedback loop is your moat. 30 days of confirmations at a facility makes your alerts specific to their plant behavior.",
  },
};

// ── Layout math ───────────────────────────────────────────────────────────────
const W = 900, H = 620;
const LAYER_H = H / 5;
const COL_W = W / 3;

function nodePos(node) {
  const x = COL_W * node.col + COL_W / 2;
  const y = LAYER_H * (4 - node.layer) + LAYER_H / 2;
  return { x, y };
}

// ── Animated particle on path ─────────────────────────────────────────────────
function Particle({ x1, y1, x2, y2, color, delay = 0, type }) {
  const [t, setT] = useState(delay / 3);
  const animRef = useRef(null);

  useEffect(() => {
    let start = null;
    const duration = 2200 + Math.random() * 800;
    function tick(ts) {
      if (!start) start = ts - (delay * duration);
      const elapsed = (ts - start) % duration;
      setT(elapsed / duration);
      animRef.current = requestAnimationFrame(tick);
    }
    animRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(animRef.current);
  }, [delay]);

  const cx = x1 + (x2 - x1) * t;
  const cy = y1 + (y2 - y1) * t;

  return (
    <circle
      cx={cx} cy={cy} r={type === "feedback" ? 3 : 3.5}
      fill={color}
      opacity={0.85}
      style={{ filter: `drop-shadow(0 0 3px ${color})` }}
    />
  );
}

// ── Edge component ────────────────────────────────────────────────────────────
function Edge({ edge, nodes, isActive, onHover }) {
  const from = nodePos(nodes[edge.from]);
  const to   = nodePos(nodes[edge.to]);
  const color = EDGE_COLORS[edge.type];
  const mid = { x: (from.x + to.x) / 2, y: (from.y + to.y) / 2 };

  // slight curve
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const ctrl = { x: mid.x - dy * 0.15, y: mid.y + dx * 0.15 };
  const path = `M ${from.x} ${from.y} Q ${ctrl.x} ${ctrl.y} ${to.x} ${to.y}`;

  return (
    <g>
      {/* glow */}
      <path d={path} fill="none" stroke={color} strokeWidth={isActive ? 4 : 2}
        opacity={isActive ? 0.6 : 0.2} strokeLinecap="round"
        style={{ filter: isActive ? `drop-shadow(0 0 6px ${color})` : undefined }} />
      {/* solid line */}
      <path d={path} fill="none" stroke={color} strokeWidth={isActive ? 2 : 1}
        opacity={isActive ? 0.9 : 0.35} strokeLinecap="round"
        strokeDasharray={edge.type === "feedback" ? "6 4" : undefined} />
      {/* particles */}
      {[0, 0.33, 0.66].map((d, i) => (
        <Particle key={i} x1={from.x} y1={from.y} x2={to.x} y2={to.y}
          color={color} delay={d} type={edge.type} />
      ))}
      {/* label on hover */}
      {isActive && (
        <text x={mid.x} y={mid.y - 8} textAnchor="middle" fontSize={10}
          fill={color} fontFamily={FONT} fontWeight={700}
          style={{ filter: "drop-shadow(0 1px 2px rgba(0,0,0,0.4))" }}>
          {edge.label}
        </text>
      )}
      {/* invisible hover zone */}
      <path d={path} fill="none" stroke="transparent" strokeWidth={18}
        onMouseEnter={onHover} style={{ cursor: "pointer" }} />
    </g>
  );
}

// ── Node component ────────────────────────────────────────────────────────────
function Node({ node, isSelected, isHighlighted, onClick }) {
  const { x, y } = nodePos(node);
  const w = 110, h = 52;
  const isLarge = node.layer === 4 || node.layer === 2;
  const nw = isLarge ? 130 : w;
  const color = node.color;
  const selected = isSelected;

  return (
    <g
      transform={`translate(${x - nw/2}, ${y - h/2})`}
      onClick={onClick}
      style={{ cursor: "pointer" }}
    >
      {/* glow */}
      {selected && (
        <rect x={-4} y={-4} width={nw + 8} height={h + 8} rx={14}
          fill="none" stroke={color} strokeWidth={2} opacity={0.5}
          style={{ filter: `drop-shadow(0 0 10px ${color})` }} />
      )}
      {/* card */}
      <rect x={0} y={0} width={nw} height={h} rx={12}
        fill={selected ? color : C.white}
        stroke={isHighlighted ? color : "rgba(13,59,94,0.12)"}
        strokeWidth={selected ? 0 : 1.5}
        style={{
          filter: selected
            ? `drop-shadow(0 4px 20px ${color}60)`
            : "drop-shadow(0 2px 8px rgba(13,59,94,0.08))",
        }}
      />
      {/* icon */}
      <text x={10} y={26} fontSize={14} dominantBaseline="middle" fontFamily={FONT}>
        {node.icon}
      </text>
      {/* label */}
      <text x={29} y={20} fontSize={10.5} fontWeight={700} fontFamily={FONT}
        fill={selected ? "#fff" : C.dark}>
        {node.label}
      </text>
      {/* sub */}
      <text x={29} y={34} fontSize={8.5} fontFamily={FONT}
        fill={selected ? "rgba(255,255,255,0.7)" : C.faint}>
        {node.sub}
      </text>
    </g>
  );
}

// ── Legend ────────────────────────────────────────────────────────────────────
function Legend() {
  const items = [
    { color: C.flow,    label: "SCADA data flow" },
    { color: C.purple,  label: "Secure / encrypted" },
    { color: C.amber,   label: "AI agent call" },
    { color: C.green,   label: "Operator output" },
    { color: C.mint,    label: "Feedback loop" },
  ];
  return (
    <div style={{ display: "flex", gap: 18, flexWrap: "wrap" }}>
      {items.map(({ color, label }) => (
        <div key={label} style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <div style={{ width: 24, height: 2.5, background: color, borderRadius: 2, boxShadow: `0 0 4px ${color}` }} />
          <span style={{ fontFamily: FONT, fontSize: 11, color: C.dim }}>{label}</span>
        </div>
      ))}
    </div>
  );
}

// ── Detail Panel ──────────────────────────────────────────────────────────────
function DetailPanel({ nodeId, onClose }) {
  const detail = DETAILS[nodeId];
  const node = NODES[nodeId];
  if (!detail || !node) return null;

  return (
    <div style={{
      width: 300, background: C.white, borderRadius: 18,
      border: `1px solid rgba(13,59,94,0.10)`,
      boxShadow: "0 8px 40px rgba(13,59,94,0.14)",
      overflow: "hidden", flexShrink: 0,
    }}>
      {/* header */}
      <div style={{
        background: `linear-gradient(135deg, ${node.color}ee, ${node.color}99)`,
        padding: "18px 20px", position: "relative",
      }}>
        <div style={{ fontSize: 24, marginBottom: 6 }}>{node.icon}</div>
        <div style={{ fontFamily: DISPLAY, fontSize: 16, color: "#fff", lineHeight: 1.2 }}>{detail.title}</div>
        <button onClick={onClose} style={{
          position: "absolute", top: 14, right: 14, background: "rgba(255,255,255,0.2)",
          border: "none", borderRadius: 8, width: 26, height: 26, cursor: "pointer",
          color: "#fff", fontSize: 14, fontFamily: FONT, fontWeight: 700,
          display: "flex", alignItems: "center", justifyContent: "center",
        }}>×</button>
      </div>
      {/* items */}
      <div style={{ padding: "16px 20px" }}>
        {detail.items.map((item, i) => (
          <div key={i} style={{
            display: "flex", gap: 8, marginBottom: 9, alignItems: "flex-start",
          }}>
            <span style={{
              width: 5, height: 5, borderRadius: "50%", background: node.color,
              flexShrink: 0, marginTop: 5,
            }} />
            <span style={{ fontFamily: FONT, fontSize: 12, color: C.body, lineHeight: 1.55 }}>{item}</span>
          </div>
        ))}
        {/* insight */}
        <div style={{
          background: `${node.color}12`, borderRadius: 10,
          padding: "10px 14px", marginTop: 12,
          borderLeft: `3px solid ${node.color}`,
        }}>
          <div style={{ fontFamily: FONT, fontSize: 10, fontWeight: 800, color: node.color, marginBottom: 4, textTransform: "uppercase", letterSpacing: "0.07em" }}>Key Insight</div>
          <p style={{ fontFamily: FONT, fontSize: 11, color: C.body, lineHeight: 1.65, margin: 0 }}>{detail.insight}</p>
        </div>
      </div>
    </div>
  );
}

// ── Layer strip ───────────────────────────────────────────────────────────────
function LayerStrip({ label, sub, y }) {
  const pxY = LAYER_H * (4 - y);
  return (
    <g>
      <rect x={0} y={pxY} width={W} height={LAYER_H}
        fill={y % 2 === 0 ? "rgba(13,59,94,0.025)" : "rgba(13,59,94,0.015)"} />
      <text x={8} y={pxY + 14} fontSize={9.5} fontWeight={800} fontFamily={FONT}
        fill={C.faint} textTransform="uppercase" letterSpacing="0.06em">
        {label.toUpperCase()}
      </text>
      <text x={8} y={pxY + 26} fontSize={9} fontFamily={FONT} fill={`${C.faint}bb`}>
        {sub}
      </text>
    </g>
  );
}

// ── Main App ──────────────────────────────────────────────────────────────────
export default function App() {
  const [selected, setSelected] = useState(null);
  const [hoveredEdge, setHoveredEdge] = useState(null);
  const [activeView, setActiveView] = useState("architecture");

  const handleNodeClick = (id) => setSelected(selected === id ? null : id);

  // Get edges connected to selected node
  const connectedEdges = selected
    ? new Set(EDGES.filter(e => e.from === selected || e.to === selected).map(e => `${e.from}-${e.to}`))
    : new Set();
  const connectedNodes = selected
    ? new Set(EDGES.filter(e => e.from === selected || e.to === selected).flatMap(e => [e.from, e.to]))
    : new Set();

  return (
    <div style={{ minHeight: "100vh", background: C.bg, fontFamily: FONT, padding: 0 }}>
      {/* inject font */}
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700;800&family=DM+Serif+Display:ital@0;1&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { background: ${C.bg}; }
      `}</style>

      {/* Header */}
      <div style={{
        background: `linear-gradient(135deg, ${C.navy} 0%, ${C.water} 100%)`,
        padding: "22px 32px 20px",
        display: "flex", justifyContent: "space-between", alignItems: "center",
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <svg width={28} height={28} viewBox="0 0 32 32" fill="none">
            <rect width="32" height="32" rx="8" fill="rgba(255,255,255,0.15)" />
            <path d="M5 22 C9 17, 13 25, 17 19 C21 13, 26 22, 26 22" stroke={C.flow} strokeWidth="2.5" strokeLinecap="round" fill="none" />
            <circle cx="16" cy="11" r="3.5" fill="rgba(255,255,255,0.85)" />
          </svg>
          <div>
            <div style={{ fontFamily: FONT, fontWeight: 900, fontSize: 18, color: "#fff", letterSpacing: "-0.04em" }}>upstream</div>
            <div style={{ fontFamily: FONT, fontSize: 11, color: "rgba(255,255,255,0.55)", marginTop: 1 }}>System Architecture</div>
          </div>
        </div>

        {/* View switcher */}
        <div style={{ display: "flex", gap: 6, background: "rgba(255,255,255,0.12)", padding: 4, borderRadius: 12 }}>
          {[["architecture", "Architecture"], ["dataflow", "Data Flow"], ["agents", "AI Agents"]].map(([k, label]) => (
            <button key={k} onClick={() => setActiveView(k)} style={{
              padding: "7px 16px", borderRadius: 9, border: "none", cursor: "pointer",
              fontFamily: FONT, fontSize: 12, fontWeight: 700,
              background: activeView === k ? "rgba(255,255,255,0.95)" : "transparent",
              color: activeView === k ? C.navy : "rgba(255,255,255,0.7)",
            }}>
              {label}
            </button>
          ))}
        </div>

        <div style={{ fontFamily: FONT, fontSize: 12, color: "rgba(255,255,255,0.5)" }}>
          Click any node to explore
        </div>
      </div>

      {/* Main canvas */}
      <div style={{ display: "flex", gap: 0, alignItems: "flex-start" }}>
        <div style={{ flex: 1, padding: "20px 24px 0" }}>
          {activeView === "architecture" && (
            <>
              <div style={{ marginBottom: 12 }}><Legend /></div>
              <div style={{
                background: C.white, borderRadius: 18,
                border: "1px solid rgba(13,59,94,0.10)",
                boxShadow: "0 2px 8px rgba(13,59,94,0.07)",
                overflow: "hidden",
              }}>
                <svg width="100%" viewBox={`0 0 ${W} ${H}`} style={{ display: "block" }}>
                  {/* Layer backgrounds */}
                  {LAYER_LABELS.map(l => <LayerStrip key={l.y} {...l} />)}

                  {/* Edges */}
                  {EDGES.map(edge => {
                    const key = `${edge.from}-${edge.to}`;
                    const isActive = hoveredEdge === key || connectedEdges.has(key);
                    return (
                      <Edge key={key} edge={edge} nodes={NODES}
                        isActive={isActive}
                        onHover={() => setHoveredEdge(key)}
                      />
                    );
                  })}
                  <rect width={W} height={H} fill="transparent"
                    onMouseLeave={() => setHoveredEdge(null)} />

                  {/* Nodes */}
                  {Object.values(NODES).map(node => (
                    <Node key={node.id} node={node}
                      isSelected={selected === node.id}
                      isHighlighted={connectedNodes.has(node.id)}
                      onClick={() => handleNodeClick(node.id)}
                    />
                  ))}
                </svg>
              </div>
            </>
          )}

          {activeView === "dataflow" && (
            <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
              <div style={{ fontFamily: DISPLAY, fontSize: 22, color: C.dark }}>Sensor tag → Operator alert <em>in 60 seconds</em></div>
              <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                {[
                  { step: "01", label: "SCADA tag fires", detail: "DO sensor reads 1.4 mg/L @ facility", color: C.water, icon: "📡" },
                  { step: "02", label: "Bridge polls & ships", detail: "Python script reads OPC tag, normalizes to mg/L, POSTs to /api/ingest", color: C.sky, icon: "⚡" },
                  { step: "03", label: "API validates & stores", detail: "FastAPI deduplicates, timestamps, writes to Supabase metrics table", color: C.navy, icon: "📥" },
                  { step: "04", label: "Statistical anomaly detector fires", detail: "Rolling percentile check: 1.4 is 2.8σ below 30-day baseline of 2.3 mg/L", color: C.amber, icon: "📊" },
                  { step: "05", label: "LLM enriches alert", detail: "Claude reads: DO trend, SVI trend, current flow, weather. Writes: 'Aeration underperforming — check blower output'", color: C.purple, icon: "🧠" },
                  { step: "06", label: "Alert fires (< 60s)", detail: "SMS + app push. Raw alert first. LLM context arrives +30s. Never gated on AI.", color: C.red, icon: "🚨" },
                  { step: "07", label: "Operator responds", detail: "Confirms or dismisses alert. Feedback updates confidence score. Trust score improves.", color: C.green, icon: "👤" },
                  { step: "08", label: "Feedback stored", detail: "Confirmation written to DB. Alert accuracy metric updated. Baseline recalibrated overnight.", color: C.mint, icon: "🔄" },
                ].map((s, i) => (
                  <div key={s.step} style={{
                    display: "flex", gap: 16, padding: "14px 20px", background: C.white,
                    borderRadius: 14, border: "1px solid rgba(13,59,94,0.08)",
                    boxShadow: "0 1px 4px rgba(13,59,94,0.06)",
                    alignItems: "center",
                  }}>
                    <div style={{
                      width: 36, height: 36, borderRadius: 10, background: s.color,
                      display: "flex", alignItems: "center", justifyContent: "center",
                      fontSize: 18, flexShrink: 0,
                      boxShadow: `0 2px 8px ${s.color}40`,
                    }}>
                      {s.icon}
                    </div>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontFamily: FONT, fontWeight: 700, fontSize: 13, color: C.dark }}>
                        <span style={{ fontFamily: FONT, fontSize: 10, fontWeight: 800, color: s.color, marginRight: 8, letterSpacing: "0.04em" }}>{s.step}</span>
                        {s.label}
                      </div>
                      <div style={{ fontFamily: FONT, fontSize: 11, color: C.dim, marginTop: 3, lineHeight: 1.5 }}>{s.detail}</div>
                    </div>
                    {i < 7 && (
                      <div style={{ fontSize: 16, color: C.faint }}>↓</div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {activeView === "agents" && (
            <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
              <div style={{ fontFamily: DISPLAY, fontSize: 22, color: C.dark }}>Three agents, three <em>distinct jobs</em></div>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 14 }}>
                {[
                  {
                    icon: "🧠", title: "Briefing Agent", color: C.purple,
                    when: "5:50 AM cron, every day",
                    input: ["Last 24h of all sensor readings", "Active alerts + confidence scores", "7-day observation log", "Weather forecast (rain → flow surge)"],
                    output: ["Streaming morning briefing text", "Stored in DB, served on demand", "Operator reads on open"],
                    rule: "Every factual claim must cite a DB row. No hallucinated process advice.",
                    type: "Single-turn inference",
                  },
                  {
                    icon: "📡", title: "Anomaly Detector", color: C.amber,
                    when: "Real-time, triggered on ingest",
                    input: ["New sensor reading", "30-day rolling baseline", "Current alert queue", "Cross-facility patterns (you only)"],
                    output: ["Raw alert (< 60s, no AI)", "LLM context enrichment (+30s)", "Confidence score update", "Operator feedback loop"],
                    rule: "NEVER gate the alert on LLM response. Raw alert first, AI context follows.",
                    type: "Hybrid: stats + LLM",
                  },
                  {
                    icon: "🤝", title: "Onboarding Agent", color: C.water,
                    when: "New facility onboarding session",
                    input: ["Operator answers (natural language)", "Raw historian export (optional)", "Facility type + design flow", "SCADA system make/model"],
                    output: ["Tag mapping proposals", "Guardrail defaults by facility type", "Bridge config YAML", "→ Human approves before commit"],
                    rule: "Human-in-the-loop always. Agent proposes, human approves. Zero autonomous SCADA writes.",
                    type: "Conversational + tool use",
                  },
                ].map(agent => (
                  <div key={agent.title} style={{
                    background: C.white, borderRadius: 18,
                    border: "1px solid rgba(13,59,94,0.10)",
                    overflow: "hidden",
                    boxShadow: "0 2px 8px rgba(13,59,94,0.07)",
                  }}>
                    <div style={{ padding: "20px 20px 14px", background: `linear-gradient(135deg, ${agent.color}22, ${agent.color}0a)`, borderBottom: "1px solid rgba(13,59,94,0.07)" }}>
                      <div style={{ fontSize: 28, marginBottom: 8 }}>{agent.icon}</div>
                      <div style={{ fontFamily: DISPLAY, fontSize: 17, color: C.dark }}>{agent.title}</div>
                      <div style={{ fontFamily: FONT, fontSize: 10, fontWeight: 700, color: agent.color, marginTop: 4, textTransform: "uppercase", letterSpacing: "0.06em" }}>{agent.type}</div>
                    </div>
                    <div style={{ padding: "14px 20px" }}>
                      <div style={{ fontFamily: FONT, fontSize: 10, fontWeight: 800, color: C.faint, textTransform: "uppercase", letterSpacing: "0.06em", marginBottom: 8 }}>Triggers</div>
                      <div style={{ fontFamily: FONT, fontSize: 11, color: C.water, background: `${agent.color}12`, borderRadius: 8, padding: "6px 10px", marginBottom: 12 }}>{agent.when}</div>
                      <div style={{ fontFamily: FONT, fontSize: 10, fontWeight: 800, color: C.faint, textTransform: "uppercase", letterSpacing: "0.06em", marginBottom: 6 }}>Input Context</div>
                      {agent.input.map(i => (
                        <div key={i} style={{ display: "flex", gap: 6, marginBottom: 5, alignItems: "flex-start" }}>
                          <span style={{ width: 4, height: 4, borderRadius: "50%", background: agent.color, flexShrink: 0, marginTop: 5 }} />
                          <span style={{ fontFamily: FONT, fontSize: 11, color: C.body, lineHeight: 1.5 }}>{i}</span>
                        </div>
                      ))}
                      <div style={{ fontFamily: FONT, fontSize: 10, fontWeight: 800, color: C.faint, textTransform: "uppercase", letterSpacing: "0.06em", margin: "10px 0 6px" }}>Output</div>
                      {agent.output.map(o => (
                        <div key={o} style={{ display: "flex", gap: 6, marginBottom: 5, alignItems: "flex-start" }}>
                          <span style={{ fontFamily: FONT, fontSize: 11, color: o.startsWith("→") ? agent.color : C.green, lineHeight: 1.5, fontWeight: o.startsWith("→") ? 700 : 400 }}>
                            {o.startsWith("→") ? o : `→ ${o}`}
                          </span>
                        </div>
                      ))}
                      <div style={{
                        background: `${agent.color}14`, borderRadius: 10,
                        padding: "10px 12px", marginTop: 12,
                        borderLeft: `3px solid ${agent.color}`,
                      }}>
                        <div style={{ fontFamily: FONT, fontSize: 10, fontWeight: 800, color: agent.color, marginBottom: 3, textTransform: "uppercase", letterSpacing: "0.06em" }}>Safety Rule</div>
                        <p style={{ fontFamily: FONT, fontSize: 11, color: C.body, lineHeight: 1.6, margin: 0 }}>{agent.rule}</p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Detail panel */}
        <div style={{ padding: "20px 24px 0 0", width: selected ? 324 : 0, transition: "width 0.25s", overflow: "hidden", flexShrink: 0 }}>
          {selected && <DetailPanel nodeId={selected} onClose={() => setSelected(null)} />}
        </div>
      </div>

      {/* Bottom hint */}
      <div style={{ padding: "14px 24px 24px", display: "flex", justifyContent: "center" }}>
        <div style={{ fontFamily: FONT, fontSize: 11, color: C.faint, display: "flex", alignItems: "center", gap: 6 }}>
          <span style={{ fontSize: 14 }}>💡</span>
          {activeView === "architecture"
            ? "Click any node for details on that component. Click an edge path to see the data it carries."
            : activeView === "dataflow"
            ? "This is the critical path from a sensor reading to an operator getting an SMS alert."
            : "Each agent has a specific safety rule. AI helps — it never acts autonomously on SCADA systems."}
        </div>
      </div>
    </div>
  );
}
