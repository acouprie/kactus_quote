# Architecture

Four diagrams, each answering one question. The reasoning behind the money computation is not
repeated here: [logbook.md](logbook.md) is the single source of truth for it, and this file points
at it rather than restating it.

Two invariants hold across all of them:

1. A validated quote can no longer be modified or deleted, itself or its items.
2. A quote with no item cannot be validated.

Amounts are never persisted: they are derived from the items on every render, for a draft as for a
validated quote. That is a deliberate simplification, and the reasons for it, along with what it
would take to freeze them instead, are in the logbook under "Deliberately kept simple".

## 1. Use cases

Answers: what can the single actor do, and which actions are gated by the quote state? The grouping
is the important part: everything in the second group is refused once the quote is validated.

Authentication is out of scope (see logbook), so the actor is anonymous and unscoped: there is no
partner account, and every quote is visible to whoever opens the application. "User" below is a
role, not an authenticated identity.

```mermaid
flowchart LR
    user(["User"])

    subgraph always["Available in any state"]
        UC1["List quotes"]
        UC2["Create quote"]
        UC3["View quote with items and totals"]
    end

    subgraph draftonly["Available only while the quote is a draft"]
        UC4["Rename quote"]
        UC5["Delete quote"]
        UC6["Validate quote<br/>(requires at least one item)"]
        UC7["Add item"]
        UC8["Edit item"]
        UC9["Delete item"]
    end

    user --> UC1
    user --> UC2
    user --> UC3
    user --> UC4
    user --> UC5
    user --> UC6
    user --> UC7
    user --> UC8
    user --> UC9

    UC2 -.->|triggered from| UC1
    UC5 -.->|triggered from| UC1
    UC3 -.->|opened from| UC1
    UC4 -.->|includes| UC3
    UC6 -.->|includes| UC3
    UC7 -.->|includes| UC3
    UC8 -.->|includes| UC3
    UC9 -.->|includes| UC3
    UC7 -.->|can be cancelled,<br/>button or Escape| UC3
```

Cancelling the add-item row is not a use case of its own: nothing is persisted, the row is simply
discarded client side. It appears here because the Figma showed no cancel affordance and the
decision to add one is a deliberate deviation (see logbook).

## 2. Data model

Answers: what is persisted?

Only the raw data is. Every amount shown on screen, per line and in the totals block, is computed by
`QuoteTotals` from the columns below.

```mermaid
erDiagram
    QUOTES ||--o{ QUOTE_ITEMS : "owns, ordered by id, dependent destroy"

    QUOTES {
        bigint id PK
        string name "not null"
        string status "draft or validated, default draft, ActiveRecord enum"
        datetime validated_at "null while draft, set once on validation"
        datetime created_at "shown as Date on the list screen"
        datetime updated_at
    }

    QUOTE_ITEMS {
        bigint id PK
        bigint quote_id FK "not null, indexed"
        string name "not null"
        decimal quantity "precision 10 scale 2, strictly positive, max 99999.99"
        decimal unit_price_excl_vat "precision 10 scale 2, zero or positive, max 99999.99"
        decimal vat_rate "precision 5 scale 2, in 0, 5.5, 10, 20"
        datetime created_at
        datetime updated_at
    }
```

Notes on the columns:

- `status` is a string column backed by an ActiveRecord enum, not a PostgreSQL enum type: adding a
  value later is a data migration rather than a type migration. It is never exposed through strong
  params; a quote changes status only through `Quotes::ValidationsController#create`.
- `vat_rate` is constrained by a model validation only. Why there is no database CHECK here is in
  the logbook, under "Deliberately kept simple".
- `quantity` and `unit_price_excl_vat` are validated against the scale of their column, on the raw
  input rather than on the cast attribute, because ActiveRecord rounds to the column scale at
  assignment time. See the logbook, "Money representation".
- Both are capped at 99 999.99, so that an out-of-range value is a form error and never a PostgreSQL
  exception surfacing as a 500.
- `quantity` is a decimal so that fractional units stay expressible, for instance half days of venue
  rental. Confirmed with the recruiter.
- Naming follows the EN 16931 vocabulary (net = before VAT, gross = after VAT). The French labels HT
  / TVA / TTC exist only in the locale files, never in an identifier.

Deleting a quote cascades to its items (`dependent: :destroy`), which only ever happens while the
quote is a draft.

## 3. Quote lifecycle

Answers: what does validation actually forbid?

Read this diagram by what is missing. The `validated` state has no outgoing arrow at all, including
no arrow to the final state, because a validated quote cannot even be deleted.

```mermaid
stateDiagram-v2
    direction LR

    [*] --> draft : create quote

    draft --> draft : rename
    draft --> draft : add, edit or delete an item
    draft --> draft : validation refused, quote has no item (422)
    draft --> [*] : delete quote
    draft --> validated : POST /quotes/{quote_id}/validation<br/>guard - at least one item

    note right of draft
        Every mutation is allowed here.
        Each one runs inside with_lock on the
        quote row, so the state is re-read
        under lock before anything is written.
    end note

    note right of validated
        Terminal state, no outgoing transition.
        validated_at is set once and never cleared.
        The model then refuses all of these:
        rename, delete the quote, validate again,
        create, update or destroy any item.
        Controllers turn the refusal into a flash
        and a 303 redirect to the quote screen.
    end note
```

The check lives in the models, not in the controllers. `Quote` refuses its own mutations, and
`QuoteItem` refuses any write whose parent quote is validated, so the guard holds even for a write
that never goes through `Quotes::ItemsController`.

Both guards read the **persisted** status, never the in-memory one: the transition assigns
`status = :validated` before saving, so a guard reading the in-memory value would make validation
refuse itself.

Validation itself needs no diagram of its own. `Quotes::ValidationsController#create` calls
`finalize!` inside `with_lock`, which re-reads the quote under lock, refuses with a 422 if it has no
item, refuses with the immutability error if it is already validated, and otherwise writes `status`
and `validated_at` before redirecting to the read-only screen with a 303.

## 4. Adding an item

Answers: how does a single item creation update the page without a reload?

The detail screen is never reloaded. One POST returns one Turbo Stream response carrying several
actions, so the new row and the totals block stay consistent. The "Ajouter un article" button is a
permanent element below the table and never disappears.

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant B as Browser and Turbo
    participant C as Quotes ItemsController
    participant Q as Quote row
    participant M as QuoteItem model
    participant T as QuoteTotals

    U->>B: click "Ajouter un article"
    B->>C: GET /quotes/{quote_id}/items/new
    C-->>B: 200, form row rendered in the new_item Turbo Frame
    Note over B: the form row is appended as the last row<br/>of the table, the button stays below it

    opt user cancels before submitting
        U->>B: click the cancel button, or press Escape
        Note over B: the new_item frame is emptied client side,<br/>nothing was persisted, no request needed
    end

    U->>B: fill name, quantity, unit price, VAT rate and submit
    B->>C: POST /quotes/{quote_id}/items
    C->>Q: with_lock: open transaction, lock and reload the quote

    alt quote is a draft and the item is valid
        C->>M: build and save
        M-->>C: saved, transaction commits
        C->>T: compute the breakdown and the totals
        T-->>C: line amounts, net, VAT and gross totals
        C-->>B: 200, turbo_stream with three actions
        Note over B: append the row to #quote_items,<br/>reset the new_item frame and keep focus,<br/>replace #quote_totals
    else item is invalid
        C->>M: build and save
        M-->>C: rejected, errors present
        C-->>B: 422, turbo_stream replacing the new_item frame
        Note over B: the form row stays open,<br/>keeps the typed values and shows the errors
    else quote was validated from another tab
        C->>M: build and save
        M-->>C: refused by the immutability guard
        C-->>B: 303 redirect to the quote screen, with a flash
        Note over B: the screen comes back in its read only variant
    end
```

Editing an item follows the same shape, with `PATCH /quotes/{quote_id}/items/{id}` and a `replace`
on the existing row instead of an `append`. Deleting follows it with a `remove` on the row.

One point to confirm against Turbo's real behaviour rather than assume, and to correct here once
tested: whether the success status should be 200 or 201 for a stream body. The immutability branch
deliberately avoids the question by redirecting, see the logbook under "Deliberately kept simple".

**Rounding, in three lines.** Each line's net amount is rounded to two decimals first; lines are
grouped by VAT rate and each group's VAT is computed once, on that group's summed net amount; the
resulting cents are then allocated back to the lines by largest remainder, ties broken by item `id`,
so the column sums exactly to the footer. The full algorithm, the EN 16931 rules it follows, the
reconciliation it adds on top of them and the trade-off it accepts are in
[logbook.md](logbook.md), section "The VAT computation contract". They are not duplicated here so
that there is only one version to keep correct.