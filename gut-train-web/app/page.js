import { getGoal, isPersistent, listDays, listSessions } from "../lib/store";
import Dashboard from "./Dashboard";

export const dynamic = "force-dynamic";

export default async function Page() {
  const [sessions, goal, days] = await Promise.all([listSessions(), getGoal(), listDays()]);
  return <Dashboard initialSessions={sessions} initialDays={days} initialGoal={goal} initialToday={new Date().toISOString().slice(0, 10)} persistent={isPersistent} />;
}
