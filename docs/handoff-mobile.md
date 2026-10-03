# Handoff: Cookbook Server → Mobile App

This document is the integration contract for the **mobile app** (the future project that owns the user's cookbook). It consolidates everything the mobile team needs to build against this server: the boundary between the two systems, the exact wire contract, and what the mobile app must implement locally.

Authoritative sources, kept in sync with this doc:

- `CONTEXT.md` — shared terminology (`OriginalRecipe`, `Recipe`, `Source`, `Import`, `Parse`, `Gate`, `Review`, `Ingredient`, `CalculatedNutrition`, `Match`, `Category`)
- `docs/adr/0001-*.md` — why the server is parse+auth only and recipes live client-side
- `docs/adr/0002-*.md` — the two-model parse pipeline (DeepSeek + Jev)
- `docs/adr/0003-*.md` — calculated nutrition from a canonical `Ingredient` table
- `docs/designs/apis.md` — narrative API documentation
- `docs/designs/data_models.md` — server and client data models
- `docs/designs/requirements.md` — product requirements
- `config/routes.rb` — canonical route list

---

## 1. System boundary

The server is a **thin parse + auth service**. It does **not** store the user's cookbook.

| Concern | Where it lives |
|---|---|
| Auth (register / login / Google / email confirm) | Server |
| Parse external sources into `OriginalRecipe` | Server |
| Global `OriginalRecipe` cache (keyed by `source_identifier`) | Server |
| Global `Ingredient` reference + calculated nutrition | Server |
| Recipe create / view / edit / delete / search | **Mobile, client-local only** |
| User's saved `Recipe`s and custom `Category`s | **Mobile, client-local only** |

**The mobile app is the offline-capable store of record for the user's cookbook.** Recipe CRUD makes no server call. The server is only ever contacted for auth and import.

A user's saved `Recipe` is a **fork** of an `OriginalRecipe`, not a live reference to it. Once forked, the user edits freely and offline; `original_recipe` is provenance only.

---

## 2. Authentication

All protected endpoints use a bearer session token:

```
Authorization: Bearer <token>
```

Token is returned by register/login/google and by `/auth/me` (via the same header). No refresh tokens in MVP.

### Endpoints

| Method | Path | Request | Success response |
|---|---|---|---|
| POST | `/auth/register` | `email`, `name`, `password` | `201 { "user": User }` |
| POST | `/auth/login` | `email`, `password` | `200 { "token": "...", "user": User }` |
| POST | `/auth/google` | `credential` (Google ID token) | `200 { "token": "...", "user": User }` |
| GET | `/auth/confirm/:token` | token in path (from email link) | `200 { "user": User }` |
| GET | `/auth/me` | bearer header | `200 { "user": User }` |

**User payload** (same shape everywhere):

```json
{
  "id": 1,
  "email": "user@example.com",
  "name": "Jane Doe",
  "confirmed": true
}
```

### Error shapes

- `422 { "error": "email has already been taken" }` — register with taken email
- `422 { "errors": { "email": [...], "password": [...] } }` — validation failure
- `422 { "error": "invalid confirmation token" }` — bad/expired confirm token
- `401 { "error": "invalid email or password" }` — login failure
- `401 { "error": "invalid Google ID token" }` — bad Google token
- `401 { "error": "unauthorized" }` — missing/invalid bearer token on protected route

### Confirmation requirement

`POST /auth/register` creates an **unconfirmed** account and sends a confirmation email. Google sign-in creates a **confirmed** account immediately.

**Import is blocked until the account is confirmed.** Without a token: `401 { "error": "unauthorized" }`. With a token but unconfirmed: `403 { "error": "confirm your email before importing recipes" }`.

---

## 3. Recipe import

The only way the mobile app asks the server for recipe content. Everything else is local.

### Submit

`POST /recipe-imports` — requires confirmed account.

Request uses the public field names `source` and `source_type`:

| `source_type` | `source` value |
|---|---|
| `web_page` | URL string |
| `image` | uploaded file (multipart) **or** base64 data URI |
| `pdf` | uploaded file (multipart) **or** base64 data URI |

**Responses:**

- Cache hit — `200`:

```json
{
  "import_id": 1,
  "status": "cached",
  "original_recipe": { "..." },
  "field_status": { "..." }
}
```

- Cache miss (parse enqueued) — `202`:

```json
{ "import_id": 1, "status": "processing" }
```

- Invalid source — `422 { "error": "..." }`

### Poll

`GET /recipe-imports/:id` — requires confirmed account.

- `200 { "import_id": 1, "status": "processing" }` — poll again
- `200 { "import_id": 1, "status": "done" | "cached", "original_recipe": {...}, "field_status": {...} }`
- `200` failed shape (below)
- `404 { "error": "import not found" }`

**Failed shape:**

```json
{
  "import_id": 1,
  "status": "failed",
  "error": "...",
  "error_code": "...",
  "retryable": true,
  "retry_count": 1,
  "retries_remaining": 2
}
```

### Retry

`POST /recipe-imports/:id/retry` — re-runs a failed import in place.

- `202 { "import_id": 1, "status": "processing" }` — retry consumed, re-enqueued
- `200 { "import_id": 1, "status": "cached", "original_recipe": {...}, "field_status": {...} }` — the source was parsed by another import in the meantime; **no retry is consumed**
- `404 { "error": "import not found" }`
- `409 { "error": "import is not failed" }`
- `409 { "error": "retry limit reached" }`

`import_id` is the integer `RecipeImport::Record` id. Every import response carries it, and it is the value used in the poll (`GET /recipe-imports/:id`) and retry (`POST /recipe-imports/:id/retry`) URLs.

Max retries: **3** (`retries_remaining` never goes below 0).

### Error codes

| `error_code` | Retryable? | Meaning |
|---|---|---|
| `fetch_http_5xx` | yes | Source server returned 5xx |
| `fetch_timeout` | yes | Source fetch timed out |
| `fetch_network_error` | yes | Network failure reaching source |
| `deep_seek_error` | yes | DeepSeek structuring call failed |
| `jev_error` | yes | Jev gate call failed |
| `fetch_http_4xx` | no | Source server returned 4xx |
| `fetch_not_html` | no | `web_page` source wasn't HTML |
| `fetch_error` | no | Other fetch failure |
| `no_recipe_found` | no | Image had no readable recipe (re-parsing same bytes can't help) |
| `unsupported_source_type` | no | `source_type` not `web_page`/`image`/`pdf` |
| `internal_error` | no | Unexpected server failure |

The mobile app should treat `retryable: true` as the signal to offer a retry button; `retries_remaining` caps it.

---

## 4. `original_recipe` wire contract

The exact JSON returned inside every `original_recipe` object (from `OriginalRecipeSerializer`):

```jsonc
{
  "id": 1,
  "name": "string | null",
  "description": "string | null",
  "ingredients": [
    {
      "name": "free text, e.g. \"2 chicken breasts\"",
      "quantity": 2.0,          // decimal; parsed by the nutrition stage
      "unit": "cup",            // canonical unit key; parsed by the nutrition stage
      "preparation": "string | null",
      "optional": false,
      "notes": "string | null"
    }
  ],
  "instructions": [
    { "position": 1, "content": "string" }
  ],
  "preparation_time": 15,       // integer minutes | null
  "cooking_time": 30,           // integer minutes | null
  "servings": 4,                // integer | null
  "calories": 400,              // integer | null (source-provided only)
  "nutritional_information": {}, // object | null (source-provided only)
  "calculated_nutritional_information": {
    "calories": 412,            // per-serving, integer
    "protein": 22.3,            // grams, 1 decimal
    "carbohydrates": 31.1,
    "fat": 18.4,
    "fiber": 2.0,
    "sugar": 6.1,
    "sodium": 510.2
  },
  "nutrition_status": "computed", // see below
  "unmatched_ingredients": ["a handful of herbs"],
  "original_source": "https://...", // URL, or content hash for image/pdf
  "source_identifier": "...",       // cache key: URL or content hash
  "categories": []                  // always empty in MVP
}
```

### Field semantics worth knowing

- `id` — the stable server id of the cached `OriginalRecipe` (integer). Keep it as provenance when you fork the recipe, and use it to match the nutrition stage's later output back to the recipe you already saved (nutrition arrives via the same `GET /recipe-imports/:id` poll — see `nutrition_status` below).
- `nutritional_information` vs `calculated_nutritional_information`: the first is **provided by the source**, the second is **calculated by the server** from the ingredient list. Keep them visibly distinct in the UI (req #6).
- `nutrition_status` enum:
  - `pending` — nutrition stage not run yet (transient; `done` arrives before nutrition finishes)
  - `computed` — all ingredients matched and quantified
  - `partial` — some ingredients matched; the rest are in `unmatched_ingredients`
  - `unavailable` — no ingredients, no `servings`, or nothing matched
- `unmatched_ingredients` — free-text ingredient names that did not match a canonical `Ingredient`; they contribute nothing to calculated nutrition.
- `categories` is always `[]` in the MVP — nothing populates it yet.

### `field_status`

A map keyed by the nine parse fields, each `"found"` or `"not_found"`:

```json
{
  "name": "found",
  "description": "not_found",
  "ingredients": "found",
  "instructions": "found",
  "preparation_time": "not_found",
  "cooking_time": "found",
  "servings": "found",
  "calories": "found",
  "nutritional_information": "not_found"
}
```

- Derived from Jev's calibrated confidence; a `not_found` field is **blanked** in the payload even if an extractor produced a value.
- This drives the review screen's 🟢/🟡 per-field indicators (req #7). `found` → 🟢, `not_found` → 🟡.

---

## 5. Import flow the mobile app implements

```
user selects URL / PDF / image
  → authenticate (verified account)
  → POST /recipe-imports
  → 202 { import_id }  ──or──  200 cached (skip polling)
  → poll GET /recipe-imports/:id until status ∈ {done, cached, failed}
  → review: show field_status 🟢/🟡, let user edit/correct
  → save: fork OriginalRecipe → local Recipe
```

The user must **always** be able to review and correct before saving (req #7). Cached imports skip straight to review.

---

## 6. What the mobile app owns (client-local, no server call)

- Recipe CRUD: create manual recipe, view, edit, delete, search, browse by category, add notes (req #2).
- Offline access to saved recipes.
- User's custom `Category`s (distinct from the server's future global `Category`s).
- The fork model: `Recipe` holds `user`, an optional `original_recipe` (provenance only, never a live dependency), and mirrors `RecipeIngredient` + `CookingInstruction` from the `OriginalRecipe` shapes in §4.

See `docs/designs/data_models.md` §"Client (mobile app — future project)" for the full client data model.

---

## 7. Not implemented (do not build against)

- `source_type: "youtube"` / video import — product requirement, **not** in the MVP server. Returns `unsupported_source_type`.
- Global `Category` tagging — the categorize stage doesn't exist yet; `original_recipe.categories` is always `[]`.
- Rate limiting on any endpoint (decision Q22).
- Refresh tokens / logout invalidation.

---

## 8. Suggested skills for the next agent

If continuing this work in an agent session, consider loading:

- `codebase-design` — for extending the deep-module seams (server vs client boundary)
- `tdd` — for building the parse/nutrition stages or mobile-side parsing test-first
- `domain-modeling` — before editing `CONTEXT.md` or recording new ADRs

(Redaction note: no secrets are included; bearer tokens, credentials, and API keys are never logged server-side — see `config/initializers/filter_parameter_logging.rb`.)
