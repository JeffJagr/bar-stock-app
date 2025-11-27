# Feature Freeze Checklist v1

Use this list to validate the V1 scope before exiting the feature freeze. Each item should be demonstrably implemented, behind auth, and scoped per active company/bar.

- [ ] **Multi-tenant access** - Firebase-authenticated users can join/create companies, switch active bars, and never see data from other tenants.
- [ ] **Bar stock management** - Full CRUD on bar groups/products, slider-driven levels, low indicators, and undo logging.
- [ ] **Warehouse stock management** - Warehouse quantities, tracking toggles, low alerts, and integration with ordering.
- [ ] **Orders lifecycle** - Pending -> Confirmed -> Delivered flow with quantity edits, status history, and inventory updates.
- [ ] **Restock planning** - Low-item selection, suggested amounts, validation, and apply-to-bar workflows.
- [ ] **History & undo** - Actor-scoped history log plus limited, role-aware undo for recent stock/order changes.
- [ ] **Analytics snapshot** - Basic charts/tables for usage, restock, and stock breakdown across selected ranges.
- [ ] **Firebase sync** - Email/password auth plus Firestore read/write scoped by company/bar for inventory, orders, history, and staff.
- [ ] **Mobile-first + web** - Responsive layouts, keyboard/scroll affordances, and hover-ready UI for Flutter mobile and Chrome.
