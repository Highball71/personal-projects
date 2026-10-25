# October 25 correction pass

Recipes first: preserve scanned source image, distinguish source pages from family dish photos, restore mockup proportions and inline detail actions. Validate phone/tablet and appearance states before delivery.

Next: investigate duplicate grocery items and section headings such as “[For the Pork] _______”. Headings must not become purchasable items. Determine origin and merge semantics before touching existing quantities or meal-plan links. Do not delete household groceries as cleanup.

Source model currently holds one original page per recipe. Multi-page extraction reads all pages; this pass preserves the first page and labels that limit. Existing originals must not be silently replaced.

Read-only live findings Oct 25: 19 heading/prefix rows, including standalone “For the Filling” (1 piece) and real ingredients prefixed “[For the Pork]” / “[For the Slaw]”. Five exact duplicate groups found, including three extra-virgin olive oil rows. Existing service only chooses first legacy duplicate, and section prefixes prevent matching. No cleanup applied; units and meal-plan contributions must be preserved. Build 127 contains recipe corrections and new optional cookbook-photo flow, not grocery cleanup.
