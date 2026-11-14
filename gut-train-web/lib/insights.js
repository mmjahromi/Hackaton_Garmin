const DAY_MS = 86400000;
const isNumber = (value) => typeof value === "number" && Number.isFinite(value);
const average = (values) => values.reduce((sum, value) => sum + value, 0) / values.length;
const rounded = (value) => Math.round(value);

function recentSessions(sessions) {
  const real = sessions.filter((session) => !session.demo);
  return (real.length ? real : sessions).slice(0, 3);
}

// Calendar dates use UTC throughout, so DST and server timezone cannot shift weeks.
function dayTime(today) {
  const date = today instanceof Date ? today.toISOString().slice(0, 10) : String(today).slice(0, 10);
  return new Date(`${date}T00:00:00Z`).getTime();
}

export function buildInsights(sessions, goal, today) {
  const recent = recentSessions(sessions);
  if (!recent.length) return [];
  const insights = [];
  const add = (area, status, title, detail) => insights.push({ area, status, title, detail });

  const fuel = recent.filter((s) => isNumber(s.rateGph) && isNumber(s.targetGph) && s.targetGph > 0);
  if (fuel.length) {
    const eaten = average(fuel.map((s) => s.rateGph));
    const target = average(fuel.map((s) => s.targetGph));
    const low = eaten < target * 0.9;
    add("Fuelling", low ? "fix" : "good", low ? "Take every feed" : "You are meeting your fuelling target",
      `You averaged ${rounded(eaten)} g/h eaten against a target of ${rounded(target)} g/h. ${low ? "Take every feed when the watch prompts." : "Keep taking each feed when the watch prompts."}`);
  }

  const ratings = recent.filter((s) => isNumber(s.gutRating));
  if (ratings.length) {
    const rating = average(ratings.map((s) => s.gutRating));
    const flags = recent.filter((s) => isNumber(s.gutEvents) && s.gutEvents > 0);
    const count = flags.reduce((sum, s) => sum + s.gutEvents, 0);
    const first = flags.filter((s) => isNumber(s.firstGutEventS)).map((s) => s.firstGutEventS);
    const flagDetail = count ? ` You flagged gut discomfort ${count} time${count === 1 ? "" : "s"}.${first.length ? ` The earliest first flag came roughly ${rounded(Math.min(...first) / 60)} minutes into a session.` : ""}` : "";
    add("Gut comfort", rating < 3 ? "fix" : rating < 4 ? "watch" : "good", "How your stomach coped",
      `Your average gut rating was ${rating.toFixed(1)} out of 5. ${rating < 3 ? "Hold or lower the target and try drink-based carbs." : rating < 4 ? "Hold the target until your stomach feels more comfortable." : "Your stomach is coping well with these feeds."}${flagDetail}`);
  }

  const fluid = recent.filter((s) => isNumber(s.fluidMl) && isNumber(s.durationS) && s.durationS > 0);
  if (fluid.length) {
    const rate = average(fluid.map((s) => s.fluidMl * 3600 / s.durationS));
    add("Fluid", rate < 400 ? "fix" : rate < 500 ? "watch" : "good", "Fluid taken per hour",
      `You averaged ${rounded(rate)} ml per hour. 500–800 ml per hour is a common starting range, not a rule; adjust for conditions and your needs.`);
  }

  const temperatures = recent.filter((s) => isNumber(s.avgTempC));
  const heatFluid = temperatures.filter((s) => isNumber(s.fluidMl) && isNumber(s.durationS) && s.durationS > 0);
  if (temperatures.length && heatFluid.length) {
    const temperature = average(temperatures.map((s) => s.avgTempC));
    if (temperature >= 27) {
      const rate = average(heatFluid.map((s) => s.fluidMl * 3600 / s.durationS));
      add("Heat", rate < 600 ? "fix" : "good", rate < 600 ? "Drink more in the heat" : "Fluid is keeping up with the heat",
        `Your average temperature reading was ${rounded(temperature)} °C, with ${rounded(rate)} ml of fluid per hour. ${rate < 600 ? "Take more fluid and sodium in the heat." : "Keep taking fluid regularly in the heat."} The watch's thermometer reads warmer than the air.`);
    }
  }

  const climbs = recent.filter((s) => isNumber(s.ascentM) && s.ascentM > 0 && isNumber(s.durationS) && s.durationS > 0);
  if (climbs.length) {
    const rate = average(climbs.map((s) => s.ascentM * 3600 / s.durationS));
    if (rate >= 300 && climbs.some((s) => s.gutEvents > 0)) {
      add("Climbing", "watch", "Try feeding before hills",
        `You averaged ${rounded(rate)} m of ascent per hour, with gut flags in these sessions. Gut trouble may come on climbs; try feeding before hills rather than on them.`);
    }
  }

  const stopped = recent.filter((s) => isNumber(s.stops) && s.stops > 0 && isNumber(s.stoppedS));
  if (stopped.length) {
    const count = stopped.reduce((sum, s) => sum + s.stops, 0);
    const minutes = rounded(stopped.reduce((sum, s) => sum + s.stoppedS, 0) / 60);
    const gutStops = stopped.some((s) => s.gutEvents > 0);
    add("Stops", gutStops ? "watch" : "good", gutStops ? "Possible gut stops" : "Time spent stopped",
      `You made ${count} stop${count === 1 ? "" : "s"}, totalling ${minutes} minutes stopped. ${gutStops ? "Stops and gut flags happened in the same sessions, so some stops may have been gut-related." : "These sessions had no gut flags recorded alongside stops."}`);
  }

  const hardFeeds = recent.filter((s) => isNumber(s.hardFeeds) && s.hardFeeds > 0)
    .reduce((sum, s) => sum + s.hardFeeds, 0);
  if (hardFeeds > 0) {
    add("Intensity", "watch", "Ease off before eating",
      `${hardFeeds} feed${hardFeeds === 1 ? " was" : "s were"} taken above 85% of max heart rate. The gut absorbs less when working hard, so ease off for a minute before eating.`);
  }

  const effort = recent.filter((s) => isNumber(s.avgHr) && s.avgHr > 0 && isNumber(s.userMaxHr) && s.userMaxHr > 0);
  if (effort.length) {
    const rate = average(effort.map((s) => s.avgHr / s.userMaxHr * 100));
    add("Effort", rate < 60 || rate > 85 ? "watch" : "good", "Effort during your sessions",
      `Your average effort was ${rounded(rate)}% of maximum heart rate. ${rate < 60 ? "This is too easy to rehearse race-day fuelling." : rate > 85 ? "This is harder than long-course race pace, where the gut copes worse." : "This is a useful effort for rehearsing race-day fuelling."}`);
  }

  const energy = recent.filter((s) => isNumber(s.calories) && s.calories > 0 && isNumber(s.carbsG));
  if (energy.length) {
    const eaten = average(energy.map((s) => s.carbsG * 4));
    const burned = average(energy.map((s) => s.calories));
    const rate = eaten / burned * 100;
    add("Energy replaced", rate >= 30 ? "good" : "watch", "Energy replaced by carbs",
      `You averaged ${rounded(eaten)} kcal from carbs against ${rounded(burned)} kcal burned, replacing ${rounded(rate)}%. This is context for your fuelling, not a target to replace all energy burned.`);
  }

  const durations = recent.map((s) => s.durationS).filter(isNumber);
  if (["half", "full"].includes(goal?.event) && durations.length && average(durations) < 7200) {
    add("Session length", "watch", "Build up to longer sessions", "Long-course gut training needs sessions of two hours or more.");
  }

  const current = recent[0].nextTargetGph;
  if (goal && isNumber(current)) {
    const daysLeft = (dayTime(goal.raceDate) - dayTime(today)) / DAY_MS;
    const weeksLeft = Math.max(0, Math.floor(daysLeft / 7));
    const sessionsNeeded = Math.ceil((goal.targetGph - current) / 10);
    if (daysLeft < 0) {
      add("Goal gap", "watch", "Your race date has passed", "Update your goal with your next race date to plan ahead.");
    } else if (current >= goal.targetGph) {
      add("Goal gap", "good", "You have reached your race-day target", `Your next target is ${current} g/h against your race-day goal of ${goal.targetGph} g/h.`);
    } else {
      add("Goal gap", sessionsNeeded <= weeksLeft ? "good" : "fix", sessionsNeeded <= weeksLeft ? "You are on track for your goal" : "Your goal needs more time",
        `${sessionsNeeded} gut-training sessions are needed to build from ${current} to ${goal.targetGph} g/h, with ${weeksLeft} whole weeks remaining.${sessionsNeeded <= weeksLeft ? " You are on track at one gut-training session a week." : " Allow more time or adjust your goal rather than rushing the increases."}`);
    }
  }
  return insights;
}

export function buildPlan(sessions, goal, today) {
  const ceiling = Math.min(goal?.targetGph ?? 90, 120);
  // Same sessions the insights use, so the plan and the goal gap never disagree.
  let target = Math.min(recentSessions(sessions)[0]?.nextTargetGph ?? 50, ceiling);
  const duration = ({ sprint: 60, olympic: 90, half: 150, full: 180 })[goal?.event] ?? 120;
  const start = dayTime(today);
  const race = goal ? dayTime(goal.raceDate) : Infinity;
  const plan = [];
  for (let week = 1; week <= 6; week++) {
    const date = start + week * 7 * DAY_MS;
    if (date >= race) break; // Rehearsals happen before race day.
    const lighter = race - date <= 7 * DAY_MS;
    if (week > 1 && !lighter) target = Math.min(target + 10, ceiling);
    plan.push({
      week,
      date: new Date(date).toISOString().slice(0, 10),
      targetGph: target,
      durationMin: lighter ? duration / 2 : duration,
      focus: lighter ? `Hold ${target} g/h for a shorter race rehearsal.` : week === 1
        ? `Hold ${target} g/h and finish every feed.`
        : `Step up to ${target} g/h; switch to drink mix if your stomach complains.`,
    });
    if (target >= ceiling) break;
  }
  return plan;
}
