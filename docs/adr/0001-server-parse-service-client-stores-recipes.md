# The server is a parse + auth service; user recipes live in the mobile app

The Cookbook server (this repo) stores only the shared `OriginalRecipe` cache, auth accounts, and global reference data (`Ingredient`, `Category`). Users' saved `Recipe`s are forks of `OriginalRecipe`s and live in a separate mobile app, which is the offline-capable store of record. The server never persists a user's cookbook.

**Considered options**: a server-backed cookbook (Postgres storing every user's recipes, with "local" meaning "the user's own collection") was rejected because the requirements demand offline access and auth-free recipe CRUD — only a client-local store satisfies both. The fork model follows from the same constraint: a saved recipe can't be a live reference to the server because it must be editable offline.
