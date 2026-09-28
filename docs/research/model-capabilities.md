# Model capabilities: DeepSeek vs Jev

Research notes for the recipe-import pipeline's two AI tiers. All claims cite their primary source. Date of research: 2026-09-28.

> **Jev source note**: the only official TypeSafe API is documented at **https://docs.typesafe.ai/api**, served from **https://api.typesafe.ai**. Other "Jev AI" sites (e.g. `jev-ai.pro`, `jevai.net`) are not official.

## DeepSeek (text generation / "non-decision output")

Source: [DeepSeek API docs — Models & Pricing](https://api-docs.deepseek.com/quick_start/pricing), [API overview](https://api-docs.deepseek.com/).

Two current models (as of research date):

| | `deepseek-flash` (DeepSeek-V4.1-Flash) | `deepseek-v4-pro` (DeepSeek-V4-Pro-0813) |
|---|---|---|
| JSON output | ✓ | ✓ |
| Tool calls | ✓ | ✓ |
| Vision | ✓ | ✗ not supported |
| Thinking mode | non-thinking + thinking (default) | non-thinking + thinking (default) |
| Context length | 1M | 1M |
| Max output | 384K | 384K |
| Input (cache miss), off-peak/peak per 1M tok | $0.15 / $0.30 | $0.66 / $1.32 |
| Output, off-peak/peak per 1M tok | $0.60 / $1.20 | $1.98 / $3.96 |
| Concurrency limit | 2500 | 500 |

- API is **OpenAI- and Anthropic-compatible** (standard SDKs work by swapping the base URL).
- Peak hours: 01:00–04:00 and 06:00–10:00 UTC, Mon–Fri (off-peak is half price; weekends fully off-peak).
- Vision on Flash means an image can go straight to the model (no separate OCR step).

## Jev via TypeSafe (decision output)

Sources: [TypeSafe API reference](https://docs.typesafe.ai/api), [Models](https://docs.typesafe.ai/models), [Quick start](https://docs.typesafe.ai/introduction/quickstart).

Jev is TypeSafe's flagship **System One model**: it **cannot generate text**. It maps unstructured input state to pre-defined, type-safe values with a calibrated confidence score.

- **Endpoint**: `POST https://api.typesafe.ai/v1/systemone`, auth `Authorization: Bearer <API_KEY>` (key from `console.typesafe.ai/keys`). `GET https://api.typesafe.ai/v1/models` lists available models.
- **Model**: `jev-latest` (alias → `jev-1.13.0`; the SDK default), or pin `jev-1.13.0`. `jev-preview` currently also points at `jev-1.13.0`.
- **Request**: `state` (required — string, object, or array), `model`, and `questions` (map of question IDs to typed questions).
- **Question types**:
  - `noul` (yes/no): optional `criteria: { true, false }`. Answer: `{ type: "noul", noul: 0..1 }` — probability of yes (no confidence field).
  - `choice`: `criteria` = map of option → description, up to 255 options. Answer: `{ type: "choice", choice, probabilities, confidence }`.
  - `score`: `criteria` = ordered array of 2–10 levels. Answer: `{ type: "score", score, legend, probabilities, confidence }`.
- **Response**: `{ model, answers: { <question_id>: {...} }, usage: { input_tokens, output_tokens } }`.
- **Pricing**: **$0.042 per 1M input tokens** ($42 per billion); **output tokens free**.
- **Rate limits**: 250,000 tokens/second and 1,200 requests/minute (both currently adjusting dynamically).
- **Context**: 64k tokens per request (32k for `state` + the longest single question).
- **Input: text only** — no image, audio, or video. Pre-process non-text inputs before sending.
- **Language**: English is the primary training language and most accurate; other languages work but should be tested.
- **Errors**: `401`, `422`, `429` (rate limit), `529` (overloaded). Retry with exponential backoff — the official SDKs do this by default.
- **SDKs**: Python `typesafe-sdk` (reads `TYPESAFE_API_KEY`) and JavaScript `@typesafe-ai/sdk`. Both default to `api.typesafe.ai`; no base-URL override needed.

## Implications for our pipeline

- **Only DeepSeek can produce recipe content** (field text, and later descriptions). Jev cannot generate anything.
- **Jev is a strong fit for the review screen's per-field status** (req #7's 🟢/🟡) and for req #4's "leave blank rather than invent": a calibrated "is cooking time present?" gate is cheap, fast, and can't invent text. Use a `noul` (or `score`) per field; note `noul` returns only the probability, so the 🟢/🟡 threshold is on `noul` directly.
- **Jev is also a fit for**: categorizing a recipe (future stage, a `choice`), routing "deterministic extraction sufficient? → call DeepSeek?", and quality gates on DeepSeek's JSON output.
- **Images must go to `deepseek-flash` via vision** — Jev is text-only, so it cannot be the image step.
- **Video** still needs transcription (YouTube captions or a speech-to-text service) before either model sees text.
- **Cost shape**: Jev is pay-as-you-go at $0.042/M input (output free), so the variable cost is dominated by DeepSeek; both are negligible per import.
