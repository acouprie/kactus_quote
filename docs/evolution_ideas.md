# Evolution ideas

This section is the "improvement" deliverable mentioned in the brief. Three axes, each roughly
ordered by priority.

**Product**

What would move the tool closer to actually replacing the partner's current process (editing a quote
outside the platform, then uploading it):

1. Export the quote as a PDF. Closest to the tool's stated purpose; without it, partners still
   cannot hand a quote to a client from within the platform.
2. Send the quote directly by email, if a client email address is registered.
3. Client-side acceptance of a quote (electronic signature).
4. Identification of the client or business a quote is for, currently missing from the data model
   entirely.
5. A VAT category alongside the rate (EN 16931 BT-118) with its exemption reason (BT-120/BT-121), so
   that a zero-VAT line can say whether it is exempt, out of scope or zero-rated, and carry the
   legal mention that goes with it. This also changes the grouping key of the VAT computation, see
   "The VAT computation contract".
6. Discounts, at the item or quote level. This reopens the computation contract, since it introduces
   negative amounts.
7. A base quantity on the unit price (EN 16931 BT-149/BT-150), which is how the standard expresses a
   sub-cent unit price without adding decimals to the amount.
8. Legal or sequential quote numbering, required in some jurisdictions.
9. A validity period or expiry date on a quote.
10. Support for multiple currencies.
11. Let the user reorder items within a quote. This needs an explicit `position` column, which would
    then replace `id` as both the display order and the allocation tie-break, and it is what would
    make the position of the add-item row a real question rather than a mockup detail.
12. An item library, so the same item is not re-entered on every quote, and then quote templates.
13. A version history of a quote's content over time, beyond the draft/validated status.

**Technical**

Roughly ordered from "protects data that is already at risk today" to "would only matter at real
scale". The first four are the items from "Deliberately kept simple".

1. Freeze the computed amounts at validation, on the quote and on each item, inside the same
   transaction as the status change, and read them back afterwards. This is what makes a validated
   quote auditable and immune to a later change in the aggregation code. It needs a CHECK constraint
   tying the frozen columns to the status, and a strict write order inside the transaction: the
   items first, while the quote is still a draft, otherwise the immutability guard blocks the
   transition itself.
2. Optimistic locking on the rename (`lock_version`), plus a "someone else just edited this,
   reload?" banner instead of last-write-wins.
3. A VAT rates reference table with validity periods, replacing the hardcoded list, so that a change
   in the legal rates is a data migration rather than a code change.
4. Answer 409 Conflict on an immutability refusal, once Turbo's handling of a stream body on that
   status has been verified.
5. An unsaved-changes guard on the quote name, or an auto-save on blur, so that leaving the quote
   screen by the browser's back button does not silently drop a pending rename.
6. An audit trail of who changed what and when: which user made which change, not just what the
   final state was.
7. Move away from hard-deleting a quote: archive it, or move it to a restorable bin for a limited
   period before permanent deletion.
8. Pagination on the quote list.
9. Authentication and per-partner scoping, so quotes are tied to "my quotes" rather than a single
   shared list, then multi-tenant separation between partner organizations.
10. Background jobs for anything that should not block the request once it exists (PDF generation,
    emails).
11. Observability: structured logging, error tracking, basic metrics.
12. Scaling considerations for the platform's actual partner volume (8,000+ partners): indexing, N+1
    prevention beyond the list view, caching totals if computing them live becomes a bottleneck.

**Process**

1. Deployment of the application, absent here since the exercise is delivered as a repository.
2. Feature flags, to ship an incomplete feature behind a toggle rather than blocking a release.
3. A defined rollout plan (staged release, canary) instead of a single big-bang deploy.
4. What I would ask the team to check manually before a release, on top of the automated suite: the
   immutability guard on non-UI paths, and the Turbo multi-target updates, since both are the kind
   of thing automated tests miss when they only exercise the happy path.
