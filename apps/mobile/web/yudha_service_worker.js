const CACHE_NAME = "yudha-pwa-v4";
const APP_SHELL = [
  "/",
  "/index.html",
  "/flutter_bootstrap.js",
  "/main.dart.js",
  "/manifest.json",
  "/favicon.png",
  "/icons/Icon-192.png",
  "/icons/Icon-512.png",
  "/icons/Icon-maskable-192.png",
  "/icons/Icon-maskable-512.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key.startsWith("yudha-pwa-") && key !== CACHE_NAME)
            .map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") {
    return;
  }

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) {
    return;
  }

  // Never persist authenticated backend responses in the shared app cache.
  if (url.pathname.startsWith("/api-proxy/")) {
    event.respondWith(fetch(request));
    return;
  }

  if (request.mode === "navigate") {
    event.respondWith(networkFirstNavigation(request));
    return;
  }

  if (isStaticAsset(request, url)) {
    event.respondWith(staleWhileRevalidate(event, request));
    return;
  }

  // Do not cache unknown same-origin requests; they may contain user data.
  event.respondWith(fetch(request));
});

function isStaticAsset(request, url) {
  return (
    url.pathname.startsWith("/assets/") ||
    url.pathname.startsWith("/canvaskit/") ||
    ["audio", "font", "image", "script", "style", "worker"].includes(
      request.destination,
    ) ||
    /\.(?:css|js|json|png|svg|ttf|otf|wasm)$/.test(url.pathname)
  );
}

async function staleWhileRevalidate(event, request) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);
  const update = fetch(request).then(async (response) => {
    if (response.ok) {
      await cache.put(request, response.clone());
    }
    return response;
  });

  if (cached) {
    event.waitUntil(update.catch(() => undefined));
    return cached;
  }
  return update;
}

async function networkFirstNavigation(request) {
  const cache = await caches.open(CACHE_NAME);
  try {
    const response = await Promise.race([
      fetch(request),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error("navigation timeout")), 2500),
      ),
    ]);
    if (response.ok) {
      await cache.put("/index.html", response.clone());
    }
    return response;
  } catch (_) {
    return cache.match("/index.html");
  }
}
