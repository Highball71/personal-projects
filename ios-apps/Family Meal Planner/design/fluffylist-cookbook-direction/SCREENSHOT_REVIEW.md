# Screenshot review: current FluffyList screens

This review is based on the real iPhone screenshots shared in the design conversation. It records what is already working, what the screenshots reveal, and a restrained implementation order for the cookbook direction.

## What the screenshots confirm

### Grocery: fix the bottom content obstruction first

In both light and dark grocery screenshots, the floating tab bar sits over the scrolling list. In the dark screenshot it visibly obscures the next grocery row; the light screenshot shows content continuing faintly behind the translucent bar. A shopper should be able to reach and check every item without the navigation covering it.

Investigate the grocery screen's bottom safe-area/inset handling and the shared tab bar container. Give scroll content enough bottom clearance for the full bar and device safe area. Keep the current grocery typography and row layout while fixing this. Check the final rows at the actual bottom of a long list, in both appearances.

### Grocery: avocado prep text is duplicated

The avocado row shows two near-duplicate preparation notes joined together: “split lengthwise, pitted, peeled, and diced” and “split lengthwise, pitted, peeled, and cut into large dice.” This is a specific data/aggregation or presentation defect visible in the screenshot. Trace where both notes enter the grocery list before deciding whether to deduplicate at the recipe source, grocery aggregation, or display layer. Avoid discarding meaningful ingredient data as a shortcut.

### Meals: preserve the useful structure

The current week screen is already clear and warm. The week label, planned/open-night summary, green emphasis for today, recipe title, and simple open-night rows make the screen easy to scan. Keep those strengths. The lower scroll also shows useful seasonal guidance and direct actions to copy last week's meals or build the grocery list; keep these grounded features.

The concept mockup's editorial flourishes and invented example content are exploration only. Do not add fabricated quotes, meals, dates, counts, or household details to the live app. Avoid adding a large decorative week ribbon unless it solves a real navigation problem.

### Recipes: make it feel like a family cookbook, not a promotion

The recipe screenshots show a useful mix of real dish photos and photographs of cookbook pages. Keep the library/list-first browsing experience as the foundation. The large food-photo hero treatment reads like merchandising and risks the “grocery store ad” reaction the family already identified.

Treat user media according to what it is: a finished-dish or family photo may work as a dish image; a cookbook-page photo is source material and should remain legible as a document, especially in recipe detail. Do not turn glare-prone cookbook scans into full-bleed hero images, and do not use generated food imagery to imply a dish photo exists. Where there is no genuine dish image, use a quiet, intentional source/document treatment rather than a conspicuous empty placeholder.

The category browsing and recently-added shelf can remain if they help discovery without pushing the actual recipe box down or crowding the first screen. Preserve useful metadata such as meal type and cooking time.

## Recommended order

1. Correct the grocery list's bottom inset so every item is unobstructed in light and dark appearance.
2. Trace and resolve the duplicated avocado preparation note at the correct layer.
3. Make only a small recipe-browsing refinement around the distinction between dish photos and cookbook-page scans. Keep the list-first hierarchy.
4. Revisit larger visual changes only after comparing the result against these real screens and real household content.

## Design guardrails

- Preserve the warm paper-like light appearance, confident cookbook typography, restrained green accents, and clear dividers.
- Keep dark appearance genuinely comfortable and readable; do not solve it by changing background colors alone.
- Preserve real user data and media. Mockup content is not production content.
- Judge screens at the phone size shown here, including the bottom navigation and the last rows of long lists.
