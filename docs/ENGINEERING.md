# BookShelf API — Engineering Decisions

## 1. Technology Stack

| Component | Choice | Version |
|-----------|--------|---------|
| Language | Ruby | 3.2.2 |
| Framework | Rails (API-only mode) | 8.1.x |
| Database | SQLite3 | >= 2.1 |
| Web Server | Puma | >= 5.0 |
| Testing | RSpec + RSwag | — |
| API Documentation | Swagger/OpenAPI 3.0 via RSwag | — |

**Why Rails API-only mode?** The app has no server-rendered views. `ActionController::API` is a thinner stack — no session middleware, no cookie handling, no CSRF protection, no asset pipeline. This reduces memory footprint and request overhead.

**Why SQLite3?** The specification describes a personal library app — single-user, moderate data volume. SQLite avoids operational complexity (no database server process). Rails 8.1 has first-class SQLite support including solid_cache, solid_queue, and solid_cable backed by SQLite. The architecture does not preclude migrating to PostgreSQL later if multi-user support is added.

---

## 2. Architecture

### 2.1 Controller Hierarchy

```
ApplicationController < ActionController::API
  Api::BaseController                           # includes all shared concerns
    Api::AuthorsController
    Api::BooksController
    Api::CollectionsController
    Api::CollectionBooksController              # nested under collections
    Api::SearchController
    Api::StatsController
```

All API controllers live under the `Api::` namespace (routed under `/api`). `Api::BaseController` is the single place where cross-cutting behavior is composed via concerns.

### 2.2 Responsibility Map

| Layer | Location | Responsibility |
|-------|----------|---------------|
| Models | `app/models/` | Validations, associations, scopes, callbacks, constants |
| Model Concerns | `app/models/concerns/` | `Filterable` (scope chaining), `Sanitizable` (trim + strip HTML) |
| Controller Concerns | `app/controllers/concerns/` | `ErrorHandler`, `Paginatable`, `Sortable` |
| Custom Validators | `app/validators/` | `IsbnValidator`, `RatingIncrementValidator` |
| Query Objects | `app/queries/` | `StatsQuery` — encapsulates aggregate statistics |
| Service Objects | `app/services/` | `CollectionReorderService` — multi-step collection reordering |

**Decision: Models over service objects for most logic.** Validations, scopes, and simple derived data live in models. Service objects are reserved for multi-step operations that coordinate across models (only `CollectionReorderService` qualifies). Query objects encapsulate complex read-only SQL that doesn't belong in a scope.

**Decision: No serializer gem.** The API has 4 entities. Plain Ruby hashes via private controller methods (`serialize_author`, `serialize_book`, etc.) are explicit, easy to trace, and avoid framework indirection. If the API grows past ~15 entities, consider Alba or Blueprinter.

### 2.3 Response Envelope

Every response passes through `render_success` or `render_error` in the `ErrorHandler` concern.

**Success (single resource):**
```json
{
  "data": { "id": 1, "first_name": "Gabriel", ... }
}
```

**Success (list with pagination):**
```json
{
  "data": [ ... ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total_items": 142,
    "total_pages": 8
  }
}
```

**Error:**
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": [
      { "field": "isbn", "message": "must be exactly 13 digits" }
    ]
  }
}
```

The `meta` key is omitted on non-list responses. The `details` key is omitted on non-validation errors.

---

## 3. Folder Structure

```
app/
  controllers/
    application_controller.rb
    concerns/
      error_handler.rb                 # rescue_from, render_success/error, content-type check
      paginatable.rb                   # page/per_page parsing, offset/limit, meta generation
      sortable.rb                      # sort_by/sort_order validation and .order() application
    api/
      base_controller.rb               # includes ErrorHandler, Paginatable, Sortable
      authors_controller.rb
      books_controller.rb
      collections_controller.rb
      collection_books_controller.rb   # add/remove/reorder books in collections
      search_controller.rb
      stats_controller.rb
  models/
    application_record.rb
    concerns/
      filterable.rb                    # class method to chain scopes from params
      sanitizable.rb                   # before_validation: trim whitespace, strip HTML tags
    author.rb
    book.rb
    collection.rb
    collection_book.rb
  validators/
    isbn_validator.rb                  # ISBN-13 format + check digit algorithm
    rating_increment_validator.rb      # 0.0–5.0 in 0.5 increments
  queries/
    stats_query.rb                     # aggregate library statistics
  services/
    collection_reorder_service.rb      # validate and apply new book ordering
db/
  migrate/
    YYYYMMDD_create_authors.rb
    YYYYMMDD_create_books.rb
    YYYYMMDD_create_collections.rb
    YYYYMMDD_create_collection_books.rb
  seeds.rb
spec/
  factories/                           # FactoryBot factory definitions
  models/                              # Unit specs for models
  validators/                          # Unit specs for custom validators
  services/                            # Unit specs for service objects
  requests/api/                        # RSwag integration/request specs
  swagger_helper.rb                    # RSwag configuration and shared schemas
  rails_helper.rb
  spec_helper.rb
swagger/
  v1/swagger.yaml                      # Auto-generated OpenAPI 3.0 spec
```

All directories under `app/` are autoloaded by Rails. No configuration needed for `validators/`, `queries/`, or `services/`.

---

## 4. Dependencies

### Added Gems

| Gem | Group | Purpose | Decision Rationale |
|-----|-------|---------|-------------------|
| `rspec-rails` | dev, test | Test framework | RSpec's expressive DSL and ecosystem (RSwag, shoulda) make it the better choice for API testing |
| `rswag-specs` | dev, test | Write specs that generate OpenAPI docs | Tests and API documentation from a single source of truth |
| `rswag-api` | default | Serve generated Swagger JSON | Required for Swagger UI to function |
| `rswag-ui` | default | Swagger UI at `/api-docs` | Interactive API exploration and testing |
| `factory_bot_rails` | dev, test | Test data factories | Flexible test data with traits, sequences, and associations |
| `shoulda-matchers` | test | One-liner model matchers | Concise validation and association specs |
| `database_cleaner-active_record` | test | Database cleaning between tests | Ensures test isolation |

### Explicitly Not Added

| Concern | Decision | Reason |
|---------|----------|--------|
| JSON serialization | Plain hashes | 4 entities — a gem adds indirection without value at this scale |
| Pagination | Hand-rolled (~10 LOC) | `offset`/`limit` with a meta builder is trivial; kaminari/pagy are overkill |
| HTML sanitization | `Rails::HTML5::FullSanitizer` | Ships with Rails, no extra dependency |
| ISBN validation | Custom validator (~20 LOC) | The ISBN-13 check digit algorithm is simple and self-contained |
| Authentication | None | Out of scope for v1 per specification |
| CORS | Commented out (rack-cors) | Already in Gemfile; uncomment when a frontend client is introduced |

---

## 5. Database Design

### 5.1 Entity-Relationship Diagram

```
┌──────────┐       ┌──────────┐       ┌─────────────────┐       ┌──────────────┐
│  authors │───1:N─│  books   │───N:M─│ collection_books │───M:1─│  collections │
└──────────┘       └──────────┘       └─────────────────┘       └──────────────┘
```

### 5.2 Tables

#### authors

| Column | Type | Constraints |
|--------|------|------------|
| id | integer | PK, auto-increment |
| first_name | string(100) | NOT NULL |
| last_name | string(100) | NOT NULL |
| bio | text | nullable |
| birth_year | integer | nullable |
| death_year | integer | nullable |
| website | string | nullable |
| created_at | datetime | NOT NULL |
| updated_at | datetime | NOT NULL |

**Indexes:** `(last_name, first_name)` — composite for sorted listing and search.

#### books

| Column | Type | Constraints |
|--------|------|------------|
| id | integer | PK, auto-increment |
| title | string(300) | NOT NULL |
| isbn | string(13) | nullable, UNIQUE (partial: WHERE isbn IS NOT NULL) |
| author_id | integer | NOT NULL, FK → authors(id) RESTRICT |
| published_year | integer | nullable |
| genre | string | NOT NULL |
| description | text | nullable |
| page_count | integer | nullable |
| language | string(10) | NOT NULL, default: "en" |
| rating | decimal(2,1) | nullable |
| read_status | string | NOT NULL, default: "unread" |
| date_added | datetime | NOT NULL |
| created_at | datetime | NOT NULL |
| updated_at | datetime | NOT NULL |

**Indexes:** `isbn` (unique partial), `genre`, `read_status`, `language`, `rating`, `published_year`, `date_added`, `author_id`.

**Decision: Partial unique index on ISBN.** ISBN is optional. A standard unique index would prevent multiple NULL values in some databases. The partial index (`WHERE isbn IS NOT NULL`) ensures uniqueness only among non-null values. SQLite supports this syntax.

**Decision: `genre` and `read_status` as strings, not enums.** SQLite has no native enum type. String columns with model-level `inclusion` validations are the pragmatic choice. The allowed values are defined as constants on the Book model.

#### collections

| Column | Type | Constraints |
|--------|------|------------|
| id | integer | PK, auto-increment |
| name | string(200) | NOT NULL, UNIQUE |
| description | text | nullable |
| is_public | boolean | NOT NULL, default: false |
| created_at | datetime | NOT NULL |
| updated_at | datetime | NOT NULL |

**Indexes:** `name` (unique).

#### collection_books (join table)

| Column | Type | Constraints |
|--------|------|------------|
| id | integer | PK, auto-increment |
| collection_id | integer | NOT NULL, FK → collections(id) CASCADE |
| book_id | integer | NOT NULL, FK → books(id) CASCADE |
| position | integer | NOT NULL |

**Indexes:** `(collection_id, book_id)` unique composite, `(collection_id, position)`.

**Decision: No timestamps on join table.** The specification does not track when a book was added to a collection, and the join table serves purely as an ordered association.

### 5.3 Foreign Key Strategy

| FK | On Delete | Rationale |
|----|-----------|-----------|
| `books.author_id → authors` | RESTRICT (default) | Spec requires 409 when deleting author with books |
| `collection_books.collection_id → collections` | CASCADE | Deleting a collection removes all associations |
| `collection_books.book_id → books` | CASCADE | Deleting a book removes it from all collections |

**Decision: Database-level cascades on collection_books.** Using `ON DELETE CASCADE` at the FK level ensures referential integrity even if Rails callbacks are bypassed (e.g., `delete_all`, raw SQL). The model also declares `dependent: :destroy` for cases where callbacks are needed in the future.

**Decision: RESTRICT on author deletion.** The controller explicitly checks for associated books and returns a `DEPENDENCY_EXISTS` error with the book count. The model uses `dependent: :restrict_with_error` as a safety net.

---

## 6. Error Handling

### 6.1 Centralized via ErrorHandler Concern

All error handling is centralized in `app/controllers/concerns/error_handler.rb`, included by `Api::BaseController`. This ensures every API endpoint returns consistently structured error responses.

### 6.2 Exception-to-Response Mapping

| Exception | Error Code | HTTP Status |
|-----------|-----------|-------------|
| `ActiveRecord::RecordNotFound` | `NOT_FOUND` | 404 |
| `ActiveRecord::RecordNotUnique` | `CONFLICT` | 409 |
| `ActionController::ParameterMissing` | `BAD_REQUEST` | 400 |
| `ActionDispatch::Http::Parameters::ParseError` | `BAD_REQUEST` | 400 |
| Model validation failure (`.save` returns false) | `VALIDATION_ERROR` | 422 |
| Delete author with associated books | `DEPENDENCY_EXISTS` | 409 |
| Unexpected exception | `INTERNAL_ERROR` | 500 |

### 6.3 Content-Type Enforcement

A `before_action` on `Api::BaseController` for `create` and `update` actions validates that `request.content_type` includes `application/json`. Returns 400 `BAD_REQUEST` if missing or incorrect.

### 6.4 Validation Error Details

```ruby
model.errors.map { |error| { field: error.attribute.to_s, message: error.message } }
```

Each validation error produces a `details` array entry with the field name and a human-readable message.

### 6.5 Conflict Detection

ISBN uniqueness and collection name uniqueness are validated at both levels:
1. **Model validation** (`validates :isbn, uniqueness: true`) — catches most cases and returns a clean 422.
2. **Database unique index** — `rescue ActiveRecord::RecordNotUnique` as a safety net for race conditions, returns 409.

---

## 7. Pagination, Sorting, and Filtering

### 7.1 Pagination (Paginatable Concern)

- Parses `page` (default: 1, minimum: 1) and `per_page` (default: 20, clamped: 1–100) from query params.
- Uses `ActiveRecord#offset` and `#limit` — no gem.
- Returns `[records, meta]` where meta contains `page`, `per_page`, `total_items`, `total_pages`.
- `total_items` uses `scope.count` before applying offset/limit.

**Decision: Hand-rolled pagination.** The implementation is ~10 lines. Kaminari and Pagy add API surface, configuration, and dependencies for functionality we fully control.

### 7.2 Sorting (Sortable Concern)

- Each controller declares `SORTABLE_FIELDS` (a hash mapping param names to column expressions) and `DEFAULT_SORT`.
- The concern validates `sort_by` against allowed fields and `sort_order` against `["asc", "desc"]`.
- Invalid sort fields are silently replaced with the default (not an error).
- For virtual columns like `book_count`, the controller joins/subqueries before sorting.

### 7.3 Filtering (Filterable Concern)

- Each filterable parameter maps to a named scope on the model.
- The `Filterable` concern provides a class method that iterates over allowed filter params and chains matching scopes.
- Filters are AND-combined (all conditions must match).
- Example scopes on Book: `by_genre`, `by_read_status`, `by_author_id`, `by_language`, `rating_min`, `rating_max`, `published_year_min`, `published_year_max`, `search`.

---

## 8. Input Sanitization

### Sanitizable Concern

Included in all models. Runs `before_validation` to:

1. **Trim whitespace** — `strip` on all string and text attributes.
2. **Strip HTML tags** — `Rails::HTML5::FullSanitizer.new.sanitize(value)` on all string and text attributes.

**Decision: Rails built-in sanitizer over a gem.** `rails-html-sanitizer` ships with Rails. No additional dependency needed.

**Decision: Sanitize before validation.** This ensures length validations run against the cleaned value, and the database never stores leading/trailing whitespace or HTML.

---

## 9. Custom Validators

### 9.1 IsbnValidator (`app/validators/isbn_validator.rb`)

Validates ISBN-13 format:
1. Must be exactly 13 digits (string of numeric characters).
2. Must pass the ISBN-13 check digit algorithm:
   - Multiply each of the first 12 digits alternately by 1 and 3.
   - Sum the products.
   - Check digit = `(10 - (sum % 10)) % 10`.
   - The 13th digit must equal the check digit.

### 9.2 RatingIncrementValidator (`app/validators/rating_increment_validator.rb`)

Validates rating values:
- Must be between 0.0 and 5.0 inclusive.
- Must be a multiple of 0.5 (i.e., `(value * 2) == (value * 2).to_i`).
- Rejects values like 3.7, -1, 5.5, 6.

---

## 10. Routing

```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  namespace :api do
    resources :authors, only: [:index, :show, :create, :update, :destroy] do
      get :books, on: :member
    end
    resources :books, only: [:index, :show, :create, :update, :destroy]
    resources :collections, only: [:index, :show, :create, :update, :destroy] do
      resources :books, only: [:create, :destroy], controller: "collection_books"
      put "books/reorder", to: "collection_books#reorder"
    end
    get :search, to: "search#index"
    get :stats, to: "stats#index"
  end
end
```

### Generated Routes

| Method | Path | Controller#Action |
|--------|------|-------------------|
| GET | /api/authors | api/authors#index |
| POST | /api/authors | api/authors#create |
| GET | /api/authors/:id | api/authors#show |
| PUT | /api/authors/:id | api/authors#update |
| DELETE | /api/authors/:id | api/authors#destroy |
| GET | /api/authors/:id/books | api/authors#books |
| GET | /api/books | api/books#index |
| POST | /api/books | api/books#create |
| GET | /api/books/:id | api/books#show |
| PUT | /api/books/:id | api/books#update |
| DELETE | /api/books/:id | api/books#destroy |
| GET | /api/collections | api/collections#index |
| POST | /api/collections | api/collections#create |
| GET | /api/collections/:id | api/collections#show |
| PUT | /api/collections/:id | api/collections#update |
| DELETE | /api/collections/:id | api/collections#destroy |
| POST | /api/collections/:collection_id/books | api/collection_books#create |
| DELETE | /api/collections/:collection_id/books/:id | api/collection_books#destroy |
| PUT | /api/collections/:collection_id/books/reorder | api/collection_books#reorder |
| GET | /api/search | api/search#index |
| GET | /api/stats | api/stats#index |

---

## 11. Testing Strategy

### 11.1 Framework Stack

| Tool | Role |
|------|------|
| RSpec | Test runner and assertion framework |
| RSwag | Request specs that double as OpenAPI documentation generators |
| FactoryBot | Test data factories with traits and sequences |
| shoulda-matchers | One-liner model validation and association matchers |
| database_cleaner | Transaction-based test isolation |

### 11.2 Test Organization

```
spec/
  models/              → Unit tests: validations, scopes, associations, callbacks
  validators/          → Unit tests: ISBN-13 algorithm, rating increment logic
  services/            → Unit tests: CollectionReorderService
  requests/api/        → Integration tests: full HTTP request/response cycle (RSwag)
  factories/           → FactoryBot definitions
```

### 11.3 What Gets Tested Where

**Model specs (unit):**
- Every validation (presence, length, inclusion, format, numericality, custom)
- Associations and dependent behavior
- Each named scope (filter returns correct records)
- Callbacks (`set_date_added`, sanitization)
- Derived methods (`Author#full_name`)

**Validator specs (unit):**
- `IsbnValidator`: valid ISBN-13, invalid check digit, wrong length, non-numeric, empty string
- `RatingIncrementValidator`: each valid increment (0, 0.5, 1.0, ..., 5.0), invalid values (3.7, -1, 5.5, 6)

**Service specs (unit):**
- `CollectionReorderService`: valid reorder, missing books, extra books, duplicates, empty collection

**Request specs (RSwag integration):**
- CRUD happy paths: correct status codes, response envelope shape, data content
- Validation failures: each required field missing, each constraint violated (422 + details)
- Not found: non-existent IDs (404)
- Conflicts: duplicate ISBN, duplicate collection name (409)
- Dependency protection: delete author with books (409 DEPENDENCY_EXISTS)
- Pagination: default values, custom page/per_page, beyond last page (empty data), invalid values
- Sorting: each allowed sort field, both asc and desc
- Filtering: each filter individually, combined filters
- Search: minimum query length, type filter, result grouping
- Statistics: correct calculations with realistic data

### 11.4 RSwag Documentation Generation

Running `rake rswag:specs:swaggerize` generates `swagger/v1/swagger.yaml` from the request specs. Swagger UI is mounted at `/api-docs` for interactive browsing and testing.

Shared component schemas are defined in `swagger_helper.rb`:
- Input schemas: `author_input`, `book_input`, `collection_input`
- Response schemas: `author_response`, `book_response`, `collection_response`
- List schemas: `authors_response`, `books_response`, `collections_response`
- Error schemas: `error_response`, `validation_error_response`
- `pagination_meta`

---

## 12. Seed Data

The seed file (`db/seeds.rb`) provides realistic sample data for development and demo:

- **10+ authors** spanning different eras and regions
- **30+ books** across multiple genres, with varied ratings, read statuses, and languages
- **5+ collections** with themes (e.g., "Classics", "Science Must-Reads", "Latin American Literature")
- Books distributed across collections with realistic overlap

All seed data uses valid ISBNs, allowed genres, and proper foreign key references.

---

## 13. Implementation Phases

| Phase | Scope | Depends On |
|-------|-------|------------|
| 0 | Test infrastructure setup (RSpec, RSwag, FactoryBot, shoulda, database_cleaner) | — |
| 1 | Migrations, models, validators, concerns, factories, model specs | Phase 0 |
| 2 | Controller concerns (ErrorHandler, Paginatable, Sortable), BaseController | Phase 1 |
| 3 | CRUD controllers, routes, RSwag request specs | Phase 2 |
| 4 | Search controller, StatsQuery, Stats controller, request specs | Phase 3 |
| 5 | Seed data, full test suite run, rubocop, brakeman | Phase 4 |
