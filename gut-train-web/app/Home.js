"use client";

import { useCallback, useEffect, useState } from "react";

// The "Today" screen. It answers four questions, top to bottom:
// what is my goal, what is suggested today and why, is my watch sending
// data, and how consistent have I been.

const ACTIVITY = { walk: "walk", run_walk: "run/walk", cycle: "ride" };
const ACTIVITY_CHOICES = [["walk", "Walking"], ["run_walk", "Run/walk"], ["cycle", "Cycling"]];
const DAYS = [["mon", "Mon"], ["tue", "Tue"], ["wed", "Wed"], ["thu", "Thu"], ["fri", "Fri"], ["sat", "Sat"], ["sun", "Sun"]];
const EXPERIENCE = [["new", "New to regular activity"], ["returning", "Getting back into it"], ["regular", "Active most weeks"]];
const DAY_ACTIVITY = [["mostly_sitting", "Mostly sitting"], ["on_feet", "On my feet a lot"], ["physical_job", "Physical job"]];
const STATUS = { suggested: "Suggested", accepted: "Accepted", adjusted: "Adjusted by you", rescheduled: "Moved", rest_chosen: "Rest chosen", done: "Done" };
const WATCH_STATE = {
  waiting: ["Waiting for watch data", "off"],
  active: ["Receiving live activity", "on"],
  paused: ["Workout paused", "on"],
  stale: ["Connection stale or interrupted", "off"],
  completed: ["Workout completed", "off"],
};
const APPS = [["pacepilot", "PacePilot"], ["guttrain", "Gut Train"]];
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const EMPTY_PROFILE = {
  goal: "stay_active", activities: ["walk"], days: ["mon", "wed", "fri"], durationMin: 20, experience: "new",
  ageYears: "", heightCm: "", weightKg: "", sexForEstimate: "", dayActivity: "", shareToWatch: false,
};

function localDate(offsetDays = 0) {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function shortDate(value) {
  const [, month, day] = value.split("-").map(Number);
  return `${MONTHS[month - 1]} ${day}`;
}
function ago(seconds) {
  if (seconds < 60) return `${Math.max(0, Math.floor(seconds))} seconds ago`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)} min ago`;
  return `${Math.floor(seconds / 3600)} h ago`;
}
function describe(suggestion) {
  if (suggestion.kind === "rest") {
    return suggestion.durationMin > 0 ? `Rest, or an easy ${suggestion.durationMin} min ${ACTIVITY[suggestion.activity] ?? "walk"}` : "Rest day";
  }
  return `${suggestion.durationMin} min easy ${ACTIVITY[suggestion.activity] ?? "session"}`;
}
const optionalNumber = value => (value === "" || value == null ? null : Number(value));

export default function Home() {
  const [demo, setDemo] = useState(false);
  const [data, setData] = useState(null);
  const [offline, setOffline] = useState(false);
  const [tick, setTick] = useState(0);          // seconds since the last server answer
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(EMPTY_PROFILE);
  const [adjusting, setAdjusting] = useState(false);
  const [change, setChange] = useState({ durationMin: 20, activity: "walk", toDate: "" });
  const [meal, setMeal] = useState({ kcal: "", label: "" });
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  const query = useCallback(() => `mode=${demo ? "demo" : "real"}&today=${localDate()}`, [demo]);

  const load = useCallback(async () => {
    try {
      const response = await fetch(`/api/overview?${query()}`, { cache: "no-store" });
      if (!response.ok) throw new Error();
      setData(await response.json());
      setOffline(false);
      setTick(0);
    } catch {
      setOffline(true);
    }
  }, [query]);

  // Refresh every 3 seconds so watch data and plan changes appear unprompted.
  useEffect(() => {
    setData(null);
    load();
    const poll = setInterval(load, 3000);
    const clock = setInterval(() => setTick(value => value + 1), 1000);
    return () => { clearInterval(poll); clearInterval(clock); };
  }, [load]);

  async function send(path, method, payload) {
    setBusy(true);
    setMessage("");
    try {
      const response = await fetch(`${path}${path.includes("?") ? "&" : "?"}${query()}`, {
        method, headers: { "Content-Type": "application/json" }, body: payload ? JSON.stringify(payload) : undefined,
      });
      const result = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(result.error || "That did not save. Try again.");
      await load();
      return true;
    } catch (error) {
      setMessage(error instanceof TypeError ? "Could not reach the server. Check your connection and try again." : error.message);
      return false;
    } finally {
      setBusy(false);
    }
  }

  function startEditing(profile) {
    setDraft(profile ? {
      ...profile,
      ageYears: profile.ageYears ?? "", heightCm: profile.heightCm ?? "", weightKg: profile.weightKg ?? "",
      sexForEstimate: profile.sexForEstimate ?? "", dayActivity: profile.dayActivity ?? "",
    } : EMPTY_PROFILE);
    setMessage("");
    setEditing(true);
  }
  async function saveProfile(event) {
    event.preventDefault();
    const saved = await send("/api/profile", "PUT", {
      goal: "stay_active", activities: draft.activities, days: draft.days, durationMin: Number(draft.durationMin),
      experience: draft.experience, ageYears: optionalNumber(draft.ageYears), heightCm: optionalNumber(draft.heightCm),
      weightKg: optionalNumber(draft.weightKg), sexForEstimate: draft.sexForEstimate || null,
      dayActivity: draft.dayActivity || null, shareToWatch: draft.shareToWatch === true,
    });
    if (saved) setEditing(false);
  }
  const toggle = (key, value) => setDraft(current => ({
    ...current,
    [key]: current[key].includes(value) ? current[key].filter(item => item !== value) : [...current[key], value],
  }));
  const decide = (action, extra = {}) => send("/api/plan/decision", "POST", { id: data.plan.suggestion.id, action, ...extra });

  async function addMeal(event) {
    event.preventDefault();
    const saved = await send("/api/meals", "POST", { date: localDate(), kcal: Number(meal.kcal), label: meal.label || null });
    if (saved) setMeal({ kcal: "", label: "" });
  }

  if (!data) {
    return <main className="sa"><p className="empty">{offline ? "Dashboard offline. Retrying." : "Loading your plan."}</p></main>;
  }

  const { profile, plan, energy, mealsToday, watch } = data;
  const suggestion = plan.suggestion;
  const now = data.now + tick;
  const needsSetup = !profile;
  const showForm = editing || needsSetup;
  const open = !["done", "rest_chosen"].includes(suggestion.status);

  return (
    <main className="sa" id="main">
      <div className="sa-mode" role="group" aria-label="Which data to show">
        <button type="button" aria-pressed={!demo} onClick={() => { setDemo(false); setEditing(false); setAdjusting(false); }}>Your data</button>
        <button type="button" aria-pressed={demo} onClick={() => { setDemo(true); setEditing(false); setAdjusting(false); }}>View demo</button>
        {demo && <button type="button" className="text-button" disabled={busy} onClick={() => send("/api/demo/reset", "POST")}>Reset demo</button>}
      </div>
      {demo && (
        <p className="sa-banner" role="note">
          <strong>Demo data.</strong> Two weeks of simulated history for an example person. None of it is yours, and nothing here reaches a watch.
        </p>
      )}
      {offline && <p className="sa-banner warn" role="status">Dashboard offline. Showing the last update; retrying.</p>}
      {message && <p className="error" role="alert">{message}</p>}

      {/* 1. What is my goal? */}
      <section className="block" aria-labelledby="goal-h">
        <div className="block-head">
          <h2 id="goal-h">Your goal</h2>
          {!showForm && <button type="button" className="text-button" onClick={() => startEditing(profile)}>Edit preferences</button>}
        </div>
        {!showForm ? (
          <div className="sa-goal">
            <p className="sa-goal-name">Stay active</p>
            <p className="sa-sub">
              {profile.days.length} planned {profile.days.length === 1 ? "day" : "days"} a week
              {" · "}{profile.durationMin} min
              {" · "}{profile.activities.map(a => ACTIVITY[a]).join(", ")}
            </p>
          </div>
        ) : (
          <form className="sa-form" onSubmit={saveProfile}>
            {needsSetup && (
              <p className="sa-intro">
                Tell us a little so today’s suggestion fits you. It takes under a minute, and the health details are optional.
              </p>
            )}
            <p className="sa-fixed"><span>Goal</span> Stay active <small>Other goals are not available yet.</small></p>
            <fieldset>
              <legend>Activities you like</legend>
              <div className="sa-chips">
                {ACTIVITY_CHOICES.map(([value, label]) => (
                  <label key={value}><input type="checkbox" checked={draft.activities.includes(value)} onChange={() => toggle("activities", value)} />{label}</label>
                ))}
              </div>
            </fieldset>
            <fieldset>
              <legend>Days you’d like to be active</legend>
              <div className="sa-chips">
                {DAYS.map(([value, label]) => (
                  <label key={value}><input type="checkbox" checked={draft.days.includes(value)} onChange={() => toggle("days", value)} />{label}</label>
                ))}
              </div>
            </fieldset>
            <div className="sa-row">
              <label>Time you usually have (minutes)
                <input type="number" min="10" max="90" step="5" required value={draft.durationMin} onChange={e => setDraft({ ...draft, durationMin: e.target.value })} />
              </label>
              <label>Your experience
                <select value={draft.experience} onChange={e => setDraft({ ...draft, experience: e.target.value })}>
                  {EXPERIENCE.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                </select>
              </label>
            </div>
            <fieldset>
              <legend>Optional: for a daily energy estimate</legend>
              <p className="fine">Leave these blank to skip the estimate. They are stored on this shared demo site, so only enter what you are comfortable sharing.</p>
              <div className="sa-row">
                <label>Age (years)<input type="number" min="13" max="100" value={draft.ageYears} onChange={e => setDraft({ ...draft, ageYears: e.target.value })} /></label>
                <label>Height (cm)<input type="number" min="100" max="230" value={draft.heightCm} onChange={e => setDraft({ ...draft, heightCm: e.target.value })} /></label>
                <label>Weight (kg)<input type="number" min="30" max="250" value={draft.weightKg} onChange={e => setDraft({ ...draft, weightKg: e.target.value })} /></label>
              </div>
              <div className="sa-row">
                <label>Sex, as used by the estimate formula
                  <select value={draft.sexForEstimate} onChange={e => setDraft({ ...draft, sexForEstimate: e.target.value })}>
                    <option value="">Prefer not to say</option><option value="female">Female</option><option value="male">Male</option>
                  </select>
                </label>
                <label>A typical day, outside workouts
                  <select value={draft.dayActivity} onChange={e => setDraft({ ...draft, dayActivity: e.target.value })}>
                    <option value="">Not set</option>
                    {DAY_ACTIVITY.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                  </select>
                </label>
              </div>
            </fieldset>
            <label className="sa-check">
              <input type="checkbox" checked={draft.shareToWatch === true} onChange={e => setDraft({ ...draft, shareToWatch: e.target.checked })} />
              <span>Send plan to watch. PacePilot can then fetch today’s suggestion when you choose “Get today’s plan” on the watch. Nothing is sent to the watch otherwise.</span>
            </label>
            <div className="form-actions">
              <button type="submit" className="primary" disabled={busy}>{busy ? "Saving…" : "Save preferences"}</button>
              {!needsSetup && <button type="button" className="text-button" onClick={() => setEditing(false)}>Cancel</button>}
            </div>
          </form>
        )}
      </section>

      {/* 2. What is suggested today, and why? */}
      {!needsSetup && (
        <section className="block sa-today" aria-labelledby="today-h">
          <div className="block-head">
            <h2 id="today-h">Today, {shortDate(suggestion.date)}</h2>
            <span className="tag">{STATUS[suggestion.status]}</span>
          </div>
          <p className="sa-big">{describe(suggestion)}</p>
          <p className="sa-why"><strong>Why:</strong> {suggestion.reason}</p>
          <ul className="sa-basis">{suggestion.basis.map((line, index) => <li key={index}>{line}</li>)}</ul>
          {open && !adjusting && (
            <div className="form-actions">
              {suggestion.status === "suggested" && <button type="button" className="primary" disabled={busy} onClick={() => decide("accept")}>Accept</button>}
              <button type="button" className="sa-secondary" disabled={busy} onClick={() => {
                setChange({ durationMin: Math.max(10, suggestion.durationMin), activity: suggestion.activity ?? "walk", toDate: localDate(1) });
                setAdjusting(true);
              }}>Adjust or move</button>
              {suggestion.kind === "workout" && suggestion.durationMin > 10 && <button type="button" className="sa-secondary" disabled={busy} onClick={() => decide("easier")}>Make it easier</button>}
              {suggestion.kind === "workout" && <button type="button" className="sa-secondary" disabled={busy} onClick={() => decide("rest")}>Rest today</button>}
            </div>
          )}
          {open && adjusting && (
            <div className="sa-adjust">
              <div className="sa-row">
                <label>Minutes
                  <input type="number" min="10" max="90" step="5" value={change.durationMin} onChange={e => setChange({ ...change, durationMin: e.target.value })} />
                </label>
                <label>Activity
                  <select value={change.activity} onChange={e => setChange({ ...change, activity: e.target.value })}>
                    {ACTIVITY_CHOICES.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                  </select>
                </label>
                <button type="button" className="primary" disabled={busy} onClick={async () => {
                  if (await decide("adjust", { durationMin: Number(change.durationMin), activity: change.activity })) setAdjusting(false);
                }}>Use this</button>
              </div>
              <div className="sa-row">
                <label>Or move it to
                  <input type="date" min={localDate(1)} max={localDate(14)} value={change.toDate} onChange={e => setChange({ ...change, toDate: e.target.value })} />
                </label>
                <button type="button" className="sa-secondary" disabled={busy || !change.toDate} onClick={async () => {
                  if (await decide("reschedule", { toDate: change.toDate })) setAdjusting(false);
                }}>Move session</button>
                <button type="button" className="text-button" onClick={() => setAdjusting(false)}>Cancel</button>
              </div>
            </div>
          )}
          <p className="fine">A suggestion never starts a workout or gets harder by itself. Start it on the watch when you are ready.</p>
        </section>
      )}

      {/* 3. Is my watch sending data? */}
      <section className="block" aria-labelledby="watch-h">
        <div className="block-head"><h2 id="watch-h">Is my watch sending data?</h2></div>
        {demo ? (
          <p className="empty">The demo has no watch. Switch to “Your data” to see live activity from yours.</p>
        ) : (
          <>
            <ul className="sa-watch" role="status" aria-live="polite">
              {APPS.map(([app, name]) => {
                const stream = watch.streams.filter(s => s.app === app).sort((a, b) => b.receivedAt - a.receivedAt)[0];
                const state = offline ? "stale" : stream?.state ?? "waiting";
                const [label, tone] = offline ? ["Dashboard offline, retrying", "off"] : WATCH_STATE[state];
                const beat = watch.beats.find(b => b.app === app);
                return (
                  <li key={app}>
                    <span className={`dot ${tone}`} aria-hidden="true" />
                    <div>
                      <p className="sa-watch-name">{name}</p>
                      <p className="sa-watch-state">{label}</p>
                      <p className="fine">
                        {stream ? `Last workout update ${ago(now - stream.receivedAt)}.` : "No workout data received yet."}
                        {beat && ` App checked in ${ago(now - beat.receivedAt)}.`}
                      </p>
                      {stream && state === "active" && (
                        <p className="sa-live">
                          {stream.heartRate != null ? `${stream.heartRate} bpm` : "Heart rate unavailable"}
                          {" · "}{Math.floor(stream.elapsedSec / 60)}:{String(stream.elapsedSec % 60).padStart(2, "0")} elapsed
                          {stream.goalSec ? ` of ${Math.round(stream.goalSec / 60)} min` : ""}
                          {(stream.fluidMl > 0 || stream.carbsG > 0) ? ` · ${stream.fluidMl ?? 0} ml, ${stream.carbsG ?? 0} g carbs logged` : ""}
                        </p>
                      )}
                    </div>
                  </li>
                );
              })}
            </ul>
            <p className="fine">
              This shows data reaching the dashboard, which needs sharing switched on in the watch app and the paired phone online. It cannot tell whether your watch is paired. A workout counts as live only while updates keep arriving; after 20 seconds without one it is marked stale.
            </p>
          </>
        )}
      </section>

      {/* 4. How am I progressing toward consistency? */}
      {!needsSetup && (
        <section className="block" aria-labelledby="progress-h">
          <div className="block-head">
            <h2 id="progress-h">Consistency, last 14 days</h2>
            {demo && <span className="tag">Demo data</span>}
          </div>
          <dl className="facts sa-facts">
            <div><dt>This week</dt><dd>{plan.week.doneDays}<small> of {plan.week.plannedDays} planned days</small></dd></div>
            <div><dt>Missed this week</dt><dd>{plan.week.missedDays}<small> planned {plan.week.missedDays === 1 ? "day" : "days"}</small></dd></div>
            <div><dt>Full weeks in a row</dt><dd>{plan.week.streakWeeks}<small> with every planned day done</small></dd></div>
          </dl>
          <ol className="sa-strip">
            {plan.consistency.map(day => {
              const kind = day.done ? "done" : day.planned ? (day.date < plan.today ? "missed" : "planned") : "rest";
              const text = day.done ? `${day.durationMin} min${day.effort ? `, ${day.effort}` : ""}` : kind === "missed" ? "Missed" : kind === "planned" ? "Planned" : "Rest";
              return (
                <li key={day.date} className={kind}>
                  <span className="sa-strip-date">{shortDate(day.date)}</span>
                  <span className="sa-strip-mark" aria-hidden="true" />
                  <span className="sa-strip-text">{text}</span>
                </li>
              );
            })}
          </ol>
          <p className="fine">Done days come from sessions finished on the watch with sharing on. A missed day is a planned day with no session; it is information, not a debt to repay.</p>
        </section>
      )}

      {/* Nutrition that supports the same goal */}
      <section className="block" aria-labelledby="food-h">
        <div className="block-head">
          <h2 id="food-h">Food and energy today</h2>
          {demo && <span className="tag">Demo data</span>}
        </div>
        <dl className="facts sa-facts">
          <div><dt>Eaten, entered by you</dt><dd>{mealsToday.kcal}<small> kcal in {mealsToday.count} {mealsToday.count === 1 ? "entry" : "entries"}</small></dd></div>
          <div>
            <dt>Estimated daily needs</dt>
            <dd>{energy.available ? <>{energy.rangeKcal.min}–{energy.rangeKcal.max}<small> kcal, an estimate</small></> : <small>Not shown</small>}</dd>
          </div>
          <div>
            <dt>Activity, reported by Garmin</dt>
            <dd>{data.activityKcalToday != null ? <>{data.activityKcalToday}<small> kcal in fuelling sessions</small></> : <small>No reading today</small>}</dd>
          </div>
        </dl>
        <p className="sa-sub">
          Logged during workouts today: {data.workoutIntake.fluidMl > 0 || data.workoutIntake.carbsG > 0
            ? `${data.workoutIntake.fluidMl} ml of fluid and ${data.workoutIntake.carbsG} g of carbohydrate, from the watch.`
            : "nothing yet. Use “Log drink” and “Log food” in the watch’s workout menu."}
        </p>
        <form className="sa-row sa-meal" onSubmit={addMeal}>
          <label>Calories (kcal)<input type="number" min="1" max="5000" required value={meal.kcal} onChange={e => setMeal({ ...meal, kcal: e.target.value })} /></label>
          <label>What was it? (optional)<input type="text" maxLength="40" value={meal.label} onChange={e => setMeal({ ...meal, label: e.target.value })} /></label>
          <button type="submit" className="primary" disabled={busy}>Log meal</button>
        </form>
        {mealsToday.meals.length > 0 && (
          <ul className="sa-meals">
            {mealsToday.meals.map(entry => (
              <li key={entry.id}>
                <span>{entry.label ?? "Meal"}</span><span className="num">{entry.kcal} kcal</span>
                {!String(entry.id).startsWith("demo-") && <button type="button" className="text-button" disabled={busy} onClick={() => send(`/api/meals?id=${encodeURIComponent(entry.id)}`, "DELETE")}>Remove</button>}
              </li>
            ))}
          </ul>
        )}
        <p className="fine">
          {energy.available
            ? `The estimate uses the Mifflin-St Jeor equation (about ${energy.restingKcal} kcal at rest) times ${energy.activityFactor} for your typical day. It is a rough population formula, shown as a range of about 10% either way, and can be well off for an individual. It already allows for everyday activity, so Garmin’s activity calories are shown separately and not added on top.`
            : `${energy.reason} The three figures here are kept separate on purpose: what you entered, a formula estimate, and what Garmin reported.`}
          {" "}This is not a calorie target, and staying active does not require eating less.
        </p>
      </section>
    </main>
  );
}
