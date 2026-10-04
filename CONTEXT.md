# Cookbook Server

The server-side service for the Cookbook app. It authenticates users and parses external recipe sources into reusable `OriginalRecipe`s. It does **not** store users' saved recipes — those live in the mobile app, a separate project built later.

## Language

**OriginalRecipe**:
A recipe parsed from an external `Source`, stored server-side as a global shared cache keyed by a source identifier. When any user imports the same `Source`, the cached `OriginalRecipe` is reused and copied into that user's own `Recipe`.
_Avoid_: parsed recipe, extracted recipe, cached recipe

**Recipe**:
A user's saved recipe — a fork of an `OriginalRecipe` that the user owns and edits freely. Lives in the mobile app, not on the server.
_Avoid_: saved recipe, cookbook entry, user recipe

**Source**:
An external resource a recipe is imported from: web page, PDF, image, or video.
_Avoid_: resource, input, link, URL

**Import**:
The end-to-end flow: a user provides a `Source`, the server parses it into an `OriginalRecipe`, and the user reviews and saves the result.
_Avoid_: parse, extract

**Parse**:
The server's act of converting a `Source` into an `OriginalRecipe`.
_Avoid_: extract, analyze, scrape

**Gate**:
The step in Parse where Jev judges which recipe fields are present in the Source; a field judged absent is blanked before the OriginalRecipe is built.
_Avoid_: filter, validate, check

**Review**:
The step where a user inspects and corrects a parsed recipe before saving it.
_Avoid_: preview, confirm

**Save**:
Persisting a `Recipe` on the user's device, forked from an `OriginalRecipe`.
_Avoid_: store, persist

**Cookbook**:
A user's collection of saved `Recipe`s.
_Avoid_: recipe list, library

**Ingredient**:
A canonical, globally-shared food reference. Carries per-100g nutrition data and a curated map of how much a common unit weighs, and is the basis for a recipe's CalculatedNutrition.
_Avoid_: food, item, component

**CalculatedNutrition**:
Nutrition derived from an OriginalRecipe's ingredients (via the canonical Ingredient reference), as opposed to nutrition provided by the Source. The two are kept separate.
_Avoid_: estimated nutrition, computed nutrition, derived nutrition

**Match**:
Resolving a free-text ingredient name to a canonical Ingredient. An ingredient that does not Match contributes nothing to CalculatedNutrition and is reported as such.
_Avoid_: normalize, link, map

**Category**:
A classification for recipes. Global categories apply to `OriginalRecipe`s (server-side); users can also create their own categories for their `Recipe`s (mobile app).
_Avoid_: tag, label, type

**User**:
The server's authentication identity: an account, identified by email, that can sign in and import recipes. Owns no recipes server-side — a `User`'s `Recipe`s and `Cookbook` live in the mobile app. A `User` may hold the Admin role.
_Avoid_: account, customer, member

**Admin**:
A `User` whose role grants access to the server's admin dashboard, for curating `Ingredient`s, moderating `OriginalRecipe`s, and monitoring `RecipeImport`s.
_Avoid_: moderator, superuser, staff, operator

**Curate**:
Admin maintenance of the canonical `Ingredient` reference — creating, editing, or deactivating `Ingredient`s so future `Match`es use correct data.
_Avoid_: manage, maintain, edit

**Moderate**:
Admin correction of a cached `OriginalRecipe`: editing its fields directly, or `Re-parse`-ing the `Source` when the whole parse is wrong.
_Avoid_: edit, fix, review

**Re-parse**:
The admin action that forces a `Source`'s cached `OriginalRecipe` to be re-extracted in place, overwriting the previous parse while keeping its history.
_Avoid_: invalidate, refresh, re-extract

**Deactivate**:
Removing an `Ingredient` from future `Match`es by flagging it inactive, without deleting it or breaking historical references.
_Avoid_: delete, remove, disable
