# Server APIs

The server is a thin **parse + auth** service (see `docs/adr/0001-*.md`). Recipe CRUD is client-local in the mobile app and has **no server endpoint**.

## Authentication

### POST /auth/google

Sign in or create an account using a Google ID token (one-tap credential exchange; no server callback).

Request:
- Google ID token

Response:
- User information
- Session token

### POST /auth/register

Create a new account using email, name, and password.

Request:
- email, name, password

Behavior:
- Create the account (unconfirmed)
- Send confirmation email
- Account remains unconfirmed until email verification

Response:
- User information
- Account status

### GET /auth/confirm/:token

Confirm an email address using the token sent in the registration email.

Request:
- Confirmation token (in the path, from the email link)

Behavior:
- Marks the account confirmed

Response:
- User information (with confirmed status)

### POST /auth/login

Authenticate an existing email/password account.

Request:
- email, password

Response:
- User information
- Session token

### GET /auth/me

Return the currently authenticated user.

Response:
- User information

**Import requires a confirmed account.** An unconfirmed account cannot call `/recipe-imports`.

## Recipe Import (async)

### POST /recipe-imports

Parse a recipe from an external resource. Requires a verified account.

Request:
- `resource` + `resource_type`:
  - `web_page` / `youtube` → `resource` is a URL string
  - `pdf` / `image` → `resource` is an uploaded file (multipart)

Behavior:
1. Compute `source_identifier` (URL / video ID / content hash).
2. Look up the global `OriginalRecipe` cache. On a hit, return the cached recipe immediately.
3. On a miss, enqueue a parse job (deterministic extraction → DeepSeek structuring → Jev presence/quality gates) and return 202.

Response:
- `202 { "import_id": "...", "status": "processing" }`
- Or, on a cache hit, the parsed recipe inline: `{ "status": "cached", "original_recipe": {...}, "field_status": {...} }`

### GET /recipe-imports/:id

Poll a parse job. Requires a verified account.

Response:
- `{ "status": "processing" }` — poll again
- `{ "status": "done" | "cached", "original_recipe": {...}, "field_status": {...} }`
- `{ "status": "failed", "error": "...", "error_code": "...", "retryable": true|false, "retry_count": 1, "retries_remaining": 2 }` — rare; partial results are preserved where possible (req #9)

### POST /recipe-imports/:id/retry

Re-run a failed import in place. Requires a verified account.

Response:
- `202 { "import_id": "...", "status": "processing" }`
- Or, on a cache hit, the parsed recipe inline with `status: "cached"` (no retry is consumed)
- `404` unknown import
- `409 { "error": "import is not failed" | "retry limit reached" }`

`original_recipe` fields:
- `name`, `description`, `ingredients` (free text), `instructions` (ordered), `preparation_time`, `cooking_time`, `servings`, `calories`, `nutritional_information` (source-provided only), `original_source`, `source_identifier`, `categories` (empty in MVP)

`field_status`: per field, `"found"` or `"not_found"` — derived from Jev's calibrated confidence and rendered as 🟢/🟡 on the review screen (req #7).

## Authentication requirements

| Operation | Auth |
|---|---|
| View / create / edit / delete / search recipes | Client-local — no server call |
| `POST /recipe-imports`, `GET /recipe-imports/:id` | Verified account required |

No rate limiting in MVP (decision Q22).

## User flows

### Manual recipe

User → Create recipe → Save locally (no server involvement).

### Import recipe

User → select URL / PDF / Image / YouTube
→ authenticate (verified)
→ `POST /recipe-imports` → `202 { import_id }`
→ poll `GET /recipe-imports/:id` until `done`
→ review (edit fields, correct 🟡/not-found)
→ save locally as a fork

### Import a previously parsed resource

User → select resource → authenticate → `POST /recipe-imports`
→ cache hit → parsed recipe returned immediately (`status: cached`)
→ review → save locally
