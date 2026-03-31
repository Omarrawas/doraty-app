/**
 * Doraty PWA - Tiered Service Worker
 * ===================================
 * Strategy:
 *   1. CORE SHELL (Cache-First)   → Flutter app shell, fonts, icons
 *   2. API / Supabase  (Network-First, 1s timeout) → fresh data when possible
 *   3. STATIC ASSETS  (Stale-While-Revalidate)     → images, manifests
 *   4. EVERYTHING ELSE (Network-Only)              → no offline fallback
 *
 * This SW coexists with Flutter's auto-generated flutter_service_worker.js
 * (which handles the Dart/JS bundle). This file handles supplementary caching.
 */

const CACHE_VERSION = 'doraty-v1';
const SHELL_CACHE   = `${CACHE_VERSION}-shell`;
const DATA_CACHE    = `${CACHE_VERSION}-data`;
const ASSET_CACHE   = `${CACHE_VERSION}-assets`;

// ── Assets to pre-cache on install ─────────────────────────────────────────
const SHELL_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
];

// ── Origin patterns for each strategy ──────────────────────────────────────
const API_ORIGINS = [
  'supabase.co',     // Supabase REST & Realtime
];

const STATIC_ORIGINS = [
  'fonts.googleapis.com',
  'fonts.gstatic.com',
  'cdnjs.cloudflare.com',
  'img.youtube.com',     // YouTube thumbnails
];

// ── Install: pre-cache shell ────────────────────────────────────────────────
self.addEventListener('install', (event) => {
  console.log('[doraty-sw] Installing v1 – pre-caching shell...');
  event.waitUntil(
    caches.open(SHELL_CACHE).then((cache) => cache.addAll(SHELL_ASSETS))
  );
  self.skipWaiting();
});

// ── Activate: delete old caches ─────────────────────────────────────────────
self.addEventListener('activate', (event) => {
  console.log('[doraty-sw] Activating – cleaning old caches...');
  const VALID = [SHELL_CACHE, DATA_CACHE, ASSET_CACHE];
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k.startsWith('doraty-') && !VALID.includes(k))
          .map((k) => {
            console.log('[doraty-sw] Deleting old cache:', k);
            return caches.delete(k);
          })
      )
    ).then(() => self.clients.claim())
  );
});

// ── Fetch: route requests ────────────────────────────────────────────────────
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Skip non-GET, chrome-extension, and flutter internal requests
  if (event.request.method !== 'GET') return;
  if (url.protocol === 'chrome-extension:') return;
  // Let Flutter's own SW handle flutter_service_worker.js requests
  if (url.pathname.includes('flutter_service_worker')) return;

  // 1. API → Network-First (5s timeout → Cache fallback)
  if (API_ORIGINS.some((o) => url.hostname.includes(o))) {
    event.respondWith(networkFirstWithTimeout(event.request, DATA_CACHE, 5000));
    return;
  }

  // 2. Static CDN / Fonts → Stale-While-Revalidate
  if (STATIC_ORIGINS.some((o) => url.hostname.includes(o))) {
    event.respondWith(staleWhileRevalidate(event.request, ASSET_CACHE));
    return;
  }

  // 3. Own-origin app shell / assets → Cache-First
  if (url.origin === self.location.origin) {
    event.respondWith(cacheFirst(event.request, SHELL_CACHE));
    return;
  }

  // 4. Anything else → Network-Only (e.g. video streams)
});

// ── Strategy Helpers ─────────────────────────────────────────────────────────

/** Cache-First: return from cache; fetch & update if missing */
async function cacheFirst(request, cacheName) {
  const cache  = await caches.open(cacheName);
  const cached = await cache.match(request);
  if (cached) return cached;
  try {
    const response = await fetch(request);
    if (response.ok) cache.put(request, response.clone());
    return response;
  } catch (err) {
    console.warn('[doraty-sw] Cache-First fetch failed:', request.url);
    return new Response('Offline', { status: 503, statusText: 'Service Unavailable' });
  }
}

/** Network-First with timeout: try network; fall back to cache after timeout */
async function networkFirstWithTimeout(request, cacheName, timeoutMs) {
  const cache = await caches.open(cacheName);

  const timeoutPromise = new Promise((_, reject) =>
    setTimeout(() => reject(new Error('timeout')), timeoutMs)
  );

  try {
    const response = await Promise.race([fetch(request), timeoutPromise]);
    if (response.ok) cache.put(request, response.clone());
    return response;
  } catch (_) {
    const cached = await cache.match(request);
    if (cached) {
      console.log('[doraty-sw] API offline – serving from cache:', request.url);
      return cached;
    }
    return new Response(JSON.stringify({ error: 'offline' }), {
      status: 503,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}

/** Stale-While-Revalidate: return cache immediately; refresh in background */
async function staleWhileRevalidate(request, cacheName) {
  const cache  = await caches.open(cacheName);
  const cached = await cache.match(request);

  const fetchPromise = fetch(request).then((response) => {
    if (response.ok) cache.put(request, response.clone());
    return response;
  }).catch(() => null);

  return cached || fetchPromise;
}
