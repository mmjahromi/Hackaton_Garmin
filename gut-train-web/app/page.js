import { getGoal, isPersistent, listDays, listSessions, listPaceSessions } from "../lib/store";
import SharedDashboard from "./SharedDashboard";

export const dynamic = "force-dynamic";

export default async function Page() {
  const [sessions, goal, days, pace] = await Promise.all([listSessions(), getGoal(), listDays(), listPaceSessions()]);
  return <SharedDashboard initialPace={pace} initialSessions={sessions} initialDays={days} initialGoal={goal} initialToday={new Date().toISOString().slice(0, 10)} persistent={isPersistent} />;
}
