// Node 22 resolves the explicit `node --test lib` directory through this entry.
// The .mjs suite loads ESM app code without changing package.json's module type.
import('./insights.test.mjs');
import('./api.test.mjs');
import('./activity.test.mjs');
