# ShelfShare data model

Multi-tenant field-data platform. **Aystro** is the platform owner; **companies**
(UniPal, NPC, …) are its tenants. Points of sale are labels for data, never users.

## Entities

```
Aystro (platform)
└── Company ─ UniPal
    ├── profiles          company_admin · sales_rep
    ├── products          "these Roboflow classes are mine"
    ├── points_of_sale    supermarkets — city · district · geo
    │     └── fridges     qr_token · real-world size
    │           └── fridge_sections   fixed at setup
    └── visits            rep + POS + date
          └── captures    photo + detections, per fridge section
```

## Decisions worth knowing

**One shared multi-brand model.** Share of Shelf is only meaningful against
competitors, so a per-customer model would always report "you: 100%". There is
one class vocabulary in `products`; `owner_company_id` decides whose product a
class is. **"Competitor" is never stored** — it is resolved at query time
against whoever is asking, which is what lets one model serve every tenant.

**Model version is stamped on every capture.** Different versions give
materially different answers on the same shelf (measured: v1 → 7 detections,
v9 → 2, v11 → 0 on one image). Without `model_id` on the row, swapping models
would render as a shelf collapse in every chart. Because photos are retained,
history can also be re-run through a newer model to rebuild a comparable series.

The version stored is the one that *ran*, not the one the client asked for. The
web proxy may override `model_id` from its own environment so the deployed model
can be switched without rebuilding, and it reports what it used back in an
`X-Effective-Model-Id` header. Recording the request instead of the result would
make a server-side model switch indistinguishable from a collapse in shelf
share — the exact failure this column exists to prevent.

**Sections are fixed at setup, not chosen per visit.** A fridge split three ways
one week and two the next produces a trend line that means nothing. Every fridge
gets at least one section via trigger; single-section fridges never show section
UI.

**Both raw and corrected detections live in one table.** `origin='model'` rows
are the raw prediction and are never deleted; a rep rejecting a false positive
sets `removed=true`. The submitted set is `removed = false`. An editable number
is a gameable number, so the original is always recoverable — and a corrected
box is a verified training label.

A hand-added facing (`origin='manual'`) carries a **synthetic box**, sized to the
median facing of the same class in that capture. There is no way to know where a
missed item sat, and asking someone to draw a rectangle at a fridge door is not
realistic. A zero-area box would have been the honest-looking choice and the
wrong one: Share of Shelf is area-based, so the correction would have raised the
count while leaving the number the customer actually reads untouched. `origin`
is what marks the geometry as inferred; `confidence` is null, because a person
asserting a facing is not a probability.

**Points of sale are per-company.** If two tenants both sell into the same
supermarket, that is two rows. Isolation is easier to get right than to repair.
A shared platform-level store list would enable a cross-brand market view; that
is a deliberate future product decision, not something to fall into by accident.

## Security

Tenant isolation is enforced by Row Level Security in the database, not in
application code — otherwise every future query is a chance to leak.

Two traps that were hit and fixed while building this:

1. **Views do not inherit RLS.** Postgres runs a view with its *creator's*
   privileges unless `security_invoker = on` is set, so the analytics views
   initially read straight past every policy. All four now set it explicitly.
2. **New sign-ins need a representable state.** Users land as `role='pending'`
   with no company and can read nothing until an admin assigns them. Without
   the `pending` role the new-user trigger violated the role/company check and
   every first sign-in failed.

Verified by acting as each role: a UniPal admin sees 2 stores not 3, an NPC
admin sees 1 store and 0 fridges, and a pending stranger sees zero of
everything — through the tables *and* through the views.

## Reporting

| View | Purpose |
|---|---|
| `capture_detection_facts` | One row per detection, ownership resolved |
| `share_of_shelf_by_capture` | Share and facings per class per capture |
| `share_of_shelf_daily` | Daily trend, **grouped by `model_id`** |
| `visit_coverage` | Did the rep visit, and shoot every section? |

`share_of_shelf_daily` excludes captures whose quality was overridden, so a
knowingly-bad photo never moves a headline number.
