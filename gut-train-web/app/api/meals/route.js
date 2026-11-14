import { addMeal, deleteMeal, listMeals } from "../../../lib/store";
import { normalizeMeal, mealsOn } from "../../../lib/meals";
import { demoMeals } from "../../../lib/demo";
import { context, body, bad, keyError } from "../../../lib/request";

export const dynamic = "force-dynamic";

export async function GET(request) {
  const { url, demo, today } = context(request);
  const saved = await listMeals(demo);
  const meals = demo ? [...saved, ...demoMeals(today)] : saved;
  return Response.json(mealsOn(meals, url.searchParams.get("date") ?? today));
}

export async function POST(request) {
  const denied = keyError(request);
  if (denied) return denied;
  const { demo } = context(request);
  let meal;
  try { meal = normalizeMeal(await body(request), { demo }); } catch (error) { return bad(error); }
  await addMeal(meal, demo);
  return Response.json({ meal }, { status: 201 });
}

export async function DELETE(request) {
  const { url, demo } = context(request);
  const removed = await deleteMeal(url.searchParams.get("id") ?? "", demo);
  return Response.json({ removed }, { status: removed ? 200 : 404 });
}
