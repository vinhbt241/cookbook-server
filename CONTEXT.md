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
A canonical, globally-shared food reference. The intended foundation for future per-recipe nutrition calculation.
_Avoid_: food, item, component

**Category**:
A classification for recipes. Global categories apply to `OriginalRecipe`s (server-side); users can also create their own categories for their `Recipe`s (mobile app).
_Avoid_: tag, label, type
