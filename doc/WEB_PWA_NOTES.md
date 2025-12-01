# Smart Bar Stock – Web PWA Notes

## Manifest
- Path: `web/manifest.json`
- name/short_name: `Smart Bar Stock` / `SmartBar`
- start_url/scope: `/` with `display: standalone`
- theme/background: `#455A64` / `#0D1B2A` (aligned to app blue-grey scheme)
- Icons: 192, 512, and maskable variants already present in `web/icons/`

## Service worker
- Path: `web/service_worker.js`
- Registration: inline in `web/index.html` (`navigator.serviceWorker.register('./service_worker.js')` on load)
- Strategy:
  - Pre-caches the core app shell (`index.html`, `manifest.json`, icons, `flutter_bootstrap.js`, `main.dart.js`, asset manifests/notices)
  - Cache name versioned: `smartbar-pwa-v1`; old caches removed on activate
  - Navigation requests fall back to cached `index.html` for offline-first shell when the network is down
  - Static asset requests use cache-first with background refresh; offline fallback to the cached shell
  - Firebase and other third-party hosts (`firebaseio.com`, `googleapis.com`, `gstatic.com`, `cloudfunctions.net`) are bypassed so real-time traffic is not intercepted

## Behaviour & limits
- Offline: previously loaded screens work from the cached shell; data requiring Firestore/Auth will need connectivity to stay up to date
- Install: browsers should surface “Install app”; installed app launches fullscreen with the `Smart Bar Stock` name and maskable icon
- Updates: bump `CACHE_NAME` in `service_worker.js` when core shell assets change to force a fresh cache on next load

## Testing checklist
1) Build web: `flutter build web --release --pwa-strategy=none` (custom service worker is in `web/`)  
2) Serve `build/web` over HTTP(S) (e.g., `python -m http.server 8080`)  
3) Open in Chrome → DevTools → Application → Manifest shows installable; address bar should display the install prompt  
4) Click Install; confirm the app name/icon and standalone window  
5) Go offline, refresh: app shell loads from cache; expect live data to pause until back online  
6) Return online, ensure real-time updates resume (Firestore snapshots)
