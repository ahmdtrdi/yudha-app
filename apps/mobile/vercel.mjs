const apiBaseUrl = process.env.YUDHA_API_BASE_URL?.replace(/\/+$/, "");

if (!apiBaseUrl) {
  throw new Error("YUDHA_API_BASE_URL is required to configure the API proxy.");
}

export const config = {
  installCommand: "bash tool/install_flutter.sh",
  buildCommand: "bash tool/build_web.sh",
  outputDirectory: "build/web",
  rewrites: [
    {
      source: "/api-proxy/:path*",
      destination: `${apiBaseUrl}/:path*`,
    },
    {
      source: "/(.*)",
      destination: "/index.html",
    },
  ],
  headers: [
    {
      source: "/yudha_service_worker.js",
      headers: [
        {
          key: "Cache-Control",
          value: "no-cache, no-store, must-revalidate",
        },
      ],
    },
    {
      source: "/manifest.json",
      headers: [
        {
          key: "Content-Type",
          value: "application/manifest+json",
        },
      ],
    },
    {
      source: "/(.*)",
      headers: [
        {
          key: "X-Content-Type-Options",
          value: "nosniff",
        },
        {
          key: "Referrer-Policy",
          value: "strict-origin-when-cross-origin",
        },
      ],
    },
  ],
};
