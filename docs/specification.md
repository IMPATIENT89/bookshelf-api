# BookShelf — Product Specification

**Version:** 1.0
**Date:** April 2026
**Status:** Final

---

## 1. Overview

BookShelf is a personal library management application. It allows users to catalog their book collection, organize books into custom collections, discover relationships between authors and their works, and gain insights into their reading patterns.

The system exposes a RESTful API that serves as the backend for any client application (web, mobile, CLI). This specification defines the data model, business rules, API contracts, and expected behaviors.

---

## 2. Core Entities

### 2.1 Author

An author represents a person who has written one or more books.

| Field | Description | Constraints |
|-------|-------------|-------------|
| id | Unique identifier | System-generated, immutable |
| first_name | Author's first/given name | Required, 1–100 characters |
| last_name | Author's last/family name | Required, 1–100 characters |
| bio | Biographical summary | Optional, max 2000 characters |
| birth_year | Year of birth | Optional, integer, must be ≤ current year |
| death_year | Year of death | Optional, integer, must be ≥ birth_year if both present |
| website | Author's website URL | Optional, must be valid URL format |
| created_at | Record creation timestamp | System-generated, immutable |
| updated_at | Last modification timestamp | System-managed |

**Business Rules:**
- An author's full name (first_name + last_name) does not need to be unique — multiple authors may share names.
- Deleting an author is only permitted if they have no associated books. If books exist, the client must reassign or delete them first.
- When retrieving an author, the response must include a count of their associated books.

### 2.2 Book

A book represents a single published work in the user's library.

| Field | Description | Constraints |
|-------|-------------|-------------|
| id | Unique identifier | System-generated, immutable |
| title | Book title | Required, 1–300 characters |
| isbn | ISBN-13 identifier | Optional, must be valid ISBN-13 format (13 digits), unique if provided |
| author_id | Reference to the author | Required, must reference an existing author |
| published_year | Year of publication | Optional, integer, range 1000–current year |
| genre | Book genre/category | Required, must be one of the allowed genres (see §2.2.1) |
| description | Synopsis or summary | Optional, max 5000 characters |
| page_count | Number of pages | Optional, positive integer |
| language | Language of the text | Optional, ISO 639-1 code (e.g., "en", "fr", "es"), defaults to "en" |
| rating | User's personal rating | Optional, decimal 0.0–5.0 in 0.5 increments |
| read_status | Whether the user has read it | Required, one of: "unread", "reading", "read", defaults to "unread" |
| date_added | When the book was added to the library | System-generated, immutable |
| created_at | Record creation timestamp | System-generated, immutable |
| updated_at | Last modification timestamp | System-managed |

#### 2.2.1 Allowed Genres

The system supports the following genres. This list is fixed and not user-configurable:

- Fiction
- Non-Fiction
- Science Fiction
- Fantasy
- Mystery
- Thriller
- Romance
- Horror
- Biography
- History
- Science
- Philosophy
- Self-Help
- Business
- Technology
- Poetry
- Children
- Young Adult
- Graphic Novel
- Other

**Business Rules:**
- ISBN must be unique across all books. Two books cannot share the same ISBN.
- ISBN validation: must be exactly 13 digits. The system should validate the ISBN-13 check digit algorithm.
- A book must belong to exactly one author. Multi-author books are not supported in v1.
- Deleting a book automatically removes it from all collections it belongs to.
- Rating, if provided, must be in 0.5 increments (0, 0.5, 1.0, 1.5, ... 5.0). Values like 3.7 are invalid.
- When a book's read_status changes to "read", this is informational only — no additional side effects.

### 2.3 Collection

A collection is a user-curated list of books, similar to a playlist.

| Field | Description | Constraints |
|-------|-------------|-------------|
| id | Unique identifier | System-generated, immutable |
| name | Collection name | Required, 1–200 characters, must be unique |
| description | Purpose or theme of the collection | Optional, max 1000 characters |
| is_public | Whether the collection is visible publicly | Required, boolean, defaults to false |
| created_at | Record creation timestamp | System-generated, immutable |
| updated_at | Last modification timestamp | System-managed |

**Collection–Book Relationship:**
- A collection contains zero or more books.
- A book can belong to zero or more collections.
- The order of books within a collection matters. Each book has a `position` (integer) within the collection.
- Adding a book that already exists in the collection should return an error, not create a duplicate.

**Business Rules:**
- Collection names must be unique. Attempting to create a duplicate name returns an error.
- Deleting a collection does not delete the books in it — only the association is removed.
- When a book is removed from a collection, the positions of remaining books must be recalculated to remain contiguous (no gaps).
- Collections can be reordered — the client can send a new ordering for books within a collection.

---

## 3. API Endpoints

All endpoints return JSON. The API uses standard HTTP methods and status codes.

### 3.1 Response Envelope

All successful responses follow this structure:

```
{
  "data": <result>,
  "meta": { ... }       // optional, present on list endpoints
}
```

All error responses follow this structure:

```
{
  "error": {
    "code": "<ERROR_CODE>",
    "message": "<human-readable message>",
    "details": [ ... ]   // optional, for validation errors
  }
}
```

### 3.2 Pagination

All list endpoints support pagination with these query parameters:

| Parameter | Description | Default | Constraints |
|-----------|-------------|---------|-------------|
| page | Page number | 1 | Positive integer |
| per_page | Items per page | 20 | 1–100 |

Paginated responses include a `meta` object:

```
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

### 3.3 Sorting

List endpoints support sorting:

| Parameter | Description | Default |
|-----------|-------------|---------|
| sort_by | Field to sort by | Varies per endpoint |
| sort_order | "asc" or "desc" | "asc" |

Valid sort fields are specified per endpoint below.

### 3.4 Filtering

List endpoints support filtering via query parameters. Filters are ANDed together (all conditions must match).

---

### 3.5 Author Endpoints

#### 3.5.1 List Authors

```
GET /api/authors
```

**Query Parameters:**
- Pagination: `page`, `per_page`
- Sort: `sort_by` (allowed: `last_name`, `first_name`, `created_at`, `book_count`), default: `last_name`
- Filter: `search` (searches first_name and last_name, case-insensitive partial match)

**Response:** Paginated list of authors. Each author includes `book_count`.

**Status Codes:** 200

#### 3.5.2 Get Author

```
GET /api/authors/:id
```

**Response:** Single author with `book_count` and a `recent_books` array (last 5 books by the author, ordered by `date_added` descending).

**Status Codes:** 200, 404

#### 3.5.3 Create Author

```
POST /api/authors
```

**Request Body:**

```
{
  "first_name": "Gabriel",
  "last_name": "García Márquez",
  "bio": "Colombian novelist...",
  "birth_year": 1927,
  "death_year": 2014,
  "website": "https://example.com"
}
```

**Validation:**
- `first_name`: required, 1–100 chars
- `last_name`: required, 1–100 chars
- `bio`: optional, max 2000 chars
- `birth_year`: optional, integer ≤ current year
- `death_year`: optional, integer ≥ `birth_year` (if both provided)
- `website`: optional, valid URL

**Status Codes:** 201, 422 (validation failure)

#### 3.5.4 Update Author

```
PUT /api/authors/:id
```

Accepts same fields as create. Partial updates are supported — only provided fields are updated.

**Status Codes:** 200, 404, 422

#### 3.5.5 Delete Author

```
DELETE /api/authors/:id
```

**Business Rule:** Fails if the author has associated books.

**Status Codes:** 204, 404, 409 (has associated books)

#### 3.5.6 List Books by Author

```
GET /api/authors/:id/books
```

**Query Parameters:** Same pagination and sorting as book list endpoint.

**Status Codes:** 200, 404 (author not found)

---

### 3.6 Book Endpoints

#### 3.6.1 List Books

```
GET /api/books
```

**Query Parameters:**
- Pagination: `page`, `per_page`
- Sort: `sort_by` (allowed: `title`, `published_year`, `date_added`, `rating`, `page_count`), default: `date_added`
- Filter:
  - `genre` — exact match, single value
  - `read_status` — exact match: "unread", "reading", "read"
  - `author_id` — exact match
  - `language` — exact match, ISO 639-1 code
  - `rating_min` — decimal, books with rating ≥ this value
  - `rating_max` — decimal, books with rating ≤ this value
  - `published_year_min` — integer, books published in or after this year
  - `published_year_max` — integer, books published in or before this year
  - `search` — case-insensitive partial match against title and description

All filters can be combined. When multiple filters are provided, results must match ALL conditions.

**Response:** Paginated list of books. Each book includes the author's full name (first_name + last_name) as `author_name`.

**Status Codes:** 200

#### 3.6.2 Get Book

```
GET /api/books/:id
```

**Response:** Single book with full author object embedded (not just author_id).

**Status Codes:** 200, 404

#### 3.6.3 Create Book

```
POST /api/books
```

**Request Body:**

```
{
  "title": "One Hundred Years of Solitude",
  "isbn": "9780060883287",
  "author_id": 1,
  "published_year": 1967,
  "genre": "Fiction",
  "description": "The multi-generational story of the Buendía family...",
  "page_count": 417,
  "language": "es",
  "rating": 4.5,
  "read_status": "read"
}
```

**Validation:**
- `title`: required, 1–300 chars
- `isbn`: optional, valid ISBN-13 (13 digits, valid check digit), unique
- `author_id`: required, must reference existing author
- `published_year`: optional, 1000–current year
- `genre`: required, must be from allowed genres list
- `description`: optional, max 5000 chars
- `page_count`: optional, positive integer
- `language`: optional, valid ISO 639-1 code, defaults to "en"
- `rating`: optional, 0.0–5.0 in 0.5 increments
- `read_status`: optional, one of: "unread", "reading", "read", defaults to "unread"

**Status Codes:** 201, 422 (validation failure), 409 (duplicate ISBN)

#### 3.6.4 Update Book

```
PUT /api/books/:id
```

Accepts same fields as create. Partial updates are supported.

**Status Codes:** 200, 404, 422, 409 (duplicate ISBN)

#### 3.6.5 Delete Book

```
DELETE /api/books/:id
```

Deleting a book automatically removes it from all collections.

**Status Codes:** 204, 404

---

### 3.7 Collection Endpoints

#### 3.7.1 List Collections

```
GET /api/collections
```

**Query Parameters:**
- Pagination: `page`, `per_page`
- Sort: `sort_by` (allowed: `name`, `created_at`, `book_count`), default: `name`
- Filter:
  - `is_public` — boolean
  - `search` — case-insensitive partial match on name and description

**Response:** Paginated list of collections. Each collection includes `book_count`.

**Status Codes:** 200

#### 3.7.2 Get Collection

```
GET /api/collections/:id
```

**Response:** Single collection with its books array, ordered by `position`. Each book in the array includes the author's full name.

**Status Codes:** 200, 404

#### 3.7.3 Create Collection

```
POST /api/collections
```

**Request Body:**

```
{
  "name": "Summer Reading 2026",
  "description": "Books I plan to read this summer",
  "is_public": true
}
```

**Validation:**
- `name`: required, 1–200 chars, must be unique
- `description`: optional, max 1000 chars
- `is_public`: optional, boolean, defaults to false

**Status Codes:** 201, 422, 409 (duplicate name)

#### 3.7.4 Update Collection

```
PUT /api/collections/:id
```

Accepts same fields as create. Partial updates supported.

**Status Codes:** 200, 404, 422, 409 (duplicate name)

#### 3.7.5 Delete Collection

```
DELETE /api/collections/:id
```

Deletes the collection and all book–collection associations. Does NOT delete the books themselves.

**Status Codes:** 204, 404

#### 3.7.6 Add Book to Collection

```
POST /api/collections/:id/books
```

**Request Body:**

```
{
  "book_id": 42
}
```

The book is added at the end of the collection (highest position + 1).

**Validation:**
- `book_id`: required, must reference existing book
- Book must not already exist in the collection

**Status Codes:** 201, 404 (collection or book not found), 409 (book already in collection), 422

**Response:** The updated collection with all books.

#### 3.7.7 Remove Book from Collection

```
DELETE /api/collections/:id/books/:book_id
```

Removes the book from the collection. Remaining books' positions are recalculated to be contiguous starting from 1.

**Status Codes:** 204, 404 (collection, book, or association not found)

#### 3.7.8 Reorder Books in Collection

```
PUT /api/collections/:id/books/reorder
```

**Request Body:**

```
{
  "book_ids": [42, 17, 3, 88]
}
```

The `book_ids` array represents the new order. Position is assigned based on array index (first element = position 1).

**Validation:**
- `book_ids` must contain exactly the same set of book IDs currently in the collection — no additions, no removals, no duplicates
- If the set doesn't match, return a validation error

**Status Codes:** 200, 404, 422

---

### 3.8 Search Endpoint

```
GET /api/search
```

A unified search across books, authors, and collections.

**Query Parameters:**
- `q` — required, the search query string, minimum 2 characters
- `type` — optional, limit search to: "books", "authors", "collections". If omitted, search all types.
- Pagination: `page`, `per_page`

**Search Behavior:**
- Case-insensitive partial matching
- Books: searches `title`, `description`, `isbn`
- Authors: searches `first_name`, `last_name`, `bio`
- Collections: searches `name`, `description`
- Results are grouped by type in the response

**Response:**

```
{
  "data": {
    "books": [ ... ],
    "authors": [ ... ],
    "collections": [ ... ]
  },
  "meta": {
    "query": "garcía",
    "total_results": 7,
    "counts": {
      "books": 4,
      "authors": 2,
      "collections": 1
    }
  }
}
```

When `type` is specified, only that section is included in the response.

**Status Codes:** 200, 422 (query too short or missing)

---

### 3.9 Statistics Endpoint

```
GET /api/stats
```

Returns aggregate statistics about the library. No parameters.

**Response:**

```
{
  "data": {
    "total_books": 142,
    "total_authors": 47,
    "total_collections": 8,
    "books_by_status": {
      "read": 89,
      "reading": 12,
      "unread": 41
    },
    "books_by_genre": [
      { "genre": "Fiction", "count": 34 },
      { "genre": "Science Fiction", "count": 22 },
      ...
    ],
    "books_by_year": [
      { "year": 2024, "count": 15 },
      { "year": 2023, "count": 22 },
      ...
    ],
    "top_authors": [
      { "author_id": 1, "author_name": "Stephen King", "book_count": 12 },
      { "author_id": 5, "author_name": "Ursula K. Le Guin", "book_count": 8 },
      ...
    ],
    "average_rating": 3.7,
    "total_pages": 48291,
    "average_pages_per_book": 340,
    "language_distribution": [
      { "language": "en", "count": 120 },
      { "language": "es", "count": 15 },
      ...
    ]
  }
}
```

**Details:**
- `books_by_genre`: sorted by count descending, include all genres that have at least 1 book
- `books_by_year`: sorted by year descending, include only years with at least 1 book, limited to last 10 years
- `top_authors`: top 10 authors by book count, sorted by count descending
- `average_rating`: calculated across all books that have a rating (exclude unrated books), rounded to 1 decimal
- `language_distribution`: sorted by count descending

**Status Codes:** 200

---

## 4. Error Handling

### 4.1 Error Codes

The system uses the following error codes consistently:

| Code | HTTP Status | Meaning |
|------|-------------|---------|
| VALIDATION_ERROR | 422 | Request body or parameters failed validation |
| NOT_FOUND | 404 | The requested resource does not exist |
| CONFLICT | 409 | Action conflicts with existing data (duplicate ISBN, name, etc.) |
| DEPENDENCY_EXISTS | 409 | Cannot delete because dependent records exist |
| BAD_REQUEST | 400 | Malformed request (invalid JSON, missing content type) |
| INTERNAL_ERROR | 500 | Unexpected server error |

### 4.2 Validation Error Details

When a validation error occurs, the `details` array provides per-field information:

```
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": [
      {
        "field": "isbn",
        "message": "ISBN must be exactly 13 digits"
      },
      {
        "field": "rating",
        "message": "Rating must be between 0 and 5 in 0.5 increments"
      }
    ]
  }
}
```

### 4.3 Not Found

```
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Author with id 999 not found"
  }
}
```

### 4.4 Conflict

```
{
  "error": {
    "code": "CONFLICT",
    "message": "A book with ISBN 9780060883287 already exists"
  }
}
```

```
{
  "error": {
    "code": "DEPENDENCY_EXISTS",
    "message": "Cannot delete author: 5 books are associated with this author"
  }
}
```

---

## 5. Data Integrity & Business Rules Summary

### 5.1 Referential Integrity

- Every book must reference a valid author. Creating a book with a non-existent `author_id` returns 422.
- Adding a book to a collection requires both the book and collection to exist.
- Deleting a book cascades to remove it from all collections.
- Deleting an author is blocked if books exist (returns 409).
- Deleting a collection removes only the associations, not the books.

### 5.2 Uniqueness Constraints

- ISBN must be unique across all books (when provided)
- Collection name must be unique

### 5.3 Timestamp Management

- `created_at` is set once when the record is created and never modified.
- `updated_at` is set on creation and updated on every modification.
- `date_added` (books only) is set once when the book is created.

### 5.4 Default Values

- `book.language` defaults to "en"
- `book.read_status` defaults to "unread"
- `collection.is_public` defaults to false

---

## 6. Seed Data

The system should be capable of being seeded with sample data for development and demonstration purposes. The seed dataset should include:

- At least 10 authors spanning different eras and regions
- At least 30 books across multiple genres, with varied ratings, read statuses, and languages
- At least 5 collections with meaningful themes (e.g., "Classics", "Science Must-Reads", "Latin American Literature", "2025 Reading List", "Short Books Under 200 Pages")
- Books distributed across collections with realistic overlap (some books in multiple collections)

The seed data must be consistent — all foreign keys valid, ISBNs properly formatted, genres from the allowed list.

---

## 7. Testing Requirements

### 7.1 Coverage Expectations

The system should have comprehensive test coverage:

- **Unit tests** for all business logic (validation rules, ISBN check digit, position recalculation, statistics computation)
- **Integration tests** for all API endpoints covering:
  - Happy path (valid request → expected response)
  - Validation failures (each field's constraints)
  - Not found cases
  - Conflict cases (duplicate ISBN, duplicate collection name, delete with dependencies)
  - Edge cases (empty collections, books with no rating, searches with special characters)
  - Pagination (first page, last page, beyond last page, custom per_page)
  - Sorting (each allowed sort field, ascending and descending)
  - Filtering (individual filters and combined filters)

### 7.2 Specific Test Scenarios

The following scenarios must be explicitly tested:

1. **ISBN validation** — valid ISBN-13 passes, invalid check digit fails, non-13-digit strings fail, duplicate ISBN fails
2. **Author deletion cascade protection** — cannot delete author with books, can delete author after all books removed
3. **Book deletion cascade** — deleting a book removes it from all collections, collection book counts update
4. **Collection position management** — positions stay contiguous after removal, reorder validates the book set
5. **Search** — returns correct types, respects the `type` filter, handles minimum query length
6. **Statistics** — calculations are correct with empty database, with one item, and with realistic data
7. **Rating validation** — accepts 0, 0.5, 1.0 ... 5.0; rejects 3.7, -1, 6
8. **Pagination edge cases** — page 0 returns error, per_page 0 returns error, page beyond total returns empty data array

---

## 8. Non-Functional Requirements

### 8.1 Response Times

- All single-resource operations (get, create, update, delete): < 100ms
- List operations with default pagination: < 200ms
- Search operations: < 300ms
- Statistics: < 500ms (acceptable to compute on the fly for v1)

### 8.2 Input Sanitization

- All text inputs must be trimmed of leading/trailing whitespace before storage
- HTML tags in text fields should be stripped or escaped
- The system must handle unicode characters correctly (author names, book titles in various languages)

### 8.3 Content Type

- The API accepts and returns `application/json` only
- Requests with missing or incorrect `Content-Type` header on POST/PUT should return 400

---

## 9. Future Considerations (Out of Scope for v1)

The following features are NOT part of v1 but may inform architectural decisions:

- Multi-author support for books (many-to-many relationship)
- User authentication and multi-user support
- Reading progress tracking (page number, percentage)
- Book cover image upload and storage
- Import/export (CSV, Goodreads, LibraryThing)
- Tags/labels (user-defined, in addition to genre)
- Book recommendations based on reading history
- Reading goals (yearly book count targets)
- Notes and highlights per book

These should not be implemented but the architecture should not make them impossible to add later.