# FluffyList Beta — Phase 2: Homemade Photos (V1)

## Goal

Allow a user to add a homemade photo to a recipe after making it. The cookbook/source image remains primary. The homemade photo appears only as a secondary element in the recipe detail screen.

This is a minimal, safe implementation: no animation, no transition effects, no card/grid redesign, no prompts outside recipe detail.

## Product Rules

- Source/cookbook image is **always primary** — in recipe cards, in the recipe detail hero, everywhere.
- Homemade photo is **secondary** and appears **only in recipe detail** for this phase.
- Homemade photos must not take over recipe cards, the hero image, or any other surface.
- No user preference for image priority in this phase.

## Scope

### Build

1. `RecipeCardImage` preference parameter so callers control which image path is displayed
2. Secondary homemade photo block in recipe detail (below the hero)
3. "Made this? Add your photo" prompt in recipe detail when no homemade photo exists
4. Upload flow wired to existing `RecipeService.uploadHomemadeImage()` and `setHomemadeImagePath()`
5. Refresh/update behavior after successful upload

### Do Not Build

- Image transitions or animation effects
- Source/homemade switching or looping
- User preference for image priority
- Photo galleries
- Prompts outside recipe detail (no cards, no meal plan, no grocery)
- Recipe card/grid redesign
- Changes to scan/import flow, recipe extraction, meal plan logic, or grocery logic

## Existing Infrastructure (Already Built)

The following already exist and will be reused without modification:

| Component | File | What It Does |
|---|---|---|
| DB column | `supabase/migrations/007_recipe_images.sql` | `homemade_image_path text` on `recipes` table |
| Model field | `SupabaseModels.swift` | `RecipeRow.homemadeImagePath: String?` |
| Upload function | `RecipeService.swift` | `uploadHomemadeImage(_:recipeID:)` — resize to 1200px, JPEG 0.8, upload to `{household}/{recipe}/homemade.jpg` |
| Path setter | `RecipeService.swift` | `setHomemadeImagePath(_:recipeID:)` — updates the DB column |
| PhotosPicker | `SupabaseRecipeDetailView.swift` | `showingHomemadePhotoPicker`, `homemadePhotoItem`, picker modifier, `onChange` handler |
| Upload orchestration | `SupabaseRecipeDetailView.swift` | `uploadHomemadePhoto(_:)` — calls upload, sets path, fetches recipes, shows toast |
| Loading overlay | `SupabaseRecipeDetailView.swift` | `uploadingOverlay` — shows "Saving photo..." during upload |
| Storage URL builder | `SupabaseManager.swift` | `publicStorageURL(path:bucket:)` — builds public URL for `recipe-images` bucket |

No new service methods, model fields, or migrations are needed.

## File Changes

### 1. RecipeCardImage.swift

**What changes:** Add an `ImagePreference` enum and a `preference` parameter.

**Current behavior:** `displayImagePath` returns `homemadeImagePath ?? sourceImagePath` — homemade wins.

**New behavior:**

```swift
enum ImagePreference {
    case source
    case homemade
}
```

Add `preference` parameter with default value `.source`:

```swift
let preference: ImagePreference

init(recipe: RecipeRow, height: CGFloat, preference: ImagePreference = .source) {
    self.recipe = recipe
    self.height = height
    self.preference = preference
}
```

Change `displayImagePath`:

```swift
private var displayImagePath: String? {
    switch preference {
    case .source:
        recipe.sourceImagePath ?? recipe.homemadeImagePath
    case .homemade:
        recipe.homemadeImagePath ?? recipe.sourceImagePath
    }
}
```

**Effect on existing call sites:**

| Call Site | File | Current Call | After Change |
|---|---|---|---|
| Hero image | `SupabaseRecipeDetailView.swift:58` | `RecipeCardImage(recipe: recipe, height: 220)` | No change needed — default `.source` |
| Hero card | `SupabaseRecipeListView.swift:280` | `RecipeCardImage(recipe: recipe, height: 200)` | No change needed — default `.source` |
| Grid card | `SupabaseRecipeListView.swift:321` | `RecipeCardImage(recipe: recipe, height: 120)` | No change needed — default `.source` |
| Recently Added | `SupabaseRecipeListView.swift:362` | `RecipeCardImage(recipe: recipe, height: 90)` | No change needed — default `.source` |

All existing call sites get `.source` by default. Recipe cards and the hero image continue showing the source/cookbook image. No behavioral change at any existing call site.

### 2. SupabaseRecipeDetailView.swift

**What changes:** Add a secondary homemade photo block below the hero image. Reposition the existing prompt.

**Layout (top of ScrollView VStack):**

```
┌─────────────────────────────┐
│  Hero Image (source, 220px) │  ← RecipeCardImage, preference: .source (default)
└─────────────────────────────┘

If homemade photo EXISTS:
┌─────────────────────────────┐
│  "Your Photo" label         │
│  ┌───────────────────────┐  │
│  │  Homemade image       │  │  ← RecipeCardImage, preference: .homemade, height: 160
│  │  (rounded, 160px)     │  │     Tappable — triggers picker to replace photo
│  └───────────────────────┘  │
└─────────────────────────────┘

If homemade photo DOES NOT EXIST:
┌─────────────────────────────┐
│  📷 Made this? Add your     │  ← existing homemadePhotoPrompt (tappable)
│     photo                   │
└─────────────────────────────┘

Title section
Metadata row
...
```

**New view: `homemadePhotoBlock`**

Shown when `recipe.homemadeImagePath != nil`. Contains:

- "Your Photo" label — `fluffyCaption`, `fluffySecondary` color, left-aligned
- `RecipeCardImage(recipe: recipe, height: 160, preference: .homemade)` — with rounded corners (12pt) and `clipShape`
- Tapping the image triggers the same `showingHomemadePhotoPicker` to allow replacing the photo (the upload uses `upsert: true`, so the storage file is overwritten)
- Horizontal padding matching the rest of the detail screen (20pt)
- Vertical spacing: 16pt above, 8pt between label and image

**Body change (lines 56-65):**

Replace the current block:

```swift
// Source image hero
if recipe.sourceImagePath != nil || recipe.homemadeImagePath != nil {
    RecipeCardImage(recipe: recipe, height: 220)
        .clipped()
}

// Secondary homemade photo OR prompt
if recipe.homemadeImagePath != nil {
    homemadePhotoBlock
} else {
    homemadePhotoPrompt
}
```

The hero image condition stays the same — it shows whenever any image exists, using the default `.source` preference. Below it, we show either the secondary homemade block or the upload prompt.

**Existing `homemadePhotoPrompt`:** No changes. Already shows "Made this? Add your photo" with camera icon, triggers `showingHomemadePhotoPicker`.

**Toast error support:** Add an `@State private var isErrorToast = false` bool. In `toastOverlay`, use this to switch between:
- Success: `checkmark.circle.fill` with `fluffySuccess` (existing behavior)
- Error: `xmark.circle.fill` with `fluffyError`

**Upload flow change:** In `uploadHomemadePhoto(_:)`, when `uploadHomemadeImage()` returns `nil`, set the error toast:

```swift
guard let path = await recipeService.uploadHomemadeImage(image, recipeID: recipe.id) else {
    isErrorToast = true
    withAnimation { toastMessage = "Photo could not be saved" }
    return
}
```

On success, ensure `isErrorToast = false` before showing the success toast (existing behavior).

### 3. No Other Files Change

- `SupabaseRecipeListView.swift` — untouched (default `.source` preference)
- `RecipeService.swift` — untouched (upload/setter methods already exist)
- `SupabaseModels.swift` — untouched (`homemadeImagePath` field already exists)
- `SupabaseManager.swift` — untouched (`publicStorageURL` already works)
- `SupabaseAddRecipeView.swift` — untouched
- Scan/import flow — untouched
- Meal plan logic — untouched
- Grocery logic — untouched

## Failure Behavior

### Upload fails (network error, storage error)

- `uploadHomemadeImage()` returns `nil`
- `uploadHomemadePhoto()` skips `setHomemadeImagePath()` and `fetchRecipes()`
- `isUploadingHomemade` is cleared by `defer`
- Loading overlay disappears
- Recipe row is unchanged — no `homemade_image_path` set
- Source image is unchanged
- Error toast shown: "Photo could not be saved" (uses existing `toastMessage` with error icon)
- UI returns to previous state: hero image + "Made this?" prompt (or existing homemade photo if replacing)

### JPEG compression fails

- `uploadHomemadeImage()` returns `nil` before any network call
- Same result as upload failure above

### No household ID

- `uploadHomemadeImage()` returns `nil` immediately
- Same result as above

### PhotosPicker returns no data

- `loadTransferable` returns `nil` or throws
- `uploadHomemadePhoto()` is never called
- No state changes

### In all failure cases

- Recipe row is unchanged
- Source image is unchanged
- No partial/broken UI state
- User can retry by tapping the prompt again

## Supabase Migration

**None required.** The `homemade_image_path` column was added in migration 007. The `recipe-images` storage bucket already exists. No new RLS policies are needed — the existing recipe update policy covers writing `homemade_image_path`.

## Testing Plan

1. **No homemade photo:** Open recipe detail for a recipe with only a source image. Verify hero shows source image. Verify "Made this? Add your photo" prompt appears below hero.
2. **Add homemade photo:** Tap prompt, select photo from library. Verify loading overlay appears. Verify toast "Photo added" appears. Verify secondary "Your Photo" block appears below hero. Verify hero still shows source image.
3. **Recipe with homemade photo (return visit):** Navigate away and back to recipe detail. Verify hero shows source image. Verify secondary block shows homemade photo.
4. **Recipe cards unchanged:** Browse recipe list. Verify all cards show source images (no homemade photos on cards).
5. **No source image, no homemade:** Recipe with no images. Verify gradient fallback in hero. Verify "Made this?" prompt appears.
6. **Upload failure:** Test with airplane mode. Verify recipe is unchanged after failure. Verify no broken UI.
7. **Replace homemade photo:** Add a homemade photo to a recipe that already has one. Verify upsert overwrites the old file. Verify new photo appears in secondary block.
