"use client";

import { useEffect, useRef, useState } from "react";
import { buildInsights, buildPlan } from "../lib/insights";
import { activityInsights, activityPlan, weekDates, weekSummary } from "../lib/activity";

const EVENTS = {
  sprint: { label: "Sprint triathlon", target: 30 },
  olympic: { label: "Olympic triathlon", target: 45 },
  half: { label: "Half Ironman (70.3)", target: 75 },
  full: { label: "Ironman", target: 90 },
};
const STATUS_LABELS = { good: "On track", watch: "Keep an eye on", fix: "Fix this" };

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// Built by hand, not with the browser's date formatter, so the server and
// every browser produce exactly the same text.
function calendarDate(value) {
  const [year, month, dayOfMonth] = value.split("-").map(Number);
  return `${MONTHS[month - 1]} ${dayOfMonth}, ${year}`;
}

const GUT_LABELS = ["Rough", "Uneasy", "OK", "Good", "Great"];
const POLL_MS = 2000;
const CHART_FLOOR_MAX = 100; // g/h at the top of the chart unless the data goes higher
const GRID_STEP = 30;
const CHART_SESSIONS = 12;
const START_TARGET = 50; // g/h before any session, matching the watch
const FLOOR_TARGET = 30; // lowest target the watch programme allows

function duration(seconds) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return hours > 0 ? `${hours} h ${minutes} min` : `${minutes} min`;
}

// The server does not know the viewer's time zone, so the first render shows
// UTC built by hand (identical on server and browser); once the page is live
// in the browser, `local` switches these to the viewer's own time.
function day(epochSeconds, local) {
  const date = new Date(epochSeconds * 1000);
  return local
    ? `${MONTHS[date.getMonth()]} ${date.getDate()}`
    : `${MONTHS[date.getUTCMonth()]} ${date.getUTCDate()}`;
}

function clockTime(epochSeconds, local) {
  const date = new Date(epochSeconds * 1000);
  const hours = local ? date.getHours() : date.getUTCHours();
  const minutes = local ? date.getMinutes() : date.getUTCMinutes();
  const text = `${hours % 12 || 12}:${String(minutes).padStart(2, "0")} ${hours < 12 ? "am" : "pm"}`;
  return local ? text : `${text} UTC`;
}

function percent(value, max) {
  return `${Math.min(100, Math.max(0, (value / max) * 100))}%`;
}

function localToday() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
}

export default function Dashboard({ initialSessions, initialDays = [], initialGoal = null, initialToday, persistent }) {
  const [sessions, setSessions] = useState(initialSessions);
  const [days, setDays] = useState(initialDays);
  const [goal, setGoal] = useState(initialGoal);
  const [editingGoal, setEditingGoal] = useState(!initialGoal);
  const [draft, setDraft] = useState(initialGoal ?? { event: "sprint", raceDate: "", targetGph: 30 });
  const [savingGoal, setSavingGoal] = useState(false);
  const [goalError, setGoalError] = useState("");
  const [today, setToday] = useState(initialToday);
  const [connected, setConnected] = useState(true);
  const [freshAt, setFreshAt] = useState(null);
  const [local, setLocal] = useState(false);
  useEffect(() => {
    setLocal(true);
    setToday(localToday());
  }, []);
  const newestSeen = useRef(initialSessions[0]?.at ?? 0);

  // Ask the server for sessions every couple of seconds, so a session
  // finished on the watch appears here without a page refresh.
  useEffect(() => {
    let cancelled = false;

    async function poll() {
      try {
        const [response, daysResponse] = await Promise.all([
          fetch("/api/sessions", { cache: "no-store" }),
          fetch("/api/days", { cache: "no-store" }),
        ]);
        if (!response.ok || !daysResponse.ok) {
          throw new Error(`Status ${response.status}`);
        }
        const [data, dayData] = await Promise.all([response.json(), daysResponse.json()]);
        if (cancelled) {
          return;
        }
        setConnected(true);
        setSessions(data.sessions);
        setDays(dayData.days);
        setToday(localToday());
        const newest = data.sessions[0]?.at ?? 0;
        if (newest > newestSeen.current) {
          newestSeen.current = newest;
          setFreshAt(newest);
        }
      } catch {
        if (!cancelled) {
          setConnected(false);
        }
      }
    }

    const timer = setInterval(poll, POLL_MS);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, []);

  async function saveGoal(event) {
    event.preventDefault();
    setSavingGoal(true);
    setGoalError("");
    try {
      const response = await fetch("/api/goal", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...draft, targetGph: Number(draft.targetGph) }),
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(data.error || "Could not save your goal. Try again.");
      setGoal(data.goal);
      setDraft(data.goal);
      setEditingGoal(false);
    } catch (error) {
      // fetch rejects with a TypeError when the server cannot be reached.
      setGoalError(error instanceof TypeError
        ? "Could not reach the server. Check your connection and try again."
        : error.message);
    } finally {
      setSavingGoal(false);
    }
  }

  const STATUS_ORDER = { fix: 0, watch: 1, good: 2 };
  const insights = [...buildInsights(sessions, goal, today), ...activityInsights(days, today)]
    .map((insight, index) => ({ ...insight, index }))
    .sort((a, b) => STATUS_ORDER[a.status] - STATUS_ORDER[b.status] || a.index - b.index);
  const counts = insights.reduce((tally, insight) => ({ ...tally, [insight.status]: tally[insight.status] + 1 }),
    { fix: 0, watch: 0, good: 0 });
  const plan = buildPlan(sessions, goal, today);
  const guidanceRecords = [...sessions, ...days.filter((day) => day.date <= today)];
  const demoGuidance = guidanceRecords.length > 0 && guidanceRecords.every((record) => record.demo);
  const activity = weekSummary(days, today);
  const dailyPlan = activityPlan(activity.weekTarget, plan.length);
  const todayActivity = days.find((day) => day.date === today);
  const activityWeek = weekDates(today).map((date) => ({ date, record: days.find((day) => day.date === date) }));
  const shownDays = activityWeek.flatMap(({ record }) => record ? [record] : []);
  const activityMax = Math.max(30, ...shownDays.flatMap((day) => [day.activeMin, day.dailyTarget]));
  const latest = sessions[0];
  const sensors = [
    { name: "Heart rate", description: "Shows effort and flags feeds taken while working hard.", reading: latest?.avgHr > 0 || latest?.maxHr > 0 || latest?.hardFeeds > 0 },
    { name: "GPS", description: "Measures distance and helps detect stops.", reading: latest?.distanceM > 0 || latest?.stops > 0 || latest?.stoppedS > 0 },
    { name: "Accelerometer", description: "Measures cadence and helps detect stops.", reading: latest?.avgCadence > 0 || latest?.stops > 0 || latest?.stoppedS > 0 },
    { name: "Barometer", description: "Measures climbing during your session.", reading: latest?.ascentM > 0 },
    { name: "Thermometer", description: "Drink prompts come sooner in the heat.", reading: latest?.avgTempC != null || latest?.maxTempC != null || latest?.hotDrinkPrompts > 0 },
    { name: "Activity recording", description: "Records session time for your per-hour totals.", reading: latest?.durationS > 0 },
  ];
  const charted = sessions.slice(0, CHART_SESSIONS).reverse(); // oldest on the left
  const chartMax = Math.max(CHART_FLOOR_MAX,
    Math.ceil(Math.max(0, ...charted.flatMap((s) => [s.rateGph, s.targetGph])) / 10) * 10);
  const grid = [];
  for (let value = GRID_STEP; value < chartMax; value += GRID_STEP) grid.push(value);

  // How far the current target has climbed from the programme's floor to the race-day goal.
  const currentTarget = latest?.nextTargetGph ?? START_TARGET;
  const goalGap = goal ? Math.max(0, goal.targetGph - currentTarget) : null;
  const goalProgress = goal
    ? goal.targetGph <= FLOOR_TARGET ? 1 : Math.min(1, Math.max(0, (currentTarget - FLOOR_TARGET) / (goal.targetGph - FLOOR_TARGET)))
    : null;
  const daysToRace = goal
    ? Math.ceil((new Date(`${goal.raceDate}T00:00:00Z`) - new Date(`${today}T00:00:00Z`)) / 86400000)
    : null;
  const effort = latest?.avgHr > 0 && latest?.userMaxHr > 0
    ? Math.round(latest.avgHr / latest.userMaxHr * 100)
    : null;

  return (
    <>
      <a className="skip" href="#main">Skip to content</a>
      <header className="masthead">
        <p className="brand">
          <span className="brand-mark" aria-hidden="true" />
          Gut Train
        </p>
        <p className={connected ? "live" : "live off"} role="status">
          <span className="dot" aria-hidden="true" />
          {connected ? "Live from the watch" : "Connection lost, retrying"}
        </p>
      </header>

      <main id="main">
        <section className="hero rise" aria-labelledby="hero-heading">
          <div className="hero-main">
            <h1 id="hero-heading" className="eyebrow">
              {latest?.targetConfirmed ? "Your confirmed fueling target" : "Next session target"}
              {latest?.demo && <span className="tag">from a demo session</span>}
            </h1>
            <p className={latest ? "big" : "big muted"}>
              {currentTarget}
              <span className="unit">g carbs<br />per hour</span>
            </p>
            <p className="hero-line">
              {latest
                ? `Last session you ate ${latest.rateGph} g/h against a ${latest.targetGph} g/h target, and your gut felt ${GUT_LABELS[latest.gutRating - 1].toLowerCase()}.`
                : "Use Gut Train to follow your own fueling plan and record comfort on longer sessions. Confirm each next-session target on the watch."}
            </p>

            {goal ? (
              <div className="goal-meter">
                <div className="meter-track" aria-hidden="true">
                  <div className="meter-fill" style={{ transform: `scaleX(${goalProgress})` }} />
                </div>
                <p className="meter-caption">
                  {goalGap === 0
                    ? `You have reached your ${goal.targetGph} g/h race-day goal.`
                    : `${goalGap} g/h to go to your ${goal.targetGph} g/h race-day goal.`}
                  {daysToRace > 0 && ` ${daysToRace} days to ${EVENTS[goal.event].label}.`}
                </p>
              </div>
            ) : (
              <p className="meter-caption">Set a goal below to see how far you have to go.</p>
            )}
          </div>

          <dl className="facts">
            <div>
              <dt>Sessions logged</dt>
              <dd>{sessions.length}</dd>
            </div>
            <div>
              <dt>Eaten last time</dt>
              <dd>{latest ? <>{latest.rateGph}<small> of {latest.targetGph} g/h</small></> : <small>None yet</small>}</dd>
            </div>
            <div>
              <dt>Gut last time</dt>
              <dd>{latest ? <>{latest.gutRating}<small> of 5, {GUT_LABELS[latest.gutRating - 1].toLowerCase()}</small></> : <small>No rating yet</small>}</dd>
            </div>
            <div>
              <dt>Effort last time</dt>
              <dd>{effort != null ? <>{effort}%<small> of max heart rate</small></> : <small>No reading</small>}</dd>
            </div>
          </dl>
        </section>

        <section className="sensors" aria-labelledby="sensors-heading">
          <h2 id="sensors-heading">Garmin sensors used</h2>
          <ul className="sensor-list">
            {sensors.map((sensor) => (
              <li key={sensor.name}>
                <h3>{sensor.name}</h3>
                <p>{sensor.description}</p>
                <span className="sensor-reading">{sensor.reading ? "Reading" : "No reading yet"}</span>
              </li>
            ))}
          </ul>
        </section>

        <section className="block rise activity" style={{ "--i": 1 }} aria-labelledby="activity-heading">
          <div className="block-head">
            <h2 id="activity-heading">Stay active</h2>
            {shownDays.some((day) => day.demo) && <span className="tag">{shownDays.every((day) => day.demo) ? "Demo data" : "Includes demo data"}</span>}
          </div>
          {days.length === 0 ? (
            <p className="empty">Your watch syncs activity every 30 minutes.</p>
          ) : (
            <>
              <div className="activity-layout">
                <div className="activity-summary">
                  <p className="activity-total">{activity.minutes}<small> of {activity.weekTarget} min this week</small></p>
                  <div className="goal-meter">
                    <div className="meter-track" aria-hidden="true">
                      <div className="meter-fill" style={{ transform: `scaleX(${activity.weekTarget ? Math.min(1, activity.minutes / activity.weekTarget) : 1})` }} />
                    </div>
                    <p className="meter-caption">{activity.streak}-day streak · {todayActivity ? `${todayActivity.activeMin} of ${todayActivity.dailyTarget} min today` : "No activity synced today"}</p>
                    <p className="fine">{activity.daysHit} days met their daily target this week.</p>
                  </div>
                </div>
                <div className="chart activity-chart" role="group" aria-labelledby="activity-heading" aria-describedby="activity-note">
                  <ul className="legend">
                    <li><span className="swatch bar-swatch" aria-hidden="true" />Active minutes</li>
                    <li><span className="swatch tick-swatch" aria-hidden="true" />Daily target</li>
                  </ul>
                  <div className="plot">
                    <div className="bars">
                      {activityWeek.map(({ date, record }, index) => (
                        <div key={date} className={`slot ${index < 3.5 ? "tip-start" : "tip-end"}`}
                          tabIndex={0} role="img"
                          aria-label={`${calendarDate(date)}${record?.demo ? ", demo" : ""}: ${record ? `${record.activeMin} active minutes, target ${record.dailyTarget} minutes` : "No record"}`}>
                          {record && <>
                            <div className="bar" style={{ height: percent(record.activeMin, activityMax) }} />
                            <div className="tick" style={{ bottom: percent(record.dailyTarget, activityMax) }} />
                          </>}
                          <span className="activity-day" aria-hidden="true">{["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][index]}</span>
                          <div className="tip" aria-hidden="true">
                            <strong>{calendarDate(date)}{record?.demo ? " (demo)" : ""}</strong>
                            {record ? <><span>Active: {record.activeMin} min</span><span>Target: {record.dailyTarget} min</span></> : <span>No record</span>}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                  <p className="axis-note" id="activity-note">Active minutes, Monday to Sunday. Ticks show each day's target.</p>
                </div>
              </div>
              <dl className="facts activity-facts">
                <div><dt>Steps today</dt><dd>{todayActivity ? todayActivity.steps : <small>No reading</small>}</dd></div>
                <div><dt>Floors today</dt><dd>{todayActivity ? todayActivity.floors : <small>No reading</small>}</dd></div>
                <div><dt>Body Battery this morning</dt><dd>{todayActivity?.bodyBattery != null ? <>{todayActivity.bodyBattery}<small> of 100</small></> : <small>No reading</small>}{todayActivity?.recoveryDay && <small className="recovery-day">Recovery day</small>}</dd></div>
              </dl>
            </>
          )}
        </section>

        <div className="layout">
          <div className="main-col">
            <section className="block rise" style={{ "--i": 1 }} aria-labelledby="insights-heading">
              <div className="block-head">
                <h2 id="insights-heading">What to work on</h2>
                {demoGuidance && <span className="tag">Demo data</span>}
              </div>
              {insights.length ? (
                <>
                  <p className="tally">
                    {counts.fix} to fix
                    <span aria-hidden="true"> · </span>
                    {counts.watch} to keep an eye on
                    <span aria-hidden="true"> · </span>
                    {counts.good} on track
                  </p>
                  <ul className="insights">
                    {insights.map((insight) => (
                      <li key={insight.area} className={insight.status}>
                        <p className="insight-status">
                          <span className="mark" aria-hidden="true" />
                          {STATUS_LABELS[insight.status]}
                        </p>
                        <div>
                          <h3>{insight.area}: {insight.title}</h3>
                          <p>{insight.detail}</p>
                        </div>
                      </li>
                    ))}
                  </ul>
                </>
              ) : (
                <ol className="start">
                  <li><strong>Set your goal.</strong> Pick your race and the carbs per hour you want to tolerate by then.</li>
                  <li><strong>Start a long session on the watch.</strong> Press START each time it says “Fuel now”.</li>
                  <li><strong>Rate your gut at the end.</strong> The session lands here within seconds, with what to work on.</li>
                </ol>
              )}
              <p className="fine">Guidance is general sports-nutrition practice, not medical advice.</p>
            </section>

            <section className="block rise" style={{ "--i": 2 }} aria-labelledby="chart-heading">
              <div className="block-head">
                <h2 id="chart-heading">Carbs eaten per hour, by session</h2>
                <ul className="legend">
                  <li>
                    <span className="swatch bar-swatch" aria-hidden="true" />
                    Eaten
                  </li>
                  <li>
                    <span className="swatch tick-swatch" aria-hidden="true" />
                    Target
                  </li>
                </ul>
              </div>

              {charted.length === 0 ? (
                <p className="empty">
                  No sessions yet. Finish one on the watch and it appears here within a few seconds.
                </p>
              ) : (
                <div className="chart" role="group" aria-labelledby="chart-heading" aria-describedby="chart-note">
                  <div className="plot">
                    {grid.map((value) => (
                      <div key={value} className="grid-line" style={{ bottom: percent(value, chartMax) }} aria-hidden="true">
                        <span>{value}</span>
                      </div>
                    ))}
                    <div className="bars">
                      {charted.map((session, index) => (
                        <div key={`${session.at}-${index}`}
                          className={index < charted.length / 2 ? "slot tip-start" : "slot tip-end"}
                          tabIndex={0} role="img"
                          aria-label={`${day(session.at, local)}, ${clockTime(session.at, local)}${session.demo ? ", demo" : ""}: ate ${session.rateGph} g/h against a ${session.targetGph} g/h target, gut ${GUT_LABELS[session.gutRating - 1].toLowerCase()}`}>
                          <div className="bar" style={{ height: percent(session.rateGph, chartMax) }} />
                          <div className="tick" style={{ bottom: percent(session.targetGph, chartMax) }} />
                          <div className="tip" aria-hidden="true">
                            <strong>
                              {day(session.at, local)}, {clockTime(session.at, local)}
                              {session.demo ? " (demo)" : ""}
                            </strong>
                            <span>Eaten: {session.rateGph} g/h</span>
                            <span>Target: {session.targetGph} g/h</span>
                            <span>Gut: {GUT_LABELS[session.gutRating - 1]}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                  <p className="axis-note" id="chart-note">Grams of carbohydrate per hour. Oldest session on the left.</p>
                </div>
              )}
            </section>
          </div>

          <aside className="rail">
            <section className="block rise" style={{ "--i": 1 }} aria-labelledby="goal-heading">
              <div className="block-head">
                <h2 id="goal-heading">Your goal</h2>
                {goal && !editingGoal && (
                  <button type="button" className="text-button" onClick={() => {
                    setDraft(goal); setGoalError(""); setEditingGoal(true);
                  }}>Edit</button>
                )}
              </div>
              {editingGoal ? (
                <form className="goal-form" onSubmit={saveGoal}>
                  <label>Event
                    <select value={draft.event} disabled={savingGoal} onChange={(event) => {
                      const value = event.target.value;
                      setDraft({ ...draft, event: value, targetGph: EVENTS[value].target });
                    }}>
                      {Object.entries(EVENTS).map(([value, event]) => <option key={value} value={value}>{event.label}</option>)}
                    </select>
                  </label>
                  <label>Race date
                    <input type="date" required value={draft.raceDate} disabled={savingGoal}
                      onChange={(event) => setDraft({ ...draft, raceDate: event.target.value })} />
                  </label>
                  <label>Target carbs per hour (g/h)
                    <input type="number" min="30" max="120" step="1" required value={draft.targetGph} disabled={savingGoal}
                      onChange={(event) => setDraft({ ...draft, targetGph: event.target.value })} />
                  </label>
                  <div className="form-actions">
                    <button type="submit" className="primary" disabled={savingGoal}>{savingGoal ? "Saving goal…" : "Save goal"}</button>
                    {goal && <button type="button" className="text-button" disabled={savingGoal} onClick={() => {
                      setEditingGoal(false); setGoalError("");
                    }}>Cancel</button>}
                  </div>
                </form>
              ) : (
                <div className="goal-summary">
                  <p className="goal-event">{EVENTS[goal.event].label}</p>
                  <p className="goal-detail">{calendarDate(goal.raceDate)} · aiming for {goal.targetGph} g/h</p>
                </div>
              )}
              {goalError && <p className="error" role="alert">{goalError}</p>}
            </section>

            <section className="block rise" style={{ "--i": 2 }} aria-labelledby="plan-heading">
              <div className="block-head">
                <h2 id="plan-heading">Training plan</h2>
                {sessions[0]?.demo && <span className="tag">Demo data</span>}
              </div>
              {plan.length ? (
                <ol className="plan">
                  {plan.map((session) => (
                    <li key={session.week}>
                      <p className="plan-when">{calendarDate(session.date).replace(/, \d{4}$/, "")}</p>
                      <p className="plan-target">{session.targetGph}<small> g/h · {session.durationMin} min</small></p>
                      <p className="plan-focus">{session.focus}</p>
                      <p className="plan-focus">Daily activity: about {dailyPlan[session.week - 1]} min a day</p>
                    </li>
                  ))}
                </ol>
              ) : (
                <p className="empty">There are no weekly sessions left before your race date. Edit your goal to plan for another race.</p>
              )}
              {!goal && <p className="fine">This plan assumes building to 90 g/h. Setting a goal tailors it to your race.</p>}
              <p className="fine">This assumes each session goes well. The watch sets the real target after every session, so the plan shifts if your stomach needs longer.</p>
            </section>
          </aside>
        </div>

        <section className="block rise" style={{ "--i": 3 }} aria-labelledby="sessions-heading">
          <div className="block-head">
            <h2 id="sessions-heading">Sessions</h2>
          </div>
          {sessions.length === 0 ? (
            <p className="empty">Nothing logged yet.</p>
          ) : (
            <div className="table-wrap" tabIndex={0} role="region" aria-label="Sessions">
              <table>
                <thead>
                  <tr>
                    <th scope="col">When</th>
                    <th scope="col">Length</th>
                    <th scope="col" className="num">Carbs</th>
                    <th scope="col" className="num">Eaten / target</th>
                    <th scope="col" className="num">Fluid</th>
                    <th scope="col" className="num">Avg heart rate</th>
                    <th scope="col" className="num">Calories</th>
                    <th scope="col" className="num">Max heart rate</th>
                    <th scope="col" className="num">Distance</th>
                    <th scope="col" className="num">Climb</th>
                    <th scope="col" className="num">Temp</th>
                    <th scope="col" className="num">Cadence</th>
                    <th scope="col" className="num">Stops</th>
                    <th scope="col" className="num">Gut flags</th>
                    <th scope="col">Gut</th>
                    <th scope="col" className="num">Next target</th>
                  </tr>
                </thead>
                <tbody>
                  {sessions.map((session, index) => {
                    const change = session.nextTargetGph - session.targetGph;
                    const direction = change > 0 ? "up" : change < 0 ? "down" : "";
                    const fresh = session.at === freshAt && index === 0;
                    return (
                      <tr key={`${session.at}-${index}`} className={fresh ? "fresh" : ""}>
                        <td>
                          {day(session.at, local)}, {clockTime(session.at, local)}
                          {session.demo && <span className="tag">demo</span>}
                        </td>
                        <td>{duration(session.durationS)}</td>
                        <td className="num">{session.carbsG} g</td>
                        <td className="num">
                          {session.rateGph} / {session.targetGph} g/h
                        </td>
                        <td className="num">{session.fluidMl ?? 0} ml</td>
                        <td className="num">{session.avgHr ? `${session.avgHr} bpm` : "No reading"}</td>
                        <td className="num">{session.calories != null ? `${session.calories} kcal` : "No reading"}</td>
                        <td className="num">{session.maxHr > 0 ? `${session.maxHr} bpm` : "No reading"}</td>
                        <td className="num">{session.distanceM > 0 ? `${(session.distanceM / 1000).toFixed(1)} km` : "No reading"}</td>
                        <td className="num">{session.ascentM > 0 ? `${session.ascentM} m` : "No reading"}</td>
                        <td className="num">{session.avgTempC != null && session.maxTempC != null
                          ? `${session.avgTempC} °C avg, ${session.maxTempC} max`
                          : session.avgTempC != null ? `${session.avgTempC} °C avg, No reading max`
                          : session.maxTempC != null ? `No reading avg, ${session.maxTempC} °C max` : "No reading"}</td>
                        <td className="num">{session.avgCadence > 0 ? `${session.avgCadence} /min` : "No reading"}</td>
                        <td className="num">{session.stops > 0
                          ? `${session.stops}, ${session.stoppedS > 0 ? `${Math.round(session.stoppedS / 60)} min` : "No reading"}`
                          : session.stops != null ? "None" : "No reading"}</td>
                        <td className="num">{session.gutEvents ?? 0}</td>
                        <td>
                          {GUT_LABELS[session.gutRating - 1]} ({session.gutRating}/5)
                        </td>
                        <td className={`num ${direction}`}>
                          {session.nextTargetGph} g/h
                          {change !== 0 && ` (${change > 0 ? "+" : ""}${change})`}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </section>

        {!persistent && (
          <p className="fine">
            Storage is in memory only, so sessions, daily activity and your goal are lost when the server restarts. Add a Redis
            database to keep them.
          </p>
        )}
      </main>
    </>
  );
}
