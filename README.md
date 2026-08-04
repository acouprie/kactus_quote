# Kactus Quote Editor

A quote editor for the partners of the Kactus marketplace, built as a technical exercise.

A partner lists their quotes, opens one, adds items to it, and reads the running totals excluding
VAT, VAT and including VAT. Validating a quote commits it: from that point it can no longer be
modified or deleted, and neither can its items. The application has exactly two screens, the quote
list and the quote itself, and every item interaction happens on the second one without ever
reloading the page.

## Key decisions

Seven decisions shape most of the code. Each one links to the reasoning behind it.

- **Two screens, and nothing else.** Creating a quote, renaming it and editing an item all happen
  in place, through Turbo Frame fragments rather than through additional pages.
  [Details](docs/logbook.md#screens-and-navigation)
- **No amount is ever a `Float`.** Everything runs in `BigDecimal` or in integer cents, and every
  rounding is half-up with the mode passed explicitly.
  [Details](docs/logbook.md#money-representation)
- **VAT is computed once per rate group, not line by line.** The resulting cents are then allocated
  back to the individual lines, so the displayed column always sums exactly to the displayed
  footer. [Details](docs/logbook.md#the-vat-computation-contract)
- **Immutability is enforced in the models, not by hiding buttons.** A direct `PATCH` on an item of
  a validated quote is refused even though the interface never offers it, and that is what the
  request specs assert. [Details](docs/architecture.md#3-quote-lifecycle)
- **Amounts are recomputed on every render, never frozen at validation.** This is a deliberate
  simplification, and the consequence it carries is stated rather than glossed over.
  [Details](docs/logbook.md#deliberately-kept-simple)
- **No authentication, no multi-tenancy, no PDF export.** The single actor is anonymous and every
  quote is visible to whoever opens the application.
  [Details](docs/logbook.md#out-of-scope)
- **Tests target relevance rather than coverage.** Three levels, each mapped to a specific risk:
  the money computation, the immutability rule, and the Turbo wiring.
  [Details](docs/logbook.md#testing-strategy)

## Documentation

- [docs/logbook.md](docs/logbook.md): decisions, assumptions and trade-offs taken during the
  exercise. Written as a working logbook, not as a report.
- [docs/architecture.md](docs/architecture.md): four diagrams covering the use cases, the data
  model, the quote lifecycle and the Turbo round trip on an item creation.
- [docs/evolution_ideas.md](docs/evolution_ideas.md): the "improvement" deliverable asked for in the
  brief, in three axes: product, technical and process.
- [Kanban board](https://github.com/users/acouprie/projects/1/views/1)
- [Figma](https://www.figma.com/design/jiNniIBnQWBxUOJzt6Ihbu/Test-technique)

## Stack

- Ruby 3.3.12
- Rails 7.2
- PostgreSQL 16
- Hotwire (Turbo and Stimulus)
- RSpec, FactoryBot, Shoulda Matchers, Capybara for testing

## Requirements

- Docker
- Docker Compose

No local Ruby, PostgreSQL or Chrome installation is required. Everything runs inside containers,
including the browser used by the system tests.

## Setup

1. Copy the environment template:

   ```bash
   cp .env.example .env
   ```

   `.env.example` ships with a working `RAILS_MASTER_KEY`, so there is nothing to fill in and
   nothing to request from anyone. This is deliberate: the encrypted credentials of this repository
   hold nothing but a generated `secret_key_base`, and this application is a technical exercise
   rather than a deployed service. On a real project that key would never be committed.

2. Build the image:

   ```bash
   docker compose build
   ```

3. Create and set up the databases:

   ```bash
   docker compose run --rm web bin/rails db:prepare
   ```

4. Load the demo data:

   ```bash
   docker compose run --rm web bin/rails db:seed
   ```

   The seeds are worth running. They cover the cases that are hard to reach by clicking: a quote
   mixing several VAT rates, a rate group where the cent reallocation actually fires, a quote made
   entirely of 0 % lines, an empty draft, and one already validated quote.

5. Start the application:

   ```bash
   docker compose up
   ```

The application is available at [http://localhost:3000](http://localhost:3000).

## Running tests

The full suite, unit, request and system specs:

```bash
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec
```

The system specs drive a real browser rather than a stubbed one, since what they exist to catch is
Turbo behaviour: multi-target stream updates, 422 and 303 responses, form resets. They run against
the `selenium` service declared in `docker-compose.yml`, which Docker Compose starts automatically
as a dependency of `web`.

If that container fails to start on your machine, the rest of the suite still runs on its own:

```bash
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec \
  --exclude-pattern "spec/system/**/*_spec.rb"
```

After adding a migration, regenerate the test database schema:

```bash
docker compose run --rm -e RAILS_ENV=test web bin/rails db:test:prepare
```

## Linting

```bash
docker compose run --rm --no-deps web bin/rubocop
```

Add `-a` to autocorrect fixable offenses:

```bash
docker compose run --rm --no-deps web bin/rubocop -a
```

## Running other commands

Any Rails command runs the same way:

```bash
docker compose run --rm web bin/rails console
docker compose run --rm web bin/rails generate model Thing
docker compose run --rm web bin/rails db:migrate
```

## Continuous integration

GitHub Actions (`.github/workflows/ci.yml`) runs on every push to `main` and on every pull request:

- `scan_ruby`: Brakeman static security analysis
- `scan_js`: `bin/importmap audit` for JavaScript dependency vulnerabilities
- `test`: the full RSpec suite, system specs included, against PostgreSQL and Chromium services
- `lint`: RuboCop

System specs run in CI rather than being skipped there, since they are the level most likely to
catch a regression the other two miss. CI runs the same command a developer runs locally, in the
same environment.

Brakeman's `EOLRails` check is disabled in `config/brakeman.yml`. Rails 7.2 security support ends on
2026-08-09, and this application is a short-lived technical exercise rather than something running
long-term in production, so the check adds noise without value here. The version is pinned to the
one in use at Kactus deliberately, see the logbook under
[Implementation choices](docs/logbook.md#implementation-choices).

## Definition of Done

Reusing Kactus's own process vocabulary (success criteria set together, breakdown into deliverable
increments, a "done" covering tests, UX and tracking), a story is done when:

- Behaviour matches the functional requirement and the Figma, including the edge cases and
  assumptions recorded in the logbook.
- Tests cover the new or changed code at the level appropriate to its risk, and the full suite is
  green locally and in CI.
- RuboCop passes, or any exception is explicitly justified.
- The change has been reviewed, here by Claude Code acting as a PR reviewer, with raised issues
  either addressed or consciously logged as known debt.
- Any new assumption, trade-off or open question is recorded in the logbook rather than left
  implicit in the code.
- The branch is merged to `main` through a short, focused pull request, and the corresponding card
  is moved on the Kanban board.

## Deployment

Out of scope for this exercise.