/* sw.js — офлайн-кеш книги. Локальные файлы: cache-first + дозапись;
   шрифты Google (другой origin) идут в сеть как обычно. */
const CACHE = "maryam-book-v1";
self.addEventListener("install", (e) => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(
  caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim())
));
self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  const url = new URL(e.request.url);
  if (url.origin !== location.origin) return;            // шрифты и прочее — в сеть
  e.respondWith(
    caches.open(CACHE).then((c) =>
      c.match(e.request).then((hit) =>
        hit || fetch(e.request).then((resp) => {
          if (resp && resp.status === 200) c.put(e.request, resp.clone());
          return resp;
        })
      )
    )
  );
});
