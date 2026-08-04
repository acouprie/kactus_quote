# Architecture

## 1. Use cases

Answers: what can the single actor do, and which actions are gated by the quote state?
The grouping is the important part. Everything in the second group is refused once the
quote is validated, which is the only invariant of this application.

```mermaid
flowchart LR
    partner(["Partner"])

    subgraph always["Available in any state"]
        UC1["List quotes"]
        UC2["Create quote"]
        UC3["View quote with items and totals"]
    end

    subgraph draftonly["Available only while the quote is a draft"]
        UC4["Rename quote"]
        UC5["Delete quote"]
        UC6["Validate quote"]
        UC7["Add item"]
        UC8["Edit item"]
        UC9["Delete item"]
    end

    partner --> UC1
    partner --> UC2
    partner --> UC3
    partner --> UC4
    partner --> UC5
    partner --> UC6
    partner --> UC7
    partner --> UC8
    partner --> UC9

    UC2 -.->|triggered from| UC1
    UC5 -.->|triggered from| UC1
    UC3 -.->|opened from| UC1
    UC4 -.->|includes| UC3
    UC6 -.->|includes| UC3
    UC7 -.->|includes| UC3
    UC8 -.->|includes| UC3
    UC9 -.->|includes| UC3
```

## 2. Data model

Answers: what is persisted, and what is not?
Totals are absent on purpose. They are derived by the `QuoteTotals` object, never stored,
so there is no denormalised value to keep in sync.

```mermaid
erDiagram
    QUOTES ||--o{ QUOTE_ITEMS : "owns, ordered by id"

    QUOTES {
        bigint id PK
        string name "not null"
        enum status "draft or validated, default draft"
        datetime validated_at "nullable, set on validation"
        integer lock_version "optimistic locking"
        datetime created_at
        datetime updated_at
    }

    QUOTE_ITEMS {
        bigint id PK
        bigint quote_id FK "not null, indexed"
        string name "not null"
        decimal quantity "precision 10 scale 2, strictly positive"
        decimal unit_price "precision 12 scale 2, zero or positive, excluding VAT"
        decimal vat_rate "precision 5 scale 2, one of the VAT_RATES values"
        datetime created_at
        datetime updated_at
    }
```

Deleting a quote cascades to its items (`dependent: :destroy`), which only ever happens
while the quote is a draft.

Open question: `quantity` is a decimal so that fractional units stay expressible, for
instance half days of venue rental. If quantities are always whole units, an integer is
enough and the rounding contract gets simpler.

## 3. Quote lifecycle

Answers: what does validation actually forbid?
Read this diagram by what is missing. The `validated` state has no outgoing arrow at all,
including no arrow to the final state, because a validated quote cannot even be deleted.

```mermaid
stateDiagram-v2
    direction LR

    [*] --> draft : create quote

    draft --> draft : rename
    draft --> draft : add, edit or delete an item
    draft --> [*] : delete quote
    draft --> validated : validate quote

    note right of draft
        Every mutation is allowed here.
        Optimistic locking on lock_version
        rejects stale concurrent updates.
    end note

    note right of validated
        Terminal state, no outgoing transition.
        validated_at is set once and never cleared.
        The model refuses all of these
        rename, delete the quote, validate again,
        create, update or destroy any item.
        Controllers turn the refusal
        into an HTTP 409 Conflict response.
    end note
```

The check lives in the models, not in the controllers. `Quote` refuses its own mutations,
and `QuoteItem` refuses any write whose parent quote is validated, so the guard holds even
for a write that never goes through `Quotes::ItemsController`.

## 4. Adding an item

Answers: how does a single item creation update the page without a reload?
The detail screen is never reloaded. One POST returns one Turbo Stream response carrying
several actions, so the new row and the totals block stay consistent. The "Add an item"
button is a permanent element below the table and never disappears.

```mermaid
sequenceDiagram
    autonumber
    actor U as Partner
    participant B as Browser and Turbo
    participant C as Quotes ItemsController
    participant M as QuoteItem model
    participant T as QuoteTotals

    U->>B: click "Add an item"
    B->>C: GET /quotes/{id}/items/new
    C-->>B: 200, form row rendered in the new_item Turbo Frame
    Note over B: the form row is appended as the last row<br/>of the table, the button stays below it

    opt partner cancels before submitting
        U->>B: press Escape
        Note over B: the new_item frame is emptied client side,<br/>nothing was persisted, no request needed
    end

    U->>B: fill name, quantity, unit price, VAT rate and submit
    B->>C: POST /quotes/{id}/items

    alt quote is a draft and the item is valid
        C->>M: build and save
        M-->>C: saved
        C->>T: compute totals for the quote
        T-->>C: net, vat and gross amounts
        C-->>B: 201, turbo_stream with three actions
        Note over B: append the row to #quote_items,<br/>empty the new_item frame,<br/>replace #quote_totals
    else item is invalid
        C->>M: build and save
        M-->>C: rejected, errors present
        C-->>B: 422, turbo_stream replacing the new_item frame
        Note over B: the form row stays open,<br/>keeps the typed values and shows the errors
    else quote was validated from another tab
        C->>M: build and save
        M-->>C: refused by the immutability guard
        C-->>B: 409, turbo_stream rendering a flash message
        Note over B: the page was rendered before validation,<br/>a reload shows the read only screen
    end
```

Editing an item follows the same shape, with `PATCH /quotes/{quote_id}/items/{id}` and a
`replace` on the existing row instead of an `append`.

Rounding contract used by `QuoteTotals`: each line total is rounded to two decimals, lines
are grouped by VAT rate, VAT is computed once per rate group on the rounded subtotal, then
the group results are summed.