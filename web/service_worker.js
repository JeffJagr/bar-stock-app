const CACHE_NAME = 'smartbar-pwa-v1';
const APP_BASE = new URL('./', self.location).toString();

const CORE_ASSETS = [
  'index.html',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'flutter_bootstrap.js',
  'main.dart.js',
  'assets/AssetManifest.json',
  'assets/FontManifest.json',
  'assets/NOTICES',
].map((path) => new URL(path, APP_BASE).toString());

const OFFLINE_FALLBACK = new URL('index.html', APP_BASE).toString();
const BYPASS_HOSTS = [
  'firebaseio.com',
  'googleapis.com',
  'gstatic.com',
  'cloudfunctions.net',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(CORE_ASSETS)).then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(
          keys.filter((key) => key !== CACHE_NAME).map((oldKey) => caches.delete(oldKey)),
        ))
        .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') {
    return;
  }

  const url = new URL(request.url);
  const isCrossOrigin = url.origin !== self.location.origin;
  const shouldBypass = isCrossOrigin || BYPASS_HOSTS.some((host) => url.hostname.includes(host));
  if (shouldBypass) {
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
          .then((response) => {
            const copy = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(OFFLINE_FALLBACK, copy));
            return response;
          })
          .catch(() => caches.match(OFFLINE_FALLBACK)),
    );
    return;
  }

  event.respondWith(
    caches.match(request).then((cached) => {
      if (cached) {
        fetch(request)
            .then((response) => {
              if (response && response.ok) {
                caches.open(CACHE_NAME).then((cache) => cache.put(request, response.clone()));
              }
            })
            .catch(() => {});
        return cached;
      }

      return fetch(request)
          .then((response) => {
            if (response && response.ok) {
              caches.open(CACHE_NAME).then((cache) => cache.put(request, response.clone()));
            }
            return response;
          })
          .catch(() => caches.match(OFFLINE_FALLBACK));
    }),
  );
});
