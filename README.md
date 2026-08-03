# Kactus

A Rails 7 application, running fully in Docker.

## Stack

* Ruby 3.3.12
* Rails 7.2
* PostgreSQL 16
* RSpec, FactoryBot, Shoulda Matchers for testing

## Requirements

* Docker
* Docker Compose

No local Ruby or PostgreSQL installation is required: everything runs inside containers.

## Setup

1. Copy the environment template and fill in the values:

   ```bash
   cp .env.example .env
   ```

   `RAILS_MASTER_KEY` must match the value in `config/master.key`. This file is not
   committed to version control — get it from a teammate through a secure channel.

2. Build the image:

   ```bash
   docker compose build
   ```

3. Create and set up the databases:

   ```bash
   docker compose run --rm web bin/rails db:prepare
   ```

4. Start the app:

   ```bash
   docker compose up
   ```

The app is available at [http://localhost:3000](http://localhost:3000).

## Running tests

```bash
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec
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

Any Rails command can be run the same way, e.g.:

```bash
docker compose run --rm web bin/rails console
docker compose run --rm web bin/rails generate model Thing
docker compose run --rm web bin/rails db:migrate
```

After adding a migration, regenerate the test database schema:

```bash
docker compose run --rm -e RAILS_ENV=test web bin/rails db:test:prepare
```

## Continuous Integration

GitHub Actions (`.github/workflows/ci.yml`) runs on every push to `main` and on every
pull request:

* `scan_ruby` — Brakeman static security analysis
* `scan_js` — `bin/importmap audit` for JS dependency vulnerabilities
* `test` — RSpec suite against a PostgreSQL service
* `lint` — Rubocop

Brakeman's `EOLRails` check is disabled in `config/brakeman.yml`. Rails 7.2 security
support ends 2026-08-09; this app is a short-lived technical test PoC, not something
running long-term in production, so that check adds noise without value here.

## Deployment

Out of scope.
