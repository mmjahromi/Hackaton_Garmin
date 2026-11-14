// Mifflin-St Jeor simplified resting energy equation (kcal/day):
// 10 * kg + 6.25 * cm - 5 * years + (male: 5, female: -161).
// Source: Mifflin et al., AJCN 1990, doi:10.1093/ajcn/51.2.241
// https://pubmed.ncbi.nlm.nih.gov/2305711/
// Activity factors below are product-contract assumptions for typical daily
// activity, not coefficients from that paper. The +/-10% display is an
// approximate range, not a confidence interval. Never add exercise calories.
export const ACTIVITY_FACTORS = { mostly_sitting: 1.2, on_feet: 1.375, physical_job: 1.55 };
export function estimateEnergy(profile) {
  const demo = profile?.demo === true;
  const fields = ['ageYears', 'heightCm', 'weightKg', 'sexForEstimate', 'dayActivity'];
  if (typeof profile?.ageYears === 'number' && profile.ageYears < 18) return { available: false, reason: 'Energy estimates are only available for adults aged 18 or older.', demo };
  const missing = fields.filter(key => profile?.[key] == null);
  if (missing.length) return { available: false, reason: 'Add age, height, weight, sex for the estimate and daily activity to see an estimate.', missing, demo };
  const valid = [['ageYears',18,100], ['heightCm',100,230], ['weightKg',30,250]].every(([key,min,max]) => Number.isInteger(profile[key]) && profile[key]>=min && profile[key]<=max);
  if (!valid || !['female','male'].includes(profile.sexForEstimate) || !Object.hasOwn(ACTIVITY_FACTORS, profile.dayActivity)) return { available: false, reason: 'The estimate inputs are invalid.', demo };
  const resting = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * profile.ageYears + (profile.sexForEstimate === 'male' ? 5 : -161);
  const factor = ACTIVITY_FACTORS[profile.dayActivity];
  const daily = resting * factor;
  if (daily <= 0) return { available: false, reason: 'These inputs do not produce a usable energy estimate.', demo };
  return { available: true, label: 'Estimated daily energy needs', restingKcal: Math.round(resting), activityFactor: factor, kcal: Math.round(daily), rangeKcal: { min: Math.round(daily * 0.9), max: Math.round(daily * 1.1) }, demo };
}
