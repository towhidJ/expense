# CLAUDE.md — Project knowledge for Claude Code

Expense tracker "TakaKhata": React 19 + Vite 6 + Tailwind 4 + Supabase (BDT ৳ currency, dark theme, no test suite). `mobile/` holds the Flutter Android companion app. This file carries the cross-machine project memory — keep it updated when architecture facts change.

## Golden rules

- **Money movements must go through Postgres RPCs** (`process_transaction`, `process_transfer`, `process_loan_repayment`, `process_new_loan`, `process_saving`, `process_bazar_purchase`, `update/delete_transaction_with_balance`) — never plain inserts/updates, or `accounts.current_balance` silently corrupts.
- **Every table is scoped by `entity_id`** (personal/family/business workspaces). `EntityContext.currentEntity` drives all hooks — a missing `currentEntity` in a `useCallback` dep array is the classic bug here (stale data after workspace switch).
- **Migrations are manual**: schema lives in numbered `supabase_migration_v*.sql` files at repo root; each new one must be pasted into the Supabase SQL Editor by the user. Latest: **v35** (split/insurance/utility/rent/activity-log tables + subscription/warranty/exchange-rate/stock-expiry columns; v34 = Dena-Paona `liabilities.counterparty`). If a feature "doesn't work", first suspect an unapplied migration.
- **Touch-visible actions**: edit/delete buttons must be visible without hover. Web: `opacity-100 sm:opacity-0 sm:group-hover:opacity-100` (hover-reveal desktop only). Flutter: visible trailing `PopupMenuButton` (⋮), never long-press-only. The user considers hidden actions to be missing features.
- `npm run lint` reports ~29 pre-existing errors (react-hooks v7 strict rules like `set-state-in-effect` on the standard fetch-in-effect hook pattern, unused React imports in vendored `src/components/ui/*`) — not regressions, don't chase them.

## Domain gotchas

- Liability type `loan_given` is a **receivable** (adds to net worth), not a debt. There is no `status` column on liabilities — use `remaining_balance > 0`.
- Person-to-person loans (Dena-Paona, `/lending`) are liabilities rows with `counterparty` set; the Liabilities page filters them out (`!l.counterparty`), same pattern as Bazar's `shop_due` shop khatas.
- Recurring transactions auto-post into `transactions`, so trailing monthly averages (used by `/forecast`) already include them — never add recurring on top of averages.
- Meal Manager (`/meals/*`) is a separate multi-user workspace scoped by `group_id` (NOT entity_id) with membership-based RLS via SECURITY DEFINER helpers; month math ONLY via `get_meal_month_summary` RPC (shared web+mobile — never recompute client-side). `meal_group_members.display_name` is a snapshot because profiles RLS is self-only.
- Cash flow statement counts only account-linked movements (due purchases have no account_id, shown as memo); trial balance equity is the balancing figure.
- Zakat page (`/zakat`) persists its settings in localStorage key `zakat_settings_v1`; nisab from per-vori gold/silver prices.

## Web app map

- Routing in `src/App.jsx`; nav in `src/components/Sidebar.jsx`; pages in `src/pages/`, one data hook per feature in `src/hooks/` (fetch + CRUD, entity-scoped).
- Reports (`/reports`) has statement tabs in `src/components/Statements.jsx`, Bangla-safe PDFs via `src/lib/htmlPdf.js`, vouchers via `VoucherModal.jsx` + `src/lib/amountInWords.js` (lakh/crore style).
- Newest modules (2026-07-16, web-only so far): `/lending` (Dena-Paona person ledger), `/forecast` (6-month cashflow projection), `/zakat`, `/subscriptions` (view over `recurring_transactions.is_subscription`), `/insurance`, `/utility` (pay via `process_transaction`, sets `utility_bills.transaction_id`), `/rent` (landlord units + month grid; collect optionally logs income via RPC), `/warranty` (assets.warranty_expiry + attachments.asset_id), `/backup` (JSON/CSV export, skips missing tables), `/activity` (trigger-fed `activity_log`, read-only), `/splitter` (split_events/members/expenses, greedy settlement), `/tax` (BD FY Jul–Jun slabs, all editable, localStorage `tax_settings_v1`), `/insights` (client-side stats + `getInsights` AI chat, aggregates only), `/scan` (receipt OCR via `parseReceipt` → `process_transaction` per row).
- `src/hooks/useEntityTable.js` is the generic entity-scoped CRUD hook for simple tables — use it for new record-keeping tables; money movements still need RPC-backed hooks.
- Multi-currency: `accounts.exchange_rate` (manual, 1 unit = X BDT) + `src/lib/currency.js` (`toBDT`/`sumBDT`) — Dashboard/Forecast/Zakat/Accounts/Statements totals all go through `sumBDT`; new totals over accounts must too.
- The `gemini` edge function (supabase/functions/gemini) routes on `action`: parse_transaction, parse_receipt, insights, meal_report — client helpers in `src/lib/ai.js`.
- Admin OTA page (`/admin`, admins only via `useIsAdmin`) uploads Flutter APKs to the `app-releases` bucket + `app_versions` row.

## Flutter app (`mobile/`)

- Package `com.towhid.expense_tracker`; same Supabase project — URL/key hardcoded in `mobile/lib/config.dart`. Data layer: `lib/app_state.dart` (single ChangeNotifier); one screen per feature in `lib/screens/`.
- Near feature parity with web, EXCEPT: no Bazar-style Dena-Paona/Forecast/Zakat modules yet; PDF/Excel export of some reports stays web-only. PDFs are image-based (RepaintBoundary → PNG) because the dart pdf package can't shape Bengali.
- Build gotchas: keep `kotlin.incremental=false` in `mobile/android/gradle.properties` when the project and Pub cache sit on different drives ("different roots" crash). A failed `flutter build` leaves the previous APK in place — `adb install` after a failed build silently installs the stale one. Gradle "Could not stat file" state corruption → `flutter clean`.
- OTA updates: bump `version:` in `mobile/pubspec.yaml` (the `+N` is the versionCode) BEFORE `flutter build apk`, then enter that same code in the web admin form.

## UI audit trick (no test suite)

The app is auth-gated with email confirmation ON. To render pages headlessly for UI checks: `npm run dev`, then playwright-core + system Chrome with (1) a fake session JSON (hand-built far-future-exp JWT) in localStorage key `sb-<project-ref>-auth-token` — `AuthContext` only calls `getSession()`, no server verification; (2) `context.route()` intercepting `**/<project-ref>.supabase.co/**` returning mock rows per table from the URL path (`/rest/v1/entities` must return ≥1 entity or `currentEntity` stays null; include embedded join keys like `accounts(name)`; `/rest/v1/rpc/*` → null). When checking horizontal overflow, also test `getBoundingClientRect().left < 0` and ignore the intentionally off-canvas `<aside>`.
