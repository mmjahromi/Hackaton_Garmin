const DAY_MS = 86400000;
const dateTime = (date) => new Date(`${date}T00:00:00Z`).getTime();
const dateString = (time) => new Date(time).toISOString().slice(0, 10);

// UTC arithmetic on local calendar-date strings avoids DST shifting a day.
export function weekDates(today) {
  const time = dateTime(today);
  const monday = time - ((new Date(time).getUTCDay() + 6) % 7) * DAY_MS;
  return Array.from({ length: 7 }, (_, index) => dateString(monday + index * DAY_MS));
}

export function weekSummary(days, today) {
  const dates = weekDates(today);
  const week = days.filter((day) => day.date >= dates[0] && day.date <= today)
    .sort((a, b) => b.date.localeCompare(a.date));
  const byDate = new Map(days.map((day) => [day.date, day]));
  const hit = (date) => {
    const day = byDate.get(date);
    return day != null && day.activeMin >= day.dailyTarget;
  };
  let cursor = dateTime(today);
  if (!hit(today)) cursor -= DAY_MS;
  let streak = 0;
  while (hit(dateString(cursor))) {
    streak++;
    cursor -= DAY_MS;
  }
  return {
    minutes: week.reduce((sum, day) => sum + day.activeMin, 0),
    weekTarget: week[0]?.weekTarget ?? 150,
    daysHit: week.filter((day) => day.activeMin >= day.dailyTarget).length,
    streak,
  };
}

export function activityInsights(days, today) {
  if (!days.some((day) => day.date <= today)) return [];
  const { minutes, weekTarget } = weekSummary(days, today);
  const elapsed = weekDates(today).indexOf(today) + 1;
  const expected = weekTarget * elapsed / 7;
  const status = minutes < expected * 0.8 ? "fix" : minutes < expected ? "watch" : "good";
  const insights = [{
    area: "Activity", status,
    title: status === "good" ? "Keeping pace this week" : "Make room for movement",
    detail: `${minutes} active minutes this week against ${Number(expected.toFixed(1))} min expected by today (${weekTarget} min for the week).`,
  }];
  const start = dateString(dateTime(today) - 6 * DAY_MS);
  const recent = days.filter((day) => day.date >= start && day.date <= today);
  const nudges = recent.reduce((sum, day) => sum + day.nudges, 0);
  const answered = recent.reduce((sum, day) => sum + day.nudgesAnswered, 0);
  if (nudges) {
    const low = nudges >= 5 && answered < nudges / 2;
    insights.push({ area: "Still time", status: low ? "watch" : "good",
      title: low ? "Give movement a regular place" : "Responding to movement reminders",
      detail: `${answered} of ${nudges} nudges answered over the last 7 days.${low ? " Try a fixed walk after lunch or meetings." : " Keep making time to move when the watch nudges you."}` });
  }
  return insights;
}

// A projection only: the watch adjusts the actual target to each week's results.
export function activityPlan(weekTarget, weeks) {
  return Array.from({ length: weeks }, (_, index) => Math.round(Math.min(300, weekTarget * 1.1 ** index) / 7));
}
