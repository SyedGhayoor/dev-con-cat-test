# Super Pixel — solution notes

A multi-tenant Rails platform behind a single embeddable pixel. Every inbound lead is run
through ten fraud/consent layers, a consensus engine turns their answers into one
`ACCEPT`/`REVIEW`/`REJECT` verdict, and a tamper-evident certificate records the evidence for it.

**32 tests, 71 assertions, all passing.**

---

## 1. Running it

Requires Ruby 3.3 and a local Postgres.

```bash
bundle install
bin/rails db:setup      # create + load schema + seed (drops/recreates — use db:reset if the DB already exists)
bin/rails server
```

`config/master.key` is committed for this submission — force-added past the default
`.gitignore` rule — purely so `git clone && bundle install && bin/rails db:setup && bin/rails
server` works with zero extra steps. It only protects an auto-generated `secret_key_base`, not a
real secret, and I would never commit it in an actual project.

`db:seed` doesn't just insert rows: it runs all 12 seeded leads through
`VerificationRuns::Start`, the exact same entry point the pixel's own ingestion endpoint calls.
So the CRM, the certificates, and the super-admin dashboard are populated the normal way, and
seeding proves nothing about the engine is special-cased for it.

| Sign in as | Role | What you see |
|---|---|---|
| `admin@catchingconsent.example` / `ChangeMe!superadmin` | super_admin | Platform overview across every account |
| `dana@solarpro.example` / `ChangeMe!sp1` | account_admin | A full account — CRM, leads, certificates |
| `founder@autoinsure.example` | account_admin | The account 80 credits from empty, `past_due` |

**The live pixel demo — the actual proof this works — is at `http://localhost:3000/demo`.** It
serves `examples/landing-page.html` and `examples/super-pixel.js` directly, the exact files the
assignment shipped, unmodified, pointed at `/api/pixel` on this server. Fill the form, submit,
and watch the panel fill in layer by layer as ten real background jobs actually run. Toggle the
consent checkbox and the TrustedForm layer's outcome genuinely changes, because there's no fake
result sitting behind it — see §2 for what "genuinely" means when there's no real TrustedForm
integration.

Opening `landing-page.html` as a bare `file://` won't reach the backend — its `data-endpoint` is
a relative path that only resolves once Rails is serving the page at `/demo`. To exercise the
actually-interesting case — a buyer's landing page on a *different* domain hitting this backend
— point `data-endpoint` at an absolute URL. CORS is already open for it (`config/initializers/
cors.rb`); see §6 for why that's a wildcard origin rather than an allowlist, and why that's the
right call here rather than a shortcut.

Run the suite with `bin/rails test`.

## 2. Data model

```
Account ─┬─ User (role: super_admin | account_admin | member; account_id null only for super_admin)
         ├─ Pixel ── CaptureSession ── Lead
         ├─ CrmContact                  │
         ├─ PolicyVersion               ├─ VerificationRun ── LayerResult (×10, one per layer)
         │                              │        │       └── ConsensusVerdict
         │                              │        └── ConsentCertificate
         ├─ CreditLedgerEntry (append-only)
         └─ ActivityEvent    (append-only)
```

**A verification run is its own row, not a status on the lead.** The reason isn't abstract —
it's that a lead needs to be re-verifiable (after a policy change, after topping up credits mid-
run) without destroying the record of what happened the first time. So `Lead` just points at
its history of `VerificationRun`s, and every `LayerResult`, the `ConsensusVerdict`, and the
`ConsentCertificate` belong to a *run*, never directly to the lead. A certificate someone already
relied on stays valid even if the lead gets re-checked tomorrow.

**Keeping "not-enabled," "not-applicable," and "actually answered" apart is the whole game in
this domain**, because if any two of those three end up looking the same to the certificate,
you've just told a buyer a check happened that didn't. So `LayerResult#state` is an enum with
four values — `not_enabled`, `not_applicable`, `returned_verdict`, `skipped_insufficient_credits`
— and every run always materializes all ten rows up front, one per known layer, regardless of
what fires. "What was supposed to run" is then a plain row count, never something re-derived from
`Account.enabled_modules` at render time and liable to drift from what actually happened.

**No vendor payloads live in the database as their own tables.** `ProviderFixtures`
(`app/services/provider_fixtures.rb`) reads `mock-data/providers/*.json` off disk, memoized, and
each layer (`app/services/layers/*.rb`) replays the exact fixture for the 12 seeded lead IDs. For
any other lead — meaning anything typed into `/demo` — it falls back to a small heuristic:
real IP comparison, real dwell time, a disposable-email denylist, a real CRM lookup for
duplicates. Every heuristic response is tagged `"_source": "heuristic: ..."` inside the stored
`raw_response`, specifically so nobody looking at a certificate later mistakes a guess for a
vendor call. This is also the only reason the live demo produces non-random results for leads
that were never in the mock data — without it, submitting your own name would either hang or
fake an answer silently.

**Policy is a data row, not a constant.** `PolicyVersion#config` is a `jsonb` column holding
`hard_stops` (an array of codes), `weights` (code → number), and `thresholds`. It can be
platform-wide (`account_id: nil`) or scoped to one account, and `PolicyVersion.default_for`
checks the account's own active policy first, falling back to the platform default. A buyer
tuning "treat suspected litigator as a hard stop" is a one-row edit to their own policy, not a
deploy.

## 3. The consensus engine (`app/services/consensus_engine.rb`)

**The test I used to sort hard stops from weighted signals: is there any amount of other,
cleaner evidence that would make this lead purchasable anyway?** If the answer is no, it's a
hard stop. That gives five, and only five:

| Hard stop | Why nothing else can outweigh it |
|---|---|
| `litigator_confirmed` | A confirmed serial TCPA litigator isn't a lead with a flaw, it's a lawsuit you'd be selling |
| `dnc_not_callable` | A number you can't legally dial is worth nothing to a buyer of *callable* leads, however clean everything else looks |
| `exact_duplicate` | Same phone *and* email as an existing CRM record — the buyer already owns this one |
| `trustedform_mismatch` / `trustedform_expired` | The retained consent record doesn't match or has lapsed — the product's entire value proposition is provable consent, so this is disqualifying by definition |

Everything else — VPN/proxy detected, a site-visit-vs-submit IP mismatch, Anura `suspect`,
*suspected*-but-not-confirmed litigator, providers disagreeing with each other, a soft CRM
duplicate, voice-actor reuse — is a weighted signal instead. The assignment's own framing, "no
layer is the answer by itself," is exactly why these don't get to short-circuit anything: they're
evidence, not verdicts.

**Hard stops are a short-circuit; weighted signals just add up.** Every signal that fires adds
its policy-configured weight to a running score, and two thresholds turn that score into a
verdict — currently `review: 30`, `reject: 60` in the seeded platform policy
(`db/seeds.rb`). One property of the actual seeded weights is worth naming because it's not an
accident: **no single weighted signal reaches the reject threshold on its own** — the heaviest,
voice-actor reuse, is 55 against a reject line of 60. Rejecting on the score always takes at
least two signals agreeing, or a hard stop. A handful of signals (35–55) *are* enough alone to
cross into review, and that's deliberate too — "somebody should look at this" has a much lower
bar than "reject outright."

That threshold gap is also why a soft CRM duplicate, weighted at 20, doesn't sink a lead by
itself: 20 sits under the review line, so a lead that's otherwise clean and merely shares a
phone number with a three-hour-old CRM record still comes back `ACCEPT`, with the duplicate
recorded as a reason on the verdict rather than treated as fraud. It's a commercial question
("should you pay for this record twice?"), not a "is this person real" question, and pricing it
below the threshold is what keeps those two questions from being conflated — no special case
needed anywhere in the code.

**Only a layer that actually ran counts.** `not_enabled` and `not_applicable` layers are
silently excluded from both tiers — that's the fail-open behavior described in §5 of the design
questions below. The one thing that isn't allowed to fail open: if *any* layer got skipped for
lack of credits, the verdict is clamped to at least `REVIEW`, full stop, regardless of what the
score says. An incomplete run is never allowed to look like a clean accept just because the
layers that *did* run happened to come back quiet.

**Tuning any of this is a data change.** Weights, thresholds, and which codes count as hard
stops all live in `PolicyVersion#config`. Arming "suspected litigator" as a hard stop for one
buyer is adding one string to their own account's `hard_stops` array — no deploy, no code
review of the consensus engine itself.

### What actually happens on the 12 seed leads

`db:seed` runs every one of them through the real pipeline, never reading the `expected_verdict`
hint from `mock-data/leads.json` — the engine derives its own answer from provider signals.
Ten land exactly on the hinted verdict; two diverge, and both diverge for the same reason:

| Lead | Hinted | Actual | Why |
|---|---|---|---|
| L-1003 | REVIEW | **ACCEPT** | `acct_medicareedge` never enabled `vpn_proxy`. The only signal that fires is `anura_suspect` (weight 20) — under the review line of 30. |
| L-1009 | REJECT | **REVIEW** | `acct_autoinsure` (starter plan) has none of `vpn_proxy`, `enrichment`, or `voice` enabled. `voice_reused_actor` alone would have scored 55, comfortably past reject — but the layer that would have caught it was never purchased. |

I don't think either of these is a bug. They're the engine correctly refusing to score evidence
it was never shown. The alternative — treating an unpurchased layer as if it silently passed —
is exactly the bug this whole three-state design exists to prevent. It's also a genuinely useful
fact to surface: a starter-plan buyer has a real fraud pattern their module mix can't catch, and
right now nothing tells them that (see §8).

The other ten, for the record:

| Lead | Verdict | Score | Leading reason |
|---|---|---|---|
| L-1001 | ACCEPT | 0 | clean |
| L-1002 | REJECT | 205 | `vpn_or_proxy_detected` (plus several more stacking) |
| L-1004 | REJECT | — | `exact_duplicate` (hard stop) |
| L-1005 | REJECT | — | `dnc_not_callable` (hard stop) |
| L-1006 | REJECT | — | `dnc_not_callable` (hard stop) |
| L-1007 | REVIEW | 58 | `vpn_medium_risk` |
| L-1008 | REVIEW | 40 | `email_providers_disagree` |
| L-1010 | REJECT | — | `trustedform_mismatch` (hard stop) |
| L-1011 | REVIEW | 55 | `litigator_suspected` |
| L-1012 | ACCEPT | 20 | `soft_duplicate` (advisory only, as above) |

`test/services/consensus_engine_test.rb` deliberately tests against **synthetic** `LayerResult`
fixtures, not these 12 leads — so the tests can't quietly encode `expected_verdict` the way the
engine itself is forbidden to.

## 4. Multi-tenancy & authorization

**`Current.account` is the one place "whose data is this" gets decided**, and it's derived from
`Current.user.account` — so it's `nil` for `super_admin` by construction. There's no separate
flag to remember to check; a super-admin simply doesn't have an account.

That alone wouldn't stop a mistake, though, so the actual enforcement is structural:
`TenantScoped` (`app/models/concerns/tenant_scoped.rb`) puts a `default_scope` on every
tenant-owned model that filters by `Current.account` and **raises if no tenant context is set at
all**. Write `Lead.find(params[:id])` by mistake instead of `current_account.leads.find(...)`,
and it doesn't quietly return the wrong account's row — it raises before the query even runs. I
checked this isn't just true in the common case: a bare `Lead.find_by(...)` with no tenant
context raises `Current::NoTenantContextError` every time. Background jobs, the pixel endpoints,
and `db/seeds.rb` have no logged-in user at all, so each of them sets `Current.account`
explicitly from whatever *does* establish the tenant at that point — the pixel a lead came in
through, the run's own account inside a job — and every one of those is a visible, deliberate
`.unscoped` call at exactly the boundary where no tenant exists yet, not a scattered escape
hatch.

**A second, independent layer sits behind that one.** Every model has a Pundit policy, and
`ApplicationController` runs `verify_authorized`/`verify_policy_scoped` after every action — a
controller that forgets to call `authorize` fails the request outright rather than silently
serving something unchecked. Because the policy re-derives ownership from the *loaded record's*
`account_id`, a `Lead` that reaches the view through a forgotten join is still checked correctly;
it doesn't matter how the record got there.

Both kinds of violation render **404, not 403**, so an attacker probing another account's IDs
can't tell "doesn't exist" from "exists, isn't yours." And `super_admin`'s power is confined
entirely to the `Admin::` namespace — every other controller uses the ordinary
`current_account.foo` pattern, which raises for a super_admin exactly like it would for a
tenant-context bug, rather than accidentally returning everything because nobody's account_id
happened to be set.

`test/integration/tenant_isolation_test.rb` doesn't just inspect this — it logs in as one
account, takes real IDs belonging to a different one, and hits every read/write route, asserting
404 across the board while also confirming the same account's *own* data is still reachable.
Isolation that also breaks your own data isn't isolation, it's a bug with a different name.

## 5. Credits & jobs

**One background job per layer** (`RunLayerJob`), all ten fired at once by
`VerificationRuns::Start` right after a lead is created. This isn't fan-out for its own sake —
ten independently-failable I/O calls per lead is the textbook case for it, and it's what makes
the live panel genuinely stream real results rather than fake a delay. Each job resolves its own
state — not_enabled, not_applicable, returned_verdict, or skipped_insufficient_credits — so one
slow or failing layer never blocks the other nine.

**A credit is spent per layer *attempted*, not per lead and not only when a layer returns a
clean verdict.** "Attempted" means the mock/heuristic call actually ran, even if the answer was
`not_found` — a real vendor bills you for that query too. `not_enabled` and `not_applicable`
never spend anything, and that's enforced structurally: `RunLayerJob` only calls
`debit_credits!` on the path where a layer actually ran.

**The check and the debit are one atomic operation, not two.** `Account#debit_credits!` takes a
row lock and checks `credits_remaining` *inside* it:

```ruby
with_lock do
  return :insufficient if credits_remaining < amount
  update!(credits_used_this_cycle: credits_used_this_cycle + amount)
  credit_ledger_entries.create!(delta: -amount, balance_after: ...)
end
```

That's not a stylistic choice — an earlier version checked the balance before locking, and
several concurrent layer jobs racing against the same account each read the same
not-yet-updated balance and each proceeded to spend it, driving the account negative under real
concurrency. `test/models/account_test.rb` spins up five real threads each trying to spend a
credit against a balance of two, and asserts exactly two succeed and the balance lands on zero,
never below — which is the test that caught the original bug and now guards against it coming
back.

**Running out mid-verification** marks that one layer `skipped_insufficient_credits` — never
conflated with `not_enabled`, because "we chose not to buy this" and "we ran out of money" are
different facts a buyer might care about differently — the run finishes with whatever did run,
and §3's clamp means the verdict can be no better than `REVIEW`. `acct_autoinsure`, seeded at
80 of 8,000 credits and `past_due`, is the account that actually exercises this path, and the
super-admin dashboard (`AccountBurnPresenter`) flags it: `at_risk?` is true whenever an account
is past due, at zero credits, or projected to run dry within a day at its current burn rate.

## 6. Real-time transport: SSE

`Api::Pixel::ActivityController#stream` is `ActionController::Live` + Server-Sent Events — not
ActionCable, not plain polling from the client.

- The channel only ever flows server → browser. The pixel-spec's own suggested contract
  (`layer_result` / `final_verdict` events) is already SSE-shaped, so a full-duplex protocol
  would be paying for a direction nothing uses.
- SSE is a plain `GET`, so the capability token that gates the stream (below) just travels as a
  query param. ActionCable's connection handshake would need its own `identified_by` scheme for
  an anonymous site visitor, for no actual benefit here.
- **Delivery is a cursor-based poll against `ActivityEvent`, not an in-process queue**, and this
  is the choice I'd defend hardest. An earlier version used an in-memory Ruby `Queue` keyed by
  lead, and it worked — but only because the job writing a result and the browser reading it
  happened to be alive in the same process at the same time. I proved that mattered rather than
  assumed it: I ran a lead to completion from a totally separate OS process (`rails runner`, not
  the running server), then opened the SSE stream against the *already-running* server, which
  had never touched any of that lead's jobs — and it replayed the full ten-layer history
  correctly, because both sides only ever read the same database row. The in-memory version
  would have hung forever on exactly that sequence.
- Reconnecting starts the poll cursor at `0`, so it naturally replays everything that already
  happened before catching up to whatever's still running. A page refresh mid-verification and a
  `/demo` visit after the fact both just work — no separate "already complete" branch to write or
  forget.
- **The trade-off**: each open connection costs a small, constant amount of DB load — one query
  roughly every 300ms — instead of costing nothing while idle. `with_connection` checks a
  connection out of the pool for just that one query and returns it immediately, specifically so
  a long-lived SSE connection doesn't hold a pool slot for its entire life, sleep included; a
  handful of open demo panels would otherwise be enough to stall every other request on the site.
  At real scale, `LISTEN/NOTIFY` or Solid Cable replaces the poll loop without the controller's
  shape changing at all — it still reads a cursor and writes an SSE event, just on a different
  trigger.

**The three questions `docs/pixel-spec.md` asks for:**

- *Stopping a pixel_id from writing into another account*: `account_id` is never read from the
  request body at all. `IngestionController#find_pixel` resolves the account exclusively from
  `Pixel.find_by!(public_id: params[:pixel_id])`, so a spoofed or guessed pixel_id can only ever
  attribute a lead to whichever account actually owns that pixel.
- *Abuse and replay*: `/leads` is idempotent on the visit's `capture_session` — resubmitting
  returns the lead that already exists instead of creating a second one — and it's rejected
  outright (422) unless a matching `/visit` beacon for that session already happened. On top of
  that, `rack-attack` throttles every `/api/pixel/*` request to 60 per IP per minute, since these
  endpoints are necessarily unauthenticated and IP-based throttling is the only line of defense
  available before a session even exists.
- *Client-side vs. server-side*: the pixel only ever holds a public `pixel_id` and a
  client-generated `session_id`. Every trust decision — the account, the verdict, the score — is
  computed and stored server-side, never trusted from the payload. The one thing worth calling
  out specifically: the stream is gated by the **activity token** returned from `POST /leads`,
  not by the `lead_id` itself. Lead IDs are sequential-ish and the channel has no session to
  check, so a bare `lead_id` would let anyone enumerate and watch another buyer's live
  conversion activity. `test/integration/pixel_ingestion_test.rb` posts a deliberately wrong
  token and asserts the stream refuses it.

**On the CORS config specifically**: `config/initializers/cors.rb` scopes to `/api/pixel/*` but
allows `origins "*"` — a genuinely open origin, not an allowlist. That's not a shortcut; it's
the only correct answer for a pixel that's meant to be embedded on landing pages this platform
has never seen before and can't enumerate in advance. The security boundary for this endpoint
was never going to be the browser's Origin header — it's the pixel_id → account resolution and
the activity token above. Scoping CORS to a fixed list of origins here would just be a false
sense of security for a product whose entire job is running on someone else's domain.

## 7. Consent certificates (`app/services/consent_certificates/issue.rb`)

Issued automatically the moment a verdict is reached, from a frozen **snapshot** — every layer's
raw response, its state, the credits it cost, plus the verdict, score, and reasons — so a buyer
can defend a lead later without depending on live rows still existing in their original shape.

**Tamper-evidence, three separate layers, because a signature alone answers a narrower question
than it looks like it does:**

1. **`content_hash`** is a SHA-256 of a *canonicalized* — recursively key-sorted — JSON
   serialization of the snapshot. This isn't defensive dressing: Postgres `jsonb` doesn't
   preserve key insertion order, so I hit this for real — hashing `snapshot.to_json` before a
   save and after a reload produced two different hashes for identical content, purely from key
   reordering. Canonicalizing before hashing (`ConsentCertificate.canonicalize`) fixes it for
   good, not just for the cases I happened to test. `cert.verify` recomputes the hash and
   compares; mutate the snapshot and it flips false.
2. **A per-account hash chain.** A single hash proves *one* certificate's content wasn't edited
   — it says nothing if a row is deleted outright or two are swapped, which a single-document
   signature can never catch by itself. Every certificate stores the previous one's
   `content_hash` as its own `previous_hash`, with a `sequence_number` unique per account, and
   `ConsentCertificate.chain_intact?` walks the whole sequence checking every link. Delete or
   reorder a certificate and the chain breaks even though every remaining certificate's own hash
   still checks out.
3. **A database trigger, not just an absence of an update route.** No code path in this app ever
   calls `update!` on a `ConsentCertificate` — but that stops the *app*, not a raw SQL statement
   run directly against the database. `db/migrate/..._add_immutability_trigger...` installs a
   Postgres trigger that raises on any `UPDATE` or `DELETE` against the table, full stop. This is
   also why `config.active_record.schema_format = :sql` is set: the default `schema.rb` dumper
   has no way to express a raw trigger, so a plain `:ruby` schema would silently drop this
   guarantee on the next `db:reset` — the SQL dump (`db/structure.sql`) is the only format that
   can carry it at all.

Two access levels, matching who's allowed to know what: `GET /certificates/:uid` is
tenant-scoped and shows everything, for the account that owns the lead; `GET
/certificates/:uid/verify` needs no login and shows only the verdict and whether the hash still
matches — no PII — so a buyer can hand that link to opposing counsel without handing over the
lead's contact details in the process.

The TrustedForm reference is only cited on the certificate if that layer actually came back
`verified` — a mismatched, expired, or not-found result is never quietly presented as supporting
evidence just because a URL happened to exist.

## 8. What I stubbed, and what I'd build next

**Stubbed on purpose:**

- No real vendor calls, as instructed — fixtures for the 12 seed leads, tagged heuristics for
  everything else, no real email or billing.
- **Burn rate** is the static `avg_daily_burn` shipped in the mock data, not recomputed from the
  credit ledger's own history. With only a handful of demo leads, a real rolling average would be
  noise, not signal — but the ledger already has everything a real computation would need once
  there's enough volume to make one meaningful.

**Known gaps, in the order I'd close them:**

1. **No policy-editing UI.** `PolicyVersion` is fully data-driven — weights, thresholds, and
   hard-stop membership are all just JSON — but changing them today means a console session or a
   seed edit, not a screen. This is the first thing I'd build.
2. **The L-1009 gap has no warning surface.** §3 treats the divergence as correct behavior, and I
   still think it is — but "correct" and "harmless" aren't the same thing. A starter-plan buyer
   genuinely has an uncaught fraud pattern, and nothing today tells them that. A "your enabled
   modules don't cover common fraud vectors" flag on the account or super-admin dashboard would
   close that loop, and I'd build it right after the policy UI.
3. **SSE's remaining scale ceiling is poll frequency vs. DB load per open connection** — not
   process-affinity anymore, since §6's fix already made the stream survive a restart and work
   across multiple Puma processes. `LISTEN/NOTIFY` or Solid Cable would remove the poll entirely
   without touching `ActivityController`'s actual shape.
4. **No browser/Capybara tests.** I verified the live pixel flow with direct HTTP and SSE
   requests — the same requests the browser's `fetch`/`EventSource` calls make — rather than a
   headless browser, given the time available. `bin/rails test` covers the consensus engine,
   tenant isolation, ingestion security, and the credit-ledger concurrency race; none of it
   exercises an actual DOM.

**The biggest risk in the current design** is the same one §3 already names: a buyer on a cheap
module mix can have a real, silent fraud gap, and the consensus engine itself has no way to flag
that — it can only score what it was shown. Closing that gap is a dashboard/product problem, not
an engine problem, which is exactly why it's item 2 above rather than a change to
`ConsensusEngine` itself.

## 9. Design questions (`docs/DESIGN_QUESTIONS.md`)

**Domain modeling**

1. §2's diagram. `VerificationRun` is the aggregate root for one verification attempt — `Lead`,
   `LayerResult`, `ConsensusVerdict`, and `ConsentCertificate` all hang off the *run*, not off
   each other — which is what makes multiple runs per lead, and the credit-exhaustion story in
   §5, representable without rewriting history.
2. A `state` enum on `LayerResult` — `not_enabled` / `not_applicable` / `returned_verdict` /
   `skipped_insufficient_credits` — and every run always writes all ten rows, so "what should
   have run" is a row count, never a re-derivation.

**Consensus engine**

3. Five hard stops — confirmed litigator, DNC, exact duplicate, TrustedForm mismatch/expired —
   chosen by one test: is there any amount of other clean evidence that makes the lead
   purchasable anyway? For these five, no. Everything else is weighted, including Anura
   `suspect` and *suspected* (not confirmed) litigator, both of which the assignment itself flags
   as judgment calls rather than certainties.
4. §3 — an additive score against policy-configured weights, banded by two thresholds
   (`review: 30`, `reject: 60` in the seeded policy). No single weighted signal reaches the
   reject line alone; a reject always takes either a hard stop or at least two signals agreeing.
5. **Fails open per layer, not per run.** An unavailable or never-purchased layer contributes
   nothing to the score, silently — the run still completes with whatever did run. The one
   exception: credit exhaustion specifically (as opposed to "never enabled") clamps the verdict
   to at least `REVIEW`, because an incomplete run is a different fact from an intentionally
   narrow one.
6. Policy is data — `PolicyVersion#config` — scoped per account with a platform-wide fallback. A
   buyer arms "suspected litigator" as a hard stop by editing their own policy row; nothing in
   `ConsensusEngine` changes.

**Multi-tenancy & authorization**

7. At the query layer: `current_account.foo.find(...)` plus a `default_scope` that raises
   outright if no tenant context is set, plus an independent Pundit re-check against the loaded
   record's own `account_id`. See §4 for the adversarial test that actually attacks it.
8. `super_admin` simply has no `account_id`, so `Current.account` is `nil` for them by
   construction — every ordinary controller path raises rather than defaulting to "everything."
   Cross-account access exists only inside `Admin::` controllers.

**Credits & subscriptions**

9. Per layer *attempted*, not per lead and not only on success — because a vendor bills for the
   call it made, not for the answer you liked. See §5.
10. The specific layer is marked `skipped_insufficient_credits`, the run completes with whatever
    ran, the verdict is clamped to at least `REVIEW`, and the super-admin dashboard
    (`AccountBurnPresenter`) flags any account that's past due, at zero, or projected to run dry
    within a day at its current burn rate.

**Consent certificates**

11. Every layer's raw response, state, and cost, plus the verdict/score/reasons, frozen at
    issuance. Tamper-evidence is three independent layers — canonicalized SHA-256, a per-account
    hash chain that also catches deletion/reordering, and a Postgres trigger blocking raw SQL
    mutation — verifiable by anyone at `/certificates/:uid/verify`, no login, no PII.

**Real-time & jobs**

12. Background, one job per layer — see §5. Ten independent I/O-bound vendor calls is the
    textbook fan-out case, and the visitor's browser was never going to wait on all ten serially.
13. SSE — see §6 for the full trade-off. Chosen for one-directional flow, a plain-GET auth model,
    and — the reason I'd defend hardest — lossless recovery off a database cursor rather than an
    in-process queue that a restart would silently empty.

**If I had another week**

14. First: a policy-editing UI, then the "your modules don't cover common fraud vectors" warning
    from §8. Biggest risk: the same section — a buyer on a cheap plan can carry a real, silent
    fraud gap that only a proactive warning, not the consensus engine itself, can close.
