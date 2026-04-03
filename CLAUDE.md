# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BookShelf API — a Rails 8.1 API-only application for personal library management. Manages authors, books, and collections with full CRUD, search, and statistics. No authentication (single-user, v1).

## Commands

```bash
# Setup
bin/setup                          # Install deps, prepare DB, start server

# Development
bin/rails server                   # Start dev server
bin/rails db:migrate               # Run migrations
bin/rails db:seed                  # Load seed data

# Testing
bundle exec rspec                  # Run full test suite
bundle exec rspec spec/models/     # Run model specs only
bundle exec rspec spec/requests/   # Run request/integration specs only
bundle exec rspec spec/models/book_spec.rb:42  # Run single test by line number
rake rswag:specs:swaggerize        # Generate OpenAPI docs from request specs

# Linting & Security
bundle exec rubocop                # Lint (rubocop-rails-omakase style)
bundle exec rubocop -a             # Lint with auto-fix
bundle exec brakeman               # Security scan
bundle exec bundler-audit check    # Gem vulnerability check

# Full CI locally
bin/ci                             # Runs rubocop + bundler-audit + brakeman + tests + seed check
```

## Architecture

**API-only Rails app** — `ActionController::API` base, JSON in/out, no views or sessions.

### Controller Hierarchy

All endpoints live under `/api`. Controllers inherit from `Api::BaseController` which composes three concerns:

- **ErrorHandler** (`app/controllers/concerns/error_handler.rb`) — Centralized `rescue_from` mapping, `render_success`/`render_error` envelope helpers, Content-Type enforcement on POST/PUT
- **Paginatable** (`app/controllers/concerns/paginatable.rb`) — Parses `page`/`per_page` params, returns `[records, meta]`
- **Sortable** (`app/controllers/concerns/sortable.rb`) — Validates `sort_by`/`sort_order` against per-controller allowed fields

Controllers: `Api::AuthorsController`, `Api::BooksController`, `Api::CollectionsController`, `Api::CollectionBooksController`, `Api::SearchController`, `Api::StatsController`.

### Models & Business Logic

- **Models** own validations, associations, scopes, and constants (e.g., `Book::GENRES`, `Book::READ_STATUSES`)
- **Model concerns**: `Filterable` (scope-chaining from params), `Sanitizable` (trim whitespace + strip HTML before validation)
- **Custom validators** (`app/validators/`): `IsbnValidator` (ISBN-13 check digit), `RatingIncrementValidator` (0.0–5.0 in 0.5 steps)
- **Query objects** (`app/queries/`): `StatsQuery` for aggregate statistics
- **Service objects** (`app/services/`): `CollectionReorderService` for reordering books in a collection

### Response Envelope

All responses use a consistent envelope:
- Success: `{ "data": ..., "meta": { page, per_page, total_items, total_pages } }` (meta only on lists)
- Error: `{ "error": { "code": "ERROR_CODE", "message": "...", "details": [...] } }`

Error codes: `VALIDATION_ERROR` (422), `NOT_FOUND` (404), `CONFLICT` (409), `DEPENDENCY_EXISTS` (409), `BAD_REQUEST` (400), `INTERNAL_ERROR` (500).

### Serialization

Plain Ruby hashes via private controller methods (`serialize_author`, `serialize_book`, etc.) — no serializer gem.

### Database

SQLite3. Four tables: `authors`, `books`, `collections`, `collection_books` (join with position).

Key FK behavior: author deletion is RESTRICT (blocked if books exist), collection_books cascade on both collection and book deletion. ISBN has a partial unique index (`WHERE isbn IS NOT NULL`). Genre and read_status are strings validated at the model level.

### Testing

RSpec + RSwag (request specs generate OpenAPI docs) + FactoryBot + shoulda-matchers. Swagger UI at `/api-docs`.

## Key Specification Reference

The full product spec is at `docs/specification.md`. Architecture decisions are documented in `ENGINEERING.md`.
