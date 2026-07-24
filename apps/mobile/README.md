# YUDHA Mobile and PWA

Flutter client for Android and the installable YUDHA web app.

## Local development

Create `.env` with the production or local values:

```dotenv
SUPABASE_URL=
SUPABASE_PUBLISHABLE_KEY=
YUDHA_API_BASE_URL=
YUDHA_GAME_BASE_URL=
```

Run the web client with the same compile-time environment:

```powershell
flutter run -d chrome --dart-define-from-file=.env
```

Create a production bundle:

```powershell
flutter build web --release --no-wasm-dry-run --dart-define-from-file=.env
```

The static bundle is generated in `build/web`.

## Vercel

Create a Vercel project with `apps/mobile` as its Root Directory. The checked-in
`vercel.json` installs the pinned Flutter SDK, builds the app, publishes
`build/web`, configures SPA rewrites, and serves the PWA service worker without
HTTP caching.

Configure these variables for Production and Preview in Vercel:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `YUDHA_API_BASE_URL`
- `YUDHA_GAME_BASE_URL`

Both backend URLs must use HTTPS. The Vercel build compiles the browser client
against `/api-proxy`, which is rewritten to `YUDHA_API_BASE_URL` at the edge.
This keeps browser API calls same-origin. `CORS_ALLOWED_ORIGINS` remains
available on the API service for deployments that call Railway directly.

On iOS, open the production URL in Safari, select Share, choose **Add to Home
Screen**, enable **Open as Web App**, and select Add.
