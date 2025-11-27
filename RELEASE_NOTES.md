# Release Notes — Smart Bar Stock v1.0.0+1

## Overview
This mobile release packages the Smart Bar Stock management experience for production-ready deployment. It includes bar/warehouse inventory tracking, low-stock and restock workflows, supplier order management, analytics, staff controls, and multi-surface printing/export utilities. State persists locally for offline resilience and syncs with Firebase services when credentials are provided.

## Working Features
- **Inventory views**: Bar, Low, Warehouse, and Restock screens support live quantities, max targets, warehouse tracking toggles, and suggested refills with validation.
- **Ordering pipeline**: Create, update, confirm, and mark supplier orders delivered, with badge indicators and undo support.
- **History & analytics**: Full audit trail plus statistics dashboards (range filtering, comparison mode, product/group focus, charts) with export/print snapshots.
- **Search & staff management**: Global search across products/history and role-based staff admin (admin/owner/manager/worker) with password policies.
- **Printing/export**: Section-based print previews, clipboard export, OS-level sharing, and simulated native print hooks.
- **Undo & persistence**: Undo manager tied to staff roles, local secure storage, and optional Firebase sync (Auth + Firestore) routed through remote repository services.
- **Security & roles**: App logic enforces bar/warehouse edit permissions, manager warnings, and safe restock/order operations even when lists are empty.

## Platform Support
- **Android**: Placeholder `com.placeholder.barstockapp` `applicationId` configured; release signing left to CI/CD. Semantic versioning aligns with `pubspec.yaml`.
- **iOS**: Placeholder `com.placeholder.barstockapp` bundle IDs and blank `DEVELOPMENT_TEAM` ready for assignment in Xcode/CI before TestFlight/App Store uploads.
- **Other**: Flutter desktop/web builds remain functional for internal QA but are not part of this store submission.

## Infrastructure & Services
- Firebase Core/Auth/Firestore hooks included and gated via `AppConfig.firebaseEnabled`. Owner/bar identifiers must be injected via environment variables or CI secrets before enabling cloud sync.
- Print/export features leverage `share_plus` and system clipboards without storing artifacts server-side.
- Analytics/usage stats are computed locally; no third-party analytics SDKs are bundled for this release.

## Known-Safe Limitations
- **Identifier placeholders**: Android `applicationId`, iOS bundle IDs, and `APP_OWNER_ID` remain placeholders. Replace them in CI or build configurations prior to store submission.
- **Signing**: No release keystores/provisioning profiles are bundled. Configure Gradle/Xcode signing outside the repo.
- **Cloud data**: Firebase sync expects a correctly provisioned project. When disabled, the app safely operates in local-only mode.
- **Printing**: “System print” is simulated on unsupported platforms; actual native print dialogs depend on platform integrations you supply later.
- **Statistics samples**: Analytics use in-memory history; extremely large histories may require future pagination but are safe for current scope.
- **Push/alerts**: No push notifications or background fetchers are included, avoiding accidental network usage.

## Validation
- `dart analyze` — passes with zero issues.
- Manual smoke passes cover login, inventory edits, restock/application flows, printing dialogs, staff CRUD, undo, and Firebase-gated paths (with guards for absent credentials).

> Ready for submission once identifiers and signing assets are injected through your release pipeline.
