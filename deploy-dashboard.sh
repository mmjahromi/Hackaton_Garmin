#!/bin/sh
set -eu
cd "$(dirname "$0")/gut-train-web"
npm ci
npm test
npm run build
npx --yes vercel@latest deploy --prod --yes
