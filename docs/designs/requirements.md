## 1. Purpose

The app allows users to **save, organize, and access cooking recipes in one place**, including recipes collected from websites, videos, PDFs, and images.

The app should reduce the effort required to turn a recipe found online or elsewhere into a **clean, usable recipe that the user can actually cook from**.

---

## 2. Recipe Management

Users should be able to:

- Create a recipe manually.
- View a recipe.
- Edit a recipe.
- Delete a recipe.
- Search for recipes.
- Browse recipes by category.
- Add personal notes to a recipe.
- Access saved recipes without an internet connection.

Each recipe should contain, where available:

- Recipe name
- Description
- Category
    - Appetizer
    - Side dish
    - Main course
    - Dessert
    - Soup
    - Salad
    - Breakfast
    - etc.
- Ingredients
- Cooking instructions
- Preparation time
- Cooking time
- Servings
- Calories
- Nutritional information
- Personal notes
- Original source

---

# 3. Recipe Import

Users should be able to provide a recipe source and have the app convert it into a recipe.

Supported sources:

- Web pages
- PDF documents
- Images/photos
- Videos
- Youtube Video

> Note: video/YouTube import is a product requirement but is **not implemented** in the MVP server yet. The server currently parses `web_page`, `image`, and `pdf` sources only (see `docs/api.md`).

### User flow

1. User provides a recipe source.
2. App analyzes the source.
3. App identifies the recipe information.
4. App presents the extracted recipe to the user.
5. User reviews and corrects the information if necessary.
6. User saves the recipe to their cookbook.

The user should **always have an opportunity to review the imported recipe before saving it**.

---

# 4. Recipe Information Extraction

When importing a recipe, the app should attempt to identify:

- Recipe name
- Description
- Category
- Ingredients
- Quantities and units
- Preparation instructions
- Preparation time
- Cooking time
- Servings
- Calories
- Nutritional information

If the source does not contain certain information, the app should leave it blank rather than inventing information.

For example:

> A recipe contains ingredients and instructions but doesn't mention preparation time.

The imported recipe should simply have:

> Preparation time: Not specified

rather than presenting an estimated time as fact.

---

# 5. Recipe Description

If a recipe doesn't have a clear description, the app may generate a short description based on the recipe.

For example:

> **Original:**  
> "This is my family's favorite chicken curry..."

Could become:

> **Description:**  
> "A rich and aromatic chicken curry made with coconut milk and warming spices."

The generated description should remain concise and relevant to the recipe.

---

# 6. Nutrition

The app should support nutritional information when it is available.

This includes, where possible:

- Calories
- Protein
- Carbohydrates
- Fat
- Fiber
- Sugar
- Sodium

For the MVP, nutrition can come from:

1. Information provided by the original recipe, or
2. Information calculated from the ingredients.

The app should clearly distinguish between **nutrition provided by the source** and **nutrition estimated/calculated by the app**.

---

# 7. Import Review

Before saving an imported recipe, users should see a review screen.

Example:

> **Chicken Tikka Masala**
> 
> 🟢 Name — Found  
> 🟢 Ingredients — Found  
> 🟢 Instructions — Found  
> 🟢 Cooking time — Found  
> 🟡 Preparation time — Not found  
> 🟢 Servings — Found
> 
> **[Edit Recipe] [Save Recipe]**

This allows users to quickly catch extraction mistakes.

---

# 8. Import Pipeline — Business Requirement

The recipe-import process should be **modular from a product perspective**.

The app should be able to add or remove processing capabilities without changing how users interact with the overall import experience.

For example, the app may initially support:

> Source → Extract recipe → Review → Save

Later, it could introduce additional capabilities such as:

> Source → Extract recipe → Improve description → Calculate nutrition → Categorize recipe → Review → Save

The addition of these capabilities should not require redesigning the core user workflow.

---

# 9. Error Handling

The app should gracefully handle sources where information cannot be extracted.

Examples:

- Unsupported website
- Poor-quality image
- Video with unclear speech
- Recipe information missing
- PDF containing scanned pages
- Recipe is incomplete

Instead of failing the entire import, the app should preserve whatever information it can extract.

For example:

> **We couldn't identify the cooking time. You can add it manually.**

---

# 10. MVP Success Criteria

The MVP should make this workflow easy:

> **Find recipe → Give it to Cookbook → Review → Save → Cook**

A successful import should ideally require **little or no manual data entry**.

The most important product metric isn't how sophisticated the extraction process is; it's:

> **How often can a user turn a recipe from an external source into a usable saved recipe with minimal correction?**

## 11. Optimize
- When import a recipe, if the URLs already existed. We should copy the recipe from original extract recipe, to avoid additional performance overhead.
