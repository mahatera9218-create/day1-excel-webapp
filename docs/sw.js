/* PIPxLOT service worker — 네트워크 우선(온라인이면 항상 최신, 오프라인이면 캐시) */
const CACHE = 'pipx-v1';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  e.respondWith((async () => {
    try {
      const net = await fetch(req, { cache: 'no-store' });
      try { const c = await caches.open(CACHE); c.put(req, net.clone()); } catch (_) {}
      return net;
    } catch (err) {
      const cached = await caches.match(req);
      return cached || Response.error();
    }
  })());
});
