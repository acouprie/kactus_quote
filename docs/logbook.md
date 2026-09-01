# Quote System

I will write in this file all the notes I take while implementing the exercise, to document my
reasoning and choices.

This file is meant to be updated as I go, so that it can be read in parallel with the code. It is
not a final report, it is a logbook.

## Scope of this document

Two documents describe the project, and they do not overlap:

- **`logbook.md` (this file)** owns the _reasoning_: assumptions, trade-offs, rejected alternatives,
  and every decision taken where the brief was silent. It is the source of truth for why the code is
  the way it is.
- **[`architecture.md`](architecture.md)** owns the _structure_: the diagrams, the data model, and
  the sequence of the one non-trivial interaction. It is the source of truth for what is persisted
  and in what order things happen.

When a rule appears in both, this file holds the justification and `architecture.md` holds the
shape. Neither restates the other, so there is only ever one version to keep correct.

## Reading the specifications

A few points came up on first read that need an explicit assumption or answer, since the brief
leaves them open:

- "Edit a quote" also covers editing its items, not just the quote's own name.
- "A validated quote can no longer be modified" also blocks adding, editing and destroying its
  items, as confirmed by the Figma.
- Deletion is a hard delete. Archiving as a soft-delete alternative is logged as an evolution idea.
- Is there an authenticated user, with quotes scoped to them ("my quotes"), or a single unscoped
  list? The "as a user" phrasing is taken as standard user-story wording rather than an
  authentication requirement. Authentication is out of scope.
- The brief requires exactly two screens, one to list quotes and one to display a single quote, with
  every item interaction happening on the quote screen. The Figma matches: two pages, and three
  frames since the quote screen has a draft variant and a validated variant. Nothing else may become
  a screen. See "Screens and navigation", which is where this constraint actually bites.
- **Where is a quote's name entered?** The brief says a quote has a name but never says where it is
  typed, and the Figma does not show it: the list has an "Ajouter un devis" button with no visible
  input, and the quote screen shows the name as a title next to an "Enregistrer et quitter" button.
  Resolved by an explicit decision, see "Screens and navigation".
- Can a quote be validated with zero items? Resolved, see Recruiter clarifications.
- Is item quantity an integer or a decimal (half-days, m2, hours)? There is no separate unit field,
  so the unit of measurement is implicit in the item's name. Resolved, see Recruiter clarifications.
- The VAT rate appears as a select in the Figma. Fixed list of standard rates, or free decimal
  value? Resolved, see Recruiter clarifications.
- VAT is set per item rather than per quote, so Total TVA is an aggregation of several amounts.
  Which aggregation and rounding strategy? The choice changes the total by a few cents. Resolved,
  see Recruiter clarifications and "The VAT computation contract".
- The Figma shows the add-item row with no visible way to cancel it if opened by mistake. Resolved,
  see Recruiter clarifications.
- The Figma is ambiguous about where the add-item row appears. In the "Composants" frame it is the
  last row of the table, just above the "Ajouter un article" button; in the "Ecrans" frame it
  appears between two existing rows. Decision: the row is always appended as the last row. It is the
  only position that stays predictable when several items are added in a row, and it keeps the
  "Ajouter un article" button immediately below it. Letting the user reorder items is logged as an
  evolution idea, and it is the change that would make this question real.

The Livrables section also refers to an "improvement" part that is never introduced earlier in the
brief. Taken as a short written note, format and location left open as the brief itself states,
covered here by the [Evolution ideas](evolution_ideas.md) section and linked as such from the README.

### Recruiter clarifications

I reached out to the recruiter with the five points still open above. Their answer: these
ambiguities are intentional, there is no single correct answer, and how they are resolved and
documented is part of what is being evaluated. The only non-negotiable point is the one already
stated in the brief, a validated quote can no longer be modified or deleted. Decisions taken as a
result:

- Item quantity is a decimal.
- VAT is a fixed, selectable list: 0, 5.5, 10, 20.
- VAT aggregation: each line's net amount is rounded to 2 decimals first, lines are grouped by VAT
  rate, and VAT is calculated once per rate group on that group's summed net subtotal. Per-line VAT
  and gross amounts are then reconciled against their group's authoritative VAT so that the
  displayed line amounts sum exactly to the quote totals. Full algorithm in "The VAT computation
  contract".
- A quote cannot be validated with zero items. Attempting it is refused rather than storing a quote
  that is both meaningless and impossible to delete afterwards.
- Cancelling an item add: the mockup shows no cancel affordance on the add-item row, only the
  validate action, which reads as an oversight rather than an intentional constraint, since every
  other reversible action in the mockup (delete) has a visible icon rather than a keyboard-only
  path. Decision: add a small cancel button next to the validate checkmark, styled like the existing
  edit/destroy icons, with Escape kept as an additional shortcut rather than the only way out. In a
  real project this UI change would go through the PM and the designer during shaping rather than be
  decided unilaterally by a dev. Noted here as the kind of trade-off that gets flagged to the team
  rather than shipped silently.

## Screens and navigation

The brief is explicit: two screens, and every item interaction happens on the quote screen. That
constraint is what settles the open question about the quote name, so both are treated here.

**Consequence on the controller.** `QuotesController` exposes `index`, `create`, `show`, `update`,
`destroy`, plus a `new` action that returns a Turbo Frame fragment and never a full page. There is
deliberately **no `edit` page and no `new` page**: either would be a third screen. Renaming happens
in place on the quote screen, so `edit` has no reason to exist at all.

**Quote list screen.** Columns ID, Date and Nom, per the Figma. "Date" is `created_at`, the only
date every quote has, and the list is sorted by `created_at` descending so the most recent work is
on top. Row actions follow the Figma, and they are the visual translation of the immutability rule:

- a draft carries the pencil (open the quote screen) and the trash (delete, with `turbo_confirm`);
- a validated quote carries the eye only, and no destructive action at all.

Both icons lead to the same `show` route; the screen renders its draft or validated variant from the
quote's status. The list never renders a delete button for a validated quote, but that is an
affordance, not the rule: the rule is enforced in the model.

**Creating a quote.** Clicking "Ajouter un devis" appends an inline row to the bottom of the list,
inside a Turbo Frame, with a name field, a validate button and a cancel button. Same pattern and
same machinery as the add-item row on the quote screen.

Why this rather than a "new quote" page or a modal: the Figma frames the "Ajouter un devis" button
in a dashed zone at the bottom of the table, in exactly the same way as "Ajouter un article" at the
bottom of the item table, and the item table does show its inline row explicitly. Reusing a pattern
the mockup already contains, rather than introducing a new one, respects the two-screen constraint
literally, keeps the `name` presence validation honest (no quote is ever created without a name),
and avoids leaving an orphan "Nouveau devis" behind whenever the user changes their mind. The row
itself is not in the mockup, so this is a deliberate addition, same class of decision as the cancel
button above.

On success, `POST /quotes` responds with a 303 redirect to the new quote's screen, since the intent
behind creating a quote is to fill it in. Implementation note that is easy to get wrong: a redirect
issued to a form living inside a Turbo Frame is followed _inside that frame_, and the quote screen
contains no frame with a matching id, so the form must carry `data-turbo-frame="_top"`. Without it
the browser shows "Content missing" and nothing else happens.

**Quote screen, draft variant.** Title showing the quote name as an editable field, "En cours
d'édition" badge, item table, totals block, "Valider le devis" button, and the "Enregistrer et
quitter" button in the top left. That last button is the only thing that persists the name: it sends
`PATCH /quotes/:id` and redirects to the list with a 303.

This creates an asymmetry worth stating, because it is a decision and not an oversight: **the name
is saved on exit, the items are saved immediately**. Items are separate resources whose every write
has to update the totals block anyway, so deferring them would mean holding an unsaved sub-form; the
name is a single field of the parent, and the mockup's own labels ("Enregistrer et quitter" on the
draft against a plain "Quitter" on the validated screen) only make sense if the draft screen has
something to save.

The known cost: leaving the screen by the browser's back button, or by a link that is not
"Enregistrer et quitter", loses a pending rename silently. Accepted for this scope, and logged as an
evolution idea. It is written down here rather than discovered later.

**Quote screen, validated variant.** "Validé" badge, read-only item table, totals block, "Quitter"
as a plain link back to the list. No validate button, no edit or delete icons, no add-item row.

**Item table columns.** Article, Qte, PU HT, TVA, Total HT, Total TTC, per the Figma. The TVA column
displays the **rate** (`20 %`), not an amount: the mockup renders it as a select in the add-item
row, which settles it. There is therefore no per-line VAT _amount_ anywhere in the interface, which
matters for the reconciliation described further down.

## Deliberately kept simple

The brief asks for production-level code and, in the same breath, for quality over quantity. Several
things I would do on a real invoicing product are deliberately left out here. They are listed with
what they would protect against, so that the omission reads as a decision rather than as an
oversight. Each one is also in [Evolution ideas](evolution_ideas.md).

- **No snapshot of the computed amounts at validation.** In production I would persist the totals
  and the per-line amounts when a quote is validated, and read them back afterwards, because the
  aggregation lives in code and code changes: a rounding fix or a refactor would move the totals of
  a quote somebody already committed to. Here the items are immutable once validated and the rate
  list is fixed, so recomputing gives the same numbers for as long as the algorithm does not change.
  The snapshot would cost six nullable columns, two CHECK constraints tying them to the status, a
  forced write order inside the validation transaction and a set of tests, to protect against a risk
  that cannot materialise within the life of this exercise. Consequence to accept knowingly: a
  validated quote is only as stable as `QuoteTotals`, and the day that class changes, every
  validated quote changes with it.
- **One concurrency mechanism, not two.** Every write path wraps the quote in `with_lock`, which
  locks the row and re-reads its state inside the transaction. No `lock_version`, no optimistic
  locking, no `StaleObjectError`. Consequence: two people renaming the same quote at the same time
  end in last-write-wins rather than in a conflict message. In production I would add optimistic
  locking on the rename and a "someone else just edited this, reload?" banner.
- **No database CHECK on the VAT rate.** The allowed list is enforced by a model validation only.
  The database constraint earns its place when a bad rate can contaminate a stored total that nobody
  can re-derive; with nothing aggregated in the database, a wrong rate is visible on screen and
  correctable. The real answer at product scale is a rates reference table with validity periods,
  not a hardcoded constraint anyway.
- **One layer of upper bounds instead of three.** Only the two user inputs are capped, see "Money
  representation". No checks on derived amounts, since none is persisted.
- **No 409 on an immutability refusal.** The refusal is turned into a flash plus a 303 redirect to
  the quote screen, which is what a REST-purist would write as a 409 Conflict. Reason: Turbo is
  explicit about how it handles 2xx, 303 and 422, and much less so about a Turbo Stream body carried
  by another error status, and these paths are not reachable from the interface anyway. Choosing the
  status Turbo definitely handles removes an open question and a class of bug for no loss of
  behaviour. A JSON API version of this application should answer 409.

## Out of scope

Deliberately not implemented, since they are not covered by the functional requirements and would
move well beyond the reduced scope described in the brief:

- **Authentication and authorization**: no login, no partner account. The single actor in the
  diagrams is anonymous, and every quote is visible to everyone using the application.
- **Multi-tenant separation**: no partitioning of quotes by partner, consistent with the above.
- **PDF export**: no way to export or print a quote. Logged as an evolution idea since it is
  arguably central to the tool's stated purpose (sending quotes to clients).
- **Sending to the client**: no email delivery. Same reasoning.
- **Discounts**: no percentage or fixed-amount discount at item or quote level.
- **VAT categories and exemptions**: the model carries a rate and nothing else. See "A note on what
  0 % actually means", which explains why that is a simplification rather than a neutral choice.
- **Multiple currencies**: prices are in a single implicit currency (euro).
- **Legal or sequential quote numbering**, which some jurisdictions require on official quotes.
- **Validity conditions**: no expiry date or validity period.
- **Electronic signature**: no client-facing acceptance flow.
- **Versioning**: no history of changes beyond the draft to validated transition and the hard delete
  decision above.
- **Deployment**: no deployment to a live server. The application is kept deployment-ready on a PaaS
  (see Project setup).

## Use of AI

I use AI, mainly Claude, as a partner to challenge my choices and help write documentation, staying
as close as possible to real-world practice. To simulate peer review, I set up Claude Code as a PR
reviewer on GitHub, acting as a virtual colleague. I also use AI-powered autocompletion (Mistral AI)
in my IDE.

## Project setup

### Implementation choices

The application is a Ruby on Rails monolith, matching the stack described in the job posting. Rails
7.2 and Ruby 3.3. To be accurate about what that pin costs: the
3.3 branch entered security-only maintenance in March 2026 and is supported until March 2027, so it
takes security fixes but no more bug fixes, and Rails 7.2 also runs on the fully maintained Ruby
3.4. Aligning on the stack actually in use still matters more here than being on the newest version,
and the choice is dated rather than implicit.

Hotwire (Turbo and Stimulus) drives the dynamic behaviour of the item table, which gives a smooth
editing experience without full page reloads.

PostgreSQL as the database, since it is the system I am most comfortable with and it handles exact
decimal arithmetic natively, which matters here (see Money representation).

Everything runs through Docker Compose: the application, PostgreSQL, and a
`selenium/standalone-chromium` service for the system tests, so the project starts on any machine
without installing Ruby, Postgres or Chrome locally. CI does not run inside that same image: the
GitHub Actions `test` job installs Ruby directly on `ubuntu-latest`, with Postgres and Selenium as
service containers rather than `docker compose`. The `bundle exec rspec` command is identical either
way, and both service images are pinned to the versions `docker-compose.yml` uses, but the
surrounding environment is not the same.

`db/seeds.rb` creates a handful of quotes covering the cases that are hard to see otherwise: several
VAT rates on one quote, a rate group where the cent reallocation actually fires, a quote made only
of 0 % lines, an empty draft, and one already validated quote. It costs ten minutes and it means the
interesting behaviour is visible in thirty seconds rather than only described in this file.

The code is on GitHub, in a public repository, with `main` protected by a ruleset (linear history,
pull request required, status checks required). Work happens in dedicated branches merged through
pull requests, tracked on a Kanban board with one card per story.

### Money representation

Money is never stored or computed as a floating point number. The failure is not that `Float#round`
picks the wrong rounding mode, Ruby's is half-up and even compensates for the binary representation
(`2.675.round(2)` returns `2.68`, where several other languages return `2.67`). The failure is
upstream, in the arithmetic that happens _before_ any rounding: `(4.35 * 100).to_i` returns `434`,
and `0.1 + 0.2` is not `0.3`. Converting an amount to cents is exactly that operation, and it is the
one this project performs on every line.

Columns and bounds:

- `unit_price_excl_vat` and `quantity` are both `decimal(10, 2)`, mapped to `BigDecimal` in Ruby.
  `unit_price_excl_vat` is zero or positive; `quantity` is strictly positive, with two decimals
  covering realistic fractional units (half-days, quarter-hours, square metres) without inviting
  precision that means nothing commercially. The two columns share the same precision because the
  same application bound (99 999.99, below) already caps them identically: giving either one more
  room in the column would add headroom nothing in the app is allowed to use.
- `vat_rate` is `decimal(5, 2)`, not an integer, since 5.5 is one of the allowed values. The allowed
  list is enforced by a model validation.
- Both user inputs are capped at 99 999.99. That bound is not dictated by the column: `decimal(10,
  2)` holds values up to 99 999 999.99, far above it. The cap is deliberately set well inside that
  range, commercially absurd for an events quote, so that the failure mode for any value a user
  could plausibly type is a form error, never a database exception. Without it, a value large
  enough to actually exceed the column would still make PostgreSQL answer
  `numeric_value_out_of_range`, surfacing as a 500 instead of a form error; setting the bound far
  inside the column's range is precisely what keeps that case from ever being reached.

Input parsing, which is where the two subtle bugs are:

- A French user typing `12,50` must be read as `12.50`. Rails' decimal cast reads `"12,50"` as `12`
  without raising, because `String#to_d` stops at the comma. Amount and quantity fields are
  therefore normalized **on the raw string, before assignment**.
- Rejecting a value with more decimals than the column can hold has to happen on the raw string too,
  and this is the part that is easy to get wrong. It is **not** PostgreSQL that rounds `1.755` to
  `1.76`: `ActiveModel::Type::Decimal#cast_value` calls `apply_scale` and rounds to the column's
  scale at **assignment** time, so a validation reading the cast attribute never sees the third
  decimal and silently passes. The validation reads `quantity_before_type_cast` and
  `unit_price_excl_vat_before_type_cast`. Same reason `normalizes` is not the right tool for the
  comma above: it runs after the cast, when `"12,50"` has already become `12`.

Arithmetic:

- The VAT computation and the cent allocation are carried out in integer cents, which makes the
  rounding and remainder logic exact and easy to reason about. The one step that cannot be done in
  cents is the line net amount itself, `quantity * unit_price_excl_vat`, since quantity is not a
  monetary value: that product is computed in `BigDecimal` and rounded to 2 decimals, and everything
  downstream works from that rounded value.
- Every explicit rounding uses half-up (half away from zero), the usual accounting convention, never
  banker's rounding. `BigDecimal#round` already defaults to half-up, but the mode is passed
  explicitly anyway: half-even is a common default in other stacks, so leaving it implicit invites a
  future contributor to change it without realising it moves published totals. `BigDecimal.mode` is
  process-global and is never touched.

#### A note on what 0 % actually means

The allowed rates are 0, 5.5, 10 and 20, and the model stores nothing but a rate. That is a
simplification, and conflating the things it collapses would be a real mistake in an invoicing
product, so it is stated rather than glossed over.

A partner under the French _franchise en base de TVA_ does not charge VAT, but that is an exemption,
not a 0 % rate and not an operation outside the scope of VAT. In EN 16931 the distinction lives in
the VAT category code (BT-118: `S` standard, `E` exempt, `O` out of scope, `Z` zero-rated), not in
the rate (BT-119), and an exempt or out-of-scope category requires a stated exemption reason
(BT-120/BT-121). French e-invoicing practice maps the _franchise en base_ to category `E` with the
mention "TVA non applicable, art. 293 B du CGI". All of these cases produce the same amount, zero,
and none of them is interchangeable with the others on a commercial document.

So: a 0 % line here means "no VAT is charged", full stop, with no statement about why. That is
enough for the exercise and wrong for production. Adding a VAT category alongside the rate, with its
exemption reason, is logged as an evolution idea.

The narrower rates (2.1 %, and the specific Corsica and overseas rates) are not in the list and are
not relevant either: the business is events, so the realistic rates are 20 for services, 10 for
accommodation and some catering, 5.5 for some food, and the zero case above.

### Testing strategy

Testing uses RSpec. Coverage is not the target, relevance is, and that is stated as such in the
README rather than left implicit:

- Dense unit tests on `QuoteTotals`: totals, VAT rounding, remainder allocation. That is the
  business risk. A wrong total is both easy to introduce and easy to miss.
- Request specs on the immutability rule, including paths the interface does not expose, since that
  is the data-integrity risk. The test that matters is a direct `PATCH` to an item of a validated
  quote, which a UI-only guard would miss entirely.
- Model specs on the validations that carry a business rule: name presence, quantity strictly
  positive, unit price non-negative, both within their bounds and their column's scale, VAT rate in
  the allowed list. These are not Rails' own validations being re-proved, they are the contract that
  makes the money computation safe, and the arithmetic section leans on them explicitly. What is
  _not_ tested is Rails itself.
- System specs, driving a real browser, only where the behaviour cannot be observed from a
  request spec: a redirect out of a Turbo Frame that a request spec reads as a correct 303 while
  the browser renders "Content missing", focus retention between two submissions, dismissal by
  the Escape key, confirmation dialogs (`turbo_confirm`), and the composition of all of it on the
  full quote flow. Four files, not four examples: several of them carry more than one example, and
  the rule is the boundary, not the count. Anything a request spec can assert is asserted there,
  since it is faster and it fails more precisely.
- Nothing on framework behaviour that no project-specific rule depends on.

Two invariants get their own named specs rather than being checked incidentally inside broader
examples, because they are the properties the whole money section exists to produce:

- `total_gross_amount == total_net_amount + total_vat_amount` on any quote.
- The lines sum to the totals, column by column: the sum of the line net amounts equals the quote's
  net total, and likewise for VAT and gross.

All three levels run in CI on every pull request and on every push to `main`, system tests
included, since they are the ones most likely to catch a regression the other two miss.

### Project initialization

I start with a Git repository and a README in English, as the brief requires, while the interface is
French; the two are not in tension since no user-facing string lives outside the locale files.

I made the diagrams before coding, to clarify the architecture and the interactions between
components. They live in [`architecture.md`](architecture.md) in Mermaid format, which GitHub
renders natively and which can still be exported, so they stay easy to update alongside the code.

### Architecture

See [architecture.md](architecture.md). The architecture is deliberately small: two persisted models
(`Quote` and `QuoteItem`), one non-persisted object (`QuoteTotals`) responsible for the money
computation, standard Rails controllers with items nested under quotes, and a dedicated controller
for the validation action.

#### Main objects and responsibilities

- **Quote** (ActiveRecord): holds the central rule. It refuses any mutation of itself (rename,
  delete, re-validate) once its **persisted** status is `validated`. It is the model, not the
  controller, that decides. It exposes `finalize` for the business transition. Items are declared
  with `dependent: :destroy` and ordered by `id` ascending, which is both the display order and the
  deterministic tie-break used by the allocation below.
- **QuoteItem** (ActiveRecord): refuses creation, update and destruction once its parent quote's
  persisted status is `validated`. The guard asks the parent on every write, so it holds even on a
  code path that does not go through `Quotes::ItemsController`.
- **QuoteTotals** (not persisted): computes, for a quote, the per-line breakdown and the aggregated
  totals that follow from it. Single responsibility, no persistence. It is the only source of
  displayed amounts, on a draft as on a validated quote.

Both guards read the **persisted** status (`status_in_database`), never the in-memory one. For
`Quote` this is not a detail: the validation transition assigns `status = :validated` in memory
before saving, so a guard reading the in-memory value would make validation refuse itself. Reading
the persisted status keeps the rule a hard raise with no exception on any path. This has its own
spec, since getting it wrong is obvious at runtime but easy to reintroduce during a refactor.

#### Naming

Column and method names are in English and aligned with the EN 16931 semantic model rather than with
the French abbreviations HT / TVA / TTC: `unit_price_excl_vat`, `line_net_amount`, `line_vat_amount`
and `line_gross_amount` for the per-line values, `total_net_amount`, `total_vat_amount` and
`total_gross_amount` for the aggregates. "Net" means before VAT and "gross" means after VAT, which
is the standard reading in an invoicing context. The alignment is on the _concepts_, not on the
standard's labels: `line_net_amount` maps to BT-131, `unit_price_excl_vat` to BT-146 (_Item net
price_), `total_net_amount` to BT-109 (_Invoice total amount without VAT_). Rails naming won over
transcribing the standard's vocabulary literally, which is also why the unit price says `excl_vat`
where the line amounts say `net`; they mean the same thing.

The interface is French and keeps the French labels. The mapping between the two vocabularies lives
in the locale files and nowhere else, so no French abbreviation leaks into an identifier.

One word is unavoidably overloaded and worth a glossary line, since the project contains both
meanings: **"validation"** means an ActiveRecord validation everywhere except in
`Quotes::ValidationsController`, `validated_at`, `Quote#validated?` and the "Valider le devis"
button, where it means the business transition from draft to committed. The business transition is
never a method named `validate`, to avoid colliding with ActiveModel; the model exposes `finalize`
and the domain word stays in the interface and in the route. No bang: the method returns a boolean
and populates `errors` on failure, exactly like `save`, so it does not carry the raising promise a
bang name would make.

#### Internationalization and formatting

The application is monolingual French. `config.i18n.default_locale` is `:fr`, `available_locales`
contains only `:fr`, and there is no locale switcher: adding one is trivial later, faking
multilingualism now would be scope creep.

Input parsing is covered under Money representation. On output, amounts are rendered with French
conventions through `number_to_currency` and the `fr` locale (comma as decimal separator, narrow
non-breaking space as thousands separator, euro symbol after the number: `1 234,56 €`). Rates are
rendered the same way (`5,5 %`). No amount is ever interpolated raw into a view.

#### The VAT computation contract

VAT is computed once per rate, on that rate's aggregated base, rather than line by line.

This is the rule the European e-invoicing semantic model EN 16931 imposes, and which underpins
Factur-X and French electronic invoicing. Five of its business rules define the shape of the
computation (the full set is published in the
[Peppol BIS Billing rule list](https://docs.peppol.eu/poacc/billing/3.0/rules/ubl-tc434/)):

- **BR-CO-10** and **BR-CO-13**: the document total excluding VAT is the sum of the line net amounts
  (there being no document-level allowances or charges in this scope). This is what makes step 1
  below a rule rather than a preference.
- **BR-S-08**: a VAT category's taxable amount is the sum of the line net amounts carrying that
  category and rate. This is what makes the grouping a rule rather than a preference.
- **BR-CO-17**: each VAT category's tax amount equals that category's taxable amount multiplied by
  its rate, rounded to two decimals.
- **BR-CO-14**: the document's total VAT is the sum of those per-category amounts, each rounded
  before being summed.
- **BR-CO-15**: the total including VAT is the total excluding VAT plus the total VAT, not a sum of
  line amounts.

To be precise about scope: those rules govern _invoices_, not quotes. A quote is under no legal
obligation to comply with EN 16931. Adopting them here is practical rather than regulatory: a quote
is a commitment on a price that will be invoiced later, so it should show exactly the amounts the
future invoice will show. Any other aggregation produces a quote whose total differs from the
invoice by a cent or two, which is a support ticket and a credibility problem, and costs nothing to
avoid by using the invoice rules from the start.

Note that the standard groups by _category and rate_, not by rate alone. Since this model carries no
VAT category, the two are the same thing here, and the day a category is added (see Evolution ideas)
the grouping key changes with it: two 0 % lines, one exempt and one out of scope, would form two
groups and two lines in the VAT breakdown.

That standard carries no VAT amount and no gross amount at the line level, which is exactly how it
sidesteps the reconciliation problem. The Figma here does display a per-line Total TTC column, so
the per-line amounts have to be made to agree with the per-rate totals. That reconciliation is a
decision of this project, not a rule of the standard. The algorithm:

1. For each line, compute `quantity * unit_price_excl_vat` in `BigDecimal` and round it half-up to 2
   decimals. That rounded value is the line's `line_net_amount`, and everything downstream uses it,
   never the unrounded product. The quote's `total_net_amount` is the sum of these rounded line
   amounts (BR-CO-10, BR-CO-13), so the displayed lines always sum to the displayed total by
   construction.
2. Group the lines by VAT rate (BR-S-08). For each group, compute the group's authoritative VAT as
   `round_half_up(group_net_subtotal * rate / 100, 2)`, a single rounding on the aggregated base
   (BR-CO-17). This is the source of truth for that rate. Note the `/ 100`: the rate is stored as a
   percentage value (`20.00`), not as a coefficient.
3. Within each group, work in integer cents. For each line, compute its exact VAT as
   `line_net_cents * rate / 100` as an exact rational, take its floor, and keep the fractional
   remainder aside.
4. The difference between the group's authoritative VAT and the sum of these floored line amounts is
   the number of cents still to distribute. Distribute them one cent at a time to the lines with the
   largest remainder (largest-remainder allocation), breaking ties by item `id` ascending so the
   result is deterministic and reproducible in tests.
5. Each line's `line_gross_amount` is its `line_net_amount` plus its allocated `line_vat_amount`.
   The quote's `total_vat_amount` is the sum of the per-rate authoritative amounts (BR-CO-14) and
   its `total_gross_amount` is `total_net_amount + total_vat_amount` (BR-CO-15). That both also
   equal the plain sums of the reconciled lines is a property the allocation guarantees, and it is
   asserted as such in the specs, but it is not the definition.

Properties worth stating, since they bound what this algorithm can do:

- Because both the group total and the per-line amounts are computed from the _same rounded_ line
  net amounts, the number of cents to distribute is always between 0 and the number of lines in the
  group, never negative. Writing `F` for the sum of the floors, `x` for the group's exact VAT in
  cents and `k` for the number of lines, each floor discards strictly less than one cent, so
  `F <= x < F + k`; and since rounding moves `x` by at most half a cent, `round(x) - F` is an
  integer in `[0, k]`. Both bounds are attainable: twelve lines of 1,09 € at 5,5 % give `F = 60` and
  `x = 71,94`, so twelve cents are reallocated across twelve lines. This is normal, not a symptom of
  a bug, and it is exactly what breaks if step 3 is ever computed from the unrounded product instead
  of `line_net_amount`.
- No line ever receives more than one cent, so a displayed line VAT is always within one cent of
  that line's exact VAT, while the per-rate and document totals stay exactly right. That is the
  trade-off, and it is the right way round: the totals are what the quote is commercially evaluated
  on.
- The visible consequence, worth writing down because it will be reported as a bug one day: an
  individual line's gross amount is not always equal to
  `round(line_net_amount * (1 + rate / 100))`. A user checking one line on a calculator can find a
  one-cent difference. The column sums exactly to the footer, which is the property that was chosen;
  the alternative would have been a footer that does not match the column above it.
- A 0 % group passes through the whole algorithm with an authoritative VAT of zero, per-line floors
  of zero, and nothing to distribute. It is not special-cased, and it gets a test anyway, since it
  is the most likely rate for an events partner who is not charging VAT.

The algorithm assumes non-negative amounts, which is guaranteed by the validations rejecting
negative quantities and unit prices. Flooring behaves differently on negative values, so if discounts
or credit notes are ever introduced, this contract needs revisiting rather than extending.

An alternative considered and rejected: computing each line's VAT independently and letting the
footer show a per-rate total that can differ by a cent from the sum of the lines. Several invoicing
tools do this, but a footer that does not match the column above it reads as a bug to the user, and
the discrepancy is impossible to explain on a commercial document.

#### Controllers

- `QuotesController`: `index`, `create`, `show`, `update`, `destroy`, plus `new` returning a Turbo
  Frame fragment rather than a page. No `edit` action, see "Screens and navigation".
- `Quotes::ItemsController`: nested under quotes, CRUD on items, with `new` and `edit` likewise
  returning frame fragments. No `accepts_nested_attributes_for`; each action responds with a
  multi-target Turbo Stream.
- `Quotes::ValidationsController`: a REST sub-resource with a single `create` action,
  `POST /quotes/:quote_id/validation`. Chosen over a custom member action to stay in standard REST
  vocabulary, since a validation is a resource being created.

Routes: `resources :quotes, except: :edit` nesting `resources :items, module: :quotes` and
`resource :validation, only: :create, module: :quotes`.

`status` is never accepted through strong params. A quote is only validated through
`Quotes::ValidationsController#create`; nothing else, including a hidden field slipped into a form,
can change it.

#### How a refusal becomes an HTTP response

Controllers hold none of the business rule; they translate a refusal into a response. For that
translation to be possible, the two kinds of refusal have to be _distinguishable_, which means they
cannot both be an ActiveRecord validation error.

- **Invalid data** is an ActiveRecord validation. It is correctable and re-submittable, so `save`
  returning false is the right shape, and the response is 422 with the form re-rendered.
- **Immutability** is a state conflict, not a data error. It is a dedicated exception,
  `Quote::ImmutableError`, raised by the guard on both models and caught by a `rescue_from` in
  `ApplicationController`. Three reasons for raising rather than validating: the refusal is not
  correctable by the user, so re-rendering a form makes no sense; validations do not run on
  `destroy` at all, and a `before_destroy` returning `throw :abort` gives no error object to
  discriminate on; and an exception cannot be silently swallowed by a non-bang `save`.

| Situation                                                                                                | Mechanism                                 | Response                                       |
| -------------------------------------------------------------------------------------------------------- | ----------------------------------------- | ---------------------------------------------- |
| Invalid field (blank name, quantity <= 0, rate outside the list, value out of bounds, too many decimals) | ActiveRecord validation                   | 422, form re-rendered                          |
| Validating a quote with no item                                                                          | ActiveRecord validation on the transition | 422, error rendered as a flash                 |
| Any write on a validated quote or its items                                                              | `Quote::ImmutableError`                   | 303 redirect to the quote screen, with a flash |
| Validating an already validated quote                                                                    | same exception                            | same                                           |
| Unknown quote or item                                                                                    | `ActiveRecord::RecordNotFound`            | 404                                            |

The 303 rather than a 409 is a deliberate simplification, see "Deliberately kept simple".

#### Concurrency

One mechanism, applied uniformly: every write path (rename, delete, item create, item update, item
destroy, validation) wraps the quote in `with_lock`, which opens a transaction, locks the quote row
and reloads it. The guard then reads a state nobody can change until the transaction commits, which
closes the window between "check that the quote is still a draft" and "write". Deliberately not
protected: two concurrent edits of two different items of the same quote. `with_lock` serialises
them and the immutability check stays correct, but there is no stale-data detection between them.
Same for two concurrent renames, which end in last-write-wins.

## Implementation checklist

Points to get right during implementation, gathered before writing code so they do not get lost.

#### Immutability of a validated quote

Enforced at the model level, not just by hiding buttons: a validated `Quote` refuses `update` and
`destroy`, and a `QuoteItem` belonging to a validated quote refuses `create`, `update` and
`destroy`. The test that matters is a request spec sending a direct `PATCH` to an item endpoint
while its quote is validated, since that is the path a UI-only guard would miss.

Both guards read the persisted status, not the in-memory one, otherwise the validation transition
refuses itself. Own spec.

#### Validating an empty quote

Refused, per the recruiter clarifications. Two layers, and they are not the same thing:

- Server side, `Quote` refuses the transition and `Quotes::ValidationsController#create` answers 422
  with the error. This is the actual rule and it is what the request spec asserts.
- Client side, the validate button is disabled while the quote has no item, with a title explaining
  why. This is an affordance, not the rule; it exists so the user does not have to trigger an error
  to learn the constraint.

If the button is triggered anyway (stale page, direct request), the 422 renders the error as a Turbo
Stream flash rather than a full page error.

#### Turbo and Stimulus specifics

- An action on an item updates three zones, the table body, the totals block and the validate
  button. Handled with a multi-target Turbo Stream response, targets named via `dom_id`.
- The table body is re-rendered whole on every item write, rather than appending, replacing or
  removing the single row that was touched. The cent allocation runs per rate group, so adding,
  editing or deleting one line can move a cent onto a line that is already displayed; a stream
  targeting only the written row would leave the Total TTC column no longer summing to the footer,
  which is exactly the outcome the allocation exists to prevent. The add-item form lives in the
  table's `tfoot`, outside the body, so re-rendering the body does not disturb the form reset or
  the focus retention above.
- Validation errors on a Turbo request respond with 422, otherwise the form is not re-rendered.
- Redirects after DELETE and PATCH use 303.
- The quote creation form lives inside a Turbo Frame but redirects to another screen, so it carries
  `data-turbo-frame="_top"`. Without it Turbo looks for a matching frame in the target page, does
  not find one, and shows "Content missing".
- The add-item form resets and keeps focus after a successful submission, to support adding several
  items in a row without extra clicks.
- The add-item row is always appended as the last row of the table, and can be dismissed both by its
  cancel button and by Escape, without submitting anything.
- The add-quote row on the list screen uses the same pattern and the same Stimulus controller.
- A Stimulus controller can compute a line's net amount while typing, for immediate feedback, but
  the server stays the source of truth. The VAT and allocation logic is never duplicated in JS,
  since a per-line JS estimate would disagree with the reconciled server value.
- Deletion is confirmed with `turbo_confirm`.
- Validation is confirmed with `turbo_confirm` too, since it is the one transition with no way
  back: a mis-click here cannot be undone the way a mis-typed name or a wrong item can. This is an
  addition to the Figma, same class of decision as the cancel button on the add-item row, and
  logged here for the same reason: an unreviewed UI decision should not read as an oversight.

#### Ordering

Items are ordered by `id` ascending, and that order is declared on the association rather than left
to the database, since it is both the display order and the allocation tie-break. If they diverge,
the totals stay correct but the specs stop being reproducible.

#### Performance

The quote list displays ID, date and name only, so there is no per-row aggregation and no N+1 by
construction. The first evolution that adds a total or an item count to that list would introduce
one.

#### Edge cases to cover in tests

- Zero or negative quantity, negative unit price, empty quote name, empty item name.
- A quantity or unit price with more decimals than its column's scale, asserting the input is
  rejected rather than silently rounded at assignment.
- A quantity or unit price above its upper bound, asserting a 422 rather than a PostgreSQL error.
- A French-formatted decimal input (`12,50`) on both quantity and unit price.
- A quote with no items, both for display (totals at zero) and for validation (refused).
- A VAT rate outside the allowed list.
- A quote made entirely of 0 % lines.
- A rate group of several lines where naive per-line rounding would not sum to the group's VAT,
  verifying the allocation reconciles the lines to the group and quote totals exactly.
- A group where the full `k` cents have to be distributed, using twelve lines of 1,09 € at 5,5 %.
  The rate matters: at 20 % the per-line remainder never exceeds 0,8 cents, so the upper bound is
  not reachable and the test would prove less than it looks.
- A tie on the remainder, verifying the `id` tie-break makes the outcome deterministic across runs.
- An item write that moves a cent onto a line that is already on screen, asserted on the Turbo
  Stream body rather than on `QuoteTotals`, since the failure is in the rendering rather than in the
  computation: three lines at 10 % where creating, editing or deleting one of them shifts another
  one's Total TTC.
- A quote with several rates, asserting both named invariants from Testing strategy.
- A direct `PATCH` and a direct `DELETE` on an item of a validated quote, and on the validated quote
  itself, asserting the refusal and that no data changed.

### Code conventions

The code follows the [Ruby style guide](https://rubystyle.guide/), checked by RuboCop in CI on every
pull request and on every push to `main`. A local pre-commit hook runs it too, but the hook lives in
`.git/hooks/` rather than being versioned, so it only exists on this machine.

The code is written in English, including comments, commit messages and identifiers. User-facing
strings are French and live in the locale files.

The project is developed in iterations, one per story, each in a dedicated branch with atomic
commits, merged into `main` once complete. Story #0 is project setup. Branches are named with a
prefix indicating the type of work, followed by the story number and name, in English, for example
`feature/1_story_name`. Commits are in English and briefly describe the change using
[Gitmoji](https://gitmoji.dev/).

## Retrospective

### What I would keep on a real project

I started by thinking about the architecture and the interactions between components, and made
diagrams before writing any code. They live in [`architecture.md`](architecture.md). Writing the
architecture down first gives a reference to check the code against as it evolves, and it forced
several decisions (the VAT reconciliation algorithm, the persisted-status guard) to be settled
before they could hide inside an implementation detail.

A clear architecture, with most
ambiguities already resolved in writing, makes it possible to write short, self-contained Kanban
tickets that an AI coding agent can implement correctly with little back and forth. The job posting
is explicit that the Tech Lead is expected to drive AI adoption in the squad's workflows, not just
use AI individually, and this is the concrete mechanism I would bring: the leverage does not come
from the AI, it comes from the quality of the specification handed to it.

### What went well

Mostly, the project went well. I was able to implement all the requirements, and I split the test
suite by risk rather than by habit: dense unit specs on `QuoteTotals`, request specs on the
immutability rule and the other business-critical paths, and system specs kept to the four cases
that cannot be observed any other way, a redirect out of a Turbo Frame, focus retention, dismissal
by Escape, and the full quote flow. That structure is one of the things I would call a real win,
since the level of testing tracks the risk of each part instead of aiming for a flat coverage
number.

Another thing that went well is that the trade-offs stayed visible instead of getting buried in the
code. The "Deliberately kept simple" section lists what I chose not to build and what it would cost
to add, so a reviewer can tell a decision was made on purpose rather than missed.

### What I would do differently

Even if it was useful to write the architecture down before coding, I spent a lot of time on it.
Overall, I would try to use my time more efficiently. I understand time is a limited resource, and
it is always a trade-off between spending time on design and spending time on implementation. I
always want to produce the best possible code, but I need to be more pragmatic and focus on the
most important things. This logbook is a good example of that: at close to 700 lines, it is likely
too much for a technical test.

### What I learned

I learned that VAT computation on an invoicing document is not just an arithmetic problem, it is
governed by legal rules, and getting the aggregation right means following them rather than picking
a convenient rounding strategy. The EN 16931 semantic model, which underpins Factur-X and French
e-invoicing, sets out precisely how a document's totals must be built from its lines: VAT is
computed once per category and rate on their combined taxable amount (BR-S-08, BR-CO-17), not line
by line, and the document's totals are sums of those per-category amounts (BR-CO-10, BR-CO-13,
BR-CO-14, BR-CO-15). Adopting these invoicing rules for a quote is a choice,
not a legal obligation, but it is the only way to guarantee the quote will match the invoice that
follows it.

I also learned to be careful with Turbo Frames and redirects. A redirect issued to a form living
inside a Turbo Frame is followed inside that frame by default, and if the target page has no frame
with a matching id, Turbo shows "Content missing" instead of navigating. A request spec reading a
correct 303 response cannot catch this, since it never renders a page. It is why the quote creation
form carries `data-turbo-frame="_top"`, and why one of the four system specs exists specifically to
exercise that redirect in a real browser.
