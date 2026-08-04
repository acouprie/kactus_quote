# Kactus - Quote System

I will write in this file all the notes I take while implementing the exercise, to document my reasoning and choices.

This file is meant to be updated as I go, so that it can be read in parallel with the code. It is not meant to be a final report, but rather a logbook of my work.

## Reading the specifications

A few points came up on first read that need an explicit assumption or answer, since there's no way to check them against a live spec during this exercise:

- "Edit a quote" also covers editing its associated quote items, not just the quote's own name.
- "A validated quote can no longer be modified" also blocks adding, editing, and destroying its items, as confirmed by the Figma.
- Deletion is a hard delete. Archiving as a soft-delete alternative is noted as an improvement idea instead.
- Is there a notion of an authenticated user/partner, with quotes scoped to them ("my quotes"), or a single, unscoped list? The "as a user" phrasing is taken as standard user-story wording rather than a real authentication requirement. Authentication is considered out of scope for this exercise.
- Can a quote be validated with zero items? Resolved, see Recruiter clarifications below.
- Is item quantity an integer or a decimal (e.g. half-days, m², hours)? There's no separate unit field either, so the unit of measurement is presumably implicit in the item's name. Resolved, see Recruiter clarifications below.
- The VAT rate appears as a select field in the Figma. Is it a fixed list of standard rates, or a free decimal value? Resolved, see Recruiter clarifications below.
- The Figma shows the add-item row appearing with no visible way to cancel it if opened by mistake (unless Escape is meant to close it). Resolved, see Recruiter clarifications below.

Each of these is resolved with the recruiter's answer where available, or an explicit assumption otherwise, documented in the relevant section below as the implementation moves forward.

The evaluation section also refers to an "improvement" part that's never actually introduced earlier in the brief. Taken as a short written note, format and location left open as the brief itself states, most likely covered by the Improvement ideas section of this logbook.

### Recruiter clarifications

Reached out to the recruiter with the four points still open above. Their answer: these ambiguities are intentional, there's no single correct answer, and how they're resolved and documented is part of what's being evaluated. The only non-negotiable point is the one already stated in the brief: a validated quote can no longer be modified or deleted. Decisions taken as a result:

- Item quantity is a decimal.
- VAT is a fixed, selectable list: 0, 5.5, 10, 20.
- VAT rounding: each line's VAT amount is rounded first (to 2 decimals), then the rounded per-line amounts are summed for Total VAT (and, by extension, Total TTC).
- A quote cannot be validated with zero items; attempting to do so shows an alert modal rather than storing a quote meaningless that could not be deleted afterwards.
- Cancelling an item add: the mockup shows no cancel affordance on the add-item row, only the validate action, which reads as an oversight rather than an intentional constraint, since every other reversible action in the mockup (delete) has a visible icon rather than a keyboard-only path. Decision: add a small cancel button next to the validate checkmark, styled like the existing edit/destroy icons in the table, with Escape kept as an additional shortcut rather than the only way out. In a real project this specific UI change would still go through the PM/designer during shaping rather than be decided unilaterally by a dev; noted here as the kind of trade-off that gets flagged to the team rather than shipped silently.

## Out of scope

The following are deliberately not implemented, since they're not covered by the functional requirements and would move well beyond the reduced scope described in the brief:

- **Authentication / authorization**: no login, no notion of a partner account.
- **Multi-tenant separation**: no partitioning of quotes by partner or organization, consistent with the absence of authentication above.
- **PDF export**: no way to export or print a quote. Logged as an improvement idea since it's arguably central to the tool's stated purpose (sending quotes to clients).
- **Sending to the client**: no email delivery from the system. Same reasoning.
- **Discounts**: no percentage or fixed-amount discount at item or quote level. Not mentioned in the requirements.
- **Multiple currencies**: prices are handled in a single, implicit currency (euro).
- **Legal/sequential quote numbering**: no unique, sequential, or legally compliant numbering scheme, which some jurisdictions require on official quotes.
- **Validity conditions**: no expiry date or validity period on a quote.
- **Electronic signature**: no client-facing acceptance or signature flow.
- **Versioning**: no history of changes to a quote over time, beyond the status transition (draft to validated) and the hard delete decision documented above.
- **Deployment**: no deployment to a live server.

Most of these are also logged under Improvement ideas.

## Use of AI

I use AI, mainly Claude, as a partner to challenge my choices and help write documentation, staying as close as possible to real-world practice.

To simulate real-world peer review, I set up Claude Code as a PR reviewer on GitHub, acting as a virtual colleague for code reviews.

I also use AI-powered autocompletion (Mistral AI) in my IDE to speed up writing code.

## Project setup

### Implementation choices

I choosed to use Rails 7 as it is the version used by Kactus teams, with the lasst version of Ruby (4.0.5). I use Hotwire (Turbo + Stimulus) to implement the dynamic behaviour of the quote items table, as it allows a smooth user experience without full page reloads.

I use Postgresl as the database, as it is mentionned in the job description, and this is the database system I am the most confortable with.

I use Docker to run the database in a container, so that the project can be run on any machine without installing Postgres locally.

I try to follow TDD as much as possible, I set up unit tests for every class and method, using a Rspec. I track coverage without chasing 100% for its own sake; any deliberately untested lines are documented with a clear justification. Unit tests run on every push via GitHub Actions.

I use GitHub to store the code, with a protected main branch (rules not enforced on the Free plan). Work is developed in dedicated branches and merged into main via pull requests.

I store the environment variables in a `.env` file, which is not committed to the repository. The `.env.example` file contains the names of the variables and their expected format, so that anyone can create their own `.env` file.

I use Rubocop to enforce code style and best practices, with a pre-commit hook to run it before every commit. I also use a GitHub Action to run Rubocop on every push, so that any issues are caught early.

### Project initialization

I start by creating a Git repository, initialized with a README.md briefly describing the project and how to run it.

I made four diagram before coding to clarify the architecture and the interactions between the different components. The diagrams are stored in the `docs` folder, in Mermaid format (display by Github, and can be exported to PNG or SVG), so that they can be easily updated and rendered.

I set up a Kanban board in Github to track progress, with a card per story organized into columns for the development stages (To do, In progress, Done).

### Architecture

Voir les diagrammes dans [docs/architecture.md](architecture.md). The architecture is simple, with two main models: `Quote` and `QuoteItem`, and a non-persisted model `QuoteTotals` to compute the totals. The controllers are standard Rails controllers, with nested resources for the items and a separate controller for the validation action.

Objets principaux et responsabilités :

- **Quote** (ActiveRecord) : porte l'invariant central. Refuse toute mutation sur
  elle-même (rename, delete, validate) dès que status == validated. C'est le modèle,
  pas le contrôleur, qui décide.
- **QuoteItem** (ActiveRecord) : refuse toute création, modification ou suppression
  dès que quote.validated?. Le garde interroge le parent à chaque écriture, donc il
  tient même pour un accès qui ne passerait pas par Quotes::ItemsController.
- **QuoteTotals** (non persisté) : seule responsabilité, calculer HT / TVA / TTC
  à partir des items d'un devis. Contrat d'arrondi : total de ligne arrondi à 2
  décimales, regroupement par taux de TVA, TVA calculée une fois par groupe sur le
  sous-total arrondi, puis somme des groupes. Recalculé à la demande, jamais stocké.

Contrôleurs :

- QuotesController : CRUD standard sur les devis (index, new, create, edit, update,
  destroy, show).
- Quotes::ItemsController : imbriqué sous quotes, CRUD sur les items. Pas de
  accepts_nested_attributes_for, chaque action répond en Turbo Stream multi-cibles.
- Quotes::ValidationsController : sous-ressource REST, une seule action create,
  POST /quotes/:id/validation. Choisi plutôt qu'une action membre custom pour rester
  dans le vocabulaire REST standard (une validation est une ressource qu'on crée).

Comportement partagé :

- Le garde d'immutabilité est dupliqué en intention entre Quote et QuoteItem
  (chacun vérifie l'état du devis) mais pas en code : QuoteItem délègue à
  quote.validated?, il n'y a pas eu besoin d'extraire un concern pour deux
  vérifications aussi courtes. À revoir si un troisième modèle venait à partager
  la même règle.
- Les contrôleurs ne contiennent aucune logique de la règle métier, ils traduisent
  le refus du modèle en réponse HTTP (422 sur validation invalide, 409 sur écriture
  refusée pour cause d'immutabilité ou de lock_version périmé).

Entrée : routes.rb, resources :quotes imbriquant resources :items (Quotes::Items)
et resource :validation (Quotes::Validations, module: :quotes).

Points encore ouverts à date de cette entrée : type de quantity (entier ou décimal).

### Code conventions

The code follows the language's standard style guide, checked automatically with a linter, at minimum at pre-commit. A CI workflow to run the linter on every push could also be added; kept to pre-commit only if time is limited.

Example pre-commit hook from a previous project (Ruby, RuboCop, Docker), to adapt to the stack used here:

```bash
#!/bin/sh
echo "Running Rubocop via Docker..."
docker compose run --rm app bundle exec rubocop --force-exclusion \
  $(git diff --cached --name-only --diff-filter=ACM | grep '\.rb$')

if [ $? -ne 0 ]; then
  echo "Rubocop found issues. Commit aborted."
  exit 1
fi
```

The code is written in English.

The project is developed in iterations, one per story, each in a dedicated Git branch with atomic commits, merged into main once complete. Story #0 is reserved for project setup. Branches are named with a prefix indicating the type of work (feature, bugfix, refactor, etc.) followed by the story number and name, in English, e.g. `feature/1_story_name`.

Commits are also written in English and briefly describe the change using [Gitmoji](https://gitmoji.dev/), e.g. :sparkles: for a new feature.

## Various notes

I try to follow the specifications as closely as possible without over-interpreting, since I can't ask for clarification as I would in a real project. I note below anything found unclear or surprising during implementation, story by story.

### Story #1 - [Story name]

_[Add one subsection per story as it's implemented: assumptions made, edge cases, anything the specifications left open.]_

### Evolution ideas

- The user could be able to reposition items in a quote, to change the order in which they are displayed.
- Manage Quote Items in a separate view, so that they can be reused across quotes. This would allow the user to create a library of items, and to quickly add them to a quote without having to re-enter the same information.
- Add identification of the client or business associated with a quote.
- There should be a way to export the quote as a PDF or other format, to send it to the client.
- We should be able to send the Quote directly from the system if a client email address is registered.
- Avoid hard deleting a quote by default. Two possible approaches: archive it permanently to keep a full history of all quotes ever created, or move it to a bin for a limited retention period (e.g. 30 days) with the option to restore it, after which it's permanently deleted.
- Add pagination to the list of quotes, to avoid loading all quotes at once if there are many.
- Add authentication and per-partner account scoping, so quotes are tied to "my quotes" rather than a single shared list.
- Support multi-tenant separation between partner organizations, once authentication exists.
- Support discounts, at the item or quote level (percentage or fixed amount).
- Support multiple currencies.
- Add legal/sequential quote numbering, required in some jurisdictions for official commercial documents.
- Add a validity period or expiry date on a quote.
- Support electronic signature for client-side acceptance of a quote.
- Keep a version history of changes made to a quote over time, beyond the current draft/validated status.

## Retrospective

_[Suggested addition: a short wrap-up once the exercise is done, what went well, what you'd do differently, what took longer than expected.]_
