# Feature Freeze Checklist v1

Use this list to validate the V1 scope before exiting the feature freeze. Each item must be implemented, behind auth, and scoped per active company/bar.

- [ ] **Multi-company support (per owner)** – Owners can belong to multiple companies without cross-tenant leakage.
- [ ] **Owner login + business selection** – Email/password auth, post-login company chooser/creator, sets activeCompanyId.
- [ ] **Staff login (Business ID + PIN)** – Business ID lookup, hashed PIN validation, sets activeCompanyId/currentStaffMember.
- [ ] **Bar & Warehouse stock management** – CRUD on products/groups, bar levels with confirmation, warehouse qty edits.
- [ ] **Orders (Pending → Confirmed → Delivered / Cancelled)** – Status flow with quantity edits and inventory impact.
- [ ] **Restock flow** – Low-item selection, suggested amounts, apply/commit with validation.
- [ ] **History log + limited undo** – Actor-tagged history for stock/order changes with time/role-bounded undo.
- [ ] **Realtime Firestore sync** – Inventory and orders stream in real time; normal use does not require manual sync.
- [ ] **Low-stock alerts + auto-suggested restock** – Badges/counters and par-based suggestions surfaced in UI.
- [ ] **Order History with search/filters/export** – Date/status filters, search chips, and export (CSV/PDF/shareable text) for owners/managers.
- [ ] **Single logout + inactivity auto-logout** – Central logout clears owner/staff/company; idle timer warns then signs out.
- [ ] **Account deletion entry point** – In-app flow to request/delete account/company data per store requirements.
- [ ] **Mobile-first UI + Web/PWA owner dashboard** – Responsive layouts for phones/tablets and installable web/PWA experience for owners.
