"use client";

import { useEffect, useState } from "react";
import LiveActivity from "./LiveActivity";
import Dashboard from "./Dashboard";
import { paceOverview } from "../lib/pace";

const ENERGY = ["Low", "Okay", "Good"];
const SORENESS = ["None", "Some", "High"];
const EFFORT = ["Easy", "About right", "Too hard", "Skipped"];
const ROUTINES = ["None selected", "Meal routine", "Drink routine", "Rest routine"];
const minutes = seconds => seconds == null ? "Choose later" : Math.round(seconds / 60) + " min";
const stamp = seconds => new Date(seconds * 1000).toISOString().replace("T", " ").slice(0, 16) + " UTC";

export default function SharedDashboard({ initialPace, ...gutProps }) {
  const [tab, setTab] = useState("overview");
  const [pace, setPace] = useState(initialPace);
  const [nutrition, setNutrition] = useState(gutProps.initialSessions);
  const [status, setStatus] = useState("Ready");
  useEffect(() => {
    let cancelled = false;
    async function refresh() {
      try {
        const responses = await Promise.all([
          fetch("/api/pace-sessions", { cache: "no-store" }),
          fetch("/api/sessions", { cache: "no-store" }),
        ]);
        if (responses.some(response => !response.ok)) throw new Error();
        const [activity, fuel] = await Promise.all(responses.map(response => response.json()));
        if (!cancelled) {
          setPace(activity.sessions);
          setNutrition(fuel.sessions);
          setStatus("Connected");
        }
      } catch {
        if (!cancelled) setStatus("Connection unavailable — showing last update");
      }
    }
    refresh();
    const timer = setInterval(refresh, 5000);
    return () => { cancelled = true; clearInterval(timer); };
  }, []);
  const overview = paceOverview(pace);
  const latest = overview.latest;
  const fuelLive = nutrition.filter(session => !session.demo);
  return (
    <>
      <header className="shared-header">
        <div><p className="eyebrow">PacePilot + Gut Train</p><h1>Your activity and fueling</h1></div>
        <p role="status">{status}</p>
      </header>
      <nav className="shared-nav" aria-label="Dashboard sections">
        {["overview", "recovery", "nutrition"].map(value => (
          <button key={value} type="button" aria-pressed={tab === value} onClick={() => setTab(value)}>
            {value[0].toUpperCase() + value.slice(1)}
          </button>
        ))}
      </nav>
      <p className="sharing-note">Shared hackathon demo. Uploaded activity and summaries are visible to anyone with this URL. Keep watch sharing off for private sessions.</p>
      <div className="shared-main"><LiveActivity /></div>
      {tab === "nutrition" ? <Dashboard {...gutProps} initialSessions={nutrition} /> : (
        <main className="shared-main">
          <section className="shared-cards" aria-label="Live session totals">
            <article><h2>Sessions completed</h2><strong>{overview.completed}</strong><p>of {overview.sessions} PacePilot sessions</p></article>
            <article><h2>Session minutes</h2><strong>{overview.minutes}</strong><p>Unpaused time, including walking</p></article>
            <article><h2>Fueling sessions</h2><strong>{fuelLive.length}</strong><p>Gut Train sessions shared from the watch</p></article>
          </section>
          <section className="shared-panel">
            <h2>{tab === "recovery" ? "Your recovery check-in" : "Your next session"}</h2>
            {latest ? (
              <>
                <p className="shared-goal">{minutes(latest.nextGoalSec)}</p>
                <p>Selected on the watch after your last session.</p>
                <dl className="shared-facts">
                  <div><dt>Energy before</dt><dd>{ENERGY[latest.energy] ?? "Not recorded"}</dd></div>
                  <div><dt>Soreness before</dt><dd>{SORENESS[latest.soreness] ?? "Not recorded"}</dd></div>
                  <div><dt>Session felt</dt><dd>{EFFORT[latest.effort] ?? "Not recorded"}</dd></div>
                  <div><dt>After-session routine</dt><dd>{ROUTINES[latest.routine] ?? "Not recorded"}</dd></div>
                </dl>
                <p>These are your reported check-ins and choices. Adjust your next session on the watch.</p>
              </>
            ) : <p>Complete a LIVE PacePilot session, confirm your feedback, and opt in to sharing to see it here.</p>}
          </section>
          <section className="shared-panel">
            <h2>Session history</h2>
            {pace.length === 0 ? <p>No PacePilot sessions shared yet.</p> : (
              <div className="shared-table"><table>
                <thead><tr><th>Session</th><th>Duration</th><th>Estimated moving</th><th>Felt</th><th>Outcome</th></tr></thead>
                <tbody>{pace.map(session => <tr key={session.mode + ":" + session.sessionId}>
                  <td>{stamp(session.endedAt)}{session.mode === "DEMO" && " · Demo"}</td>
                  <td>{minutes(session.sessionSec)}</td><td>{minutes(session.movingSec)}</td>
                  <td>{EFFORT[session.effort] ?? "Not recorded"}</td>
                  <td>{session.goalMet ? "Goal met" : "Ended early"}</td>
                </tr>)}</tbody>
              </table></div>
            )}
          </section>
          <section className="shared-panel">
            <h2>Fueling and tolerance</h2>
            {nutrition.length === 0 ? <p>Log food, drinks, and gut comfort in Gut Train, then share the summary.</p> : (
              <div className="shared-table"><table>
                <thead><tr><th>Session</th><th>Food</th><th>Carbs logged</th><th>Drink logged</th><th>Gut comfort</th><th>Next plan</th></tr></thead>
                <tbody>{nutrition.slice(0, 20).map((session, index) => <tr key={session.at + "-" + index}>
                  <td>{stamp(session.at)}{session.demo && " · Demo"}</td>
                  <td>{session.foodType ?? "Not recorded"}
                    {session.fuelLog?.length > 0 && <details><summary>Feed times</summary><ul>{session.fuelLog.map((feed, i) => <li key={i}>{minutes(feed.atS)} · {feed.carbsG} g · {feed.kind}</li>)}</ul></details>}
                  </td>
                  <td>{session.carbsG} g</td><td>{session.fluidMl ?? "—"} ml</td>
                  <td>{session.gutRating}/5{session.gutEvents > 0 && " · discomfort flagged"}</td>
                  <td>{session.nextTargetGph} g/h · {session.targetConfirmed ? "user confirmed" : "legacy suggestion"}</td>
                </tr>)}</tbody>
              </table></div>
            )}
          </section>
        </main>
      )}
    </>
  );
}
