# FEATURE: Engineer Mode — Cooking for Engineers table view (easter egg)

**Status:** Filed 2026-08-04. Not started. Priority: post-App-Store-blockers (delighter, not a gate).

## Concept
Hidden alternate recipe view rendering the recipe as a Chu-style nested table
(rows = ingredients, columns = merged actions, read left to right). Inspired by
cookingforengineers.com format, viral July 2026 (Fast Company 91582535).

## Unlock
TBD — leaning triple-tap recipe title, toast "Engineer Mode" on first discovery.
Persists as toggle after discovery. Zero UI surface pre-discovery (no settings
entry until unlocked).

## Slices
1. **Renderer:** tree JSON → table layout. Canvas/ZStack with computed frames
   (no Grid rowspan). Cap ~5 merge columns on iPhone, horizontal scroll fallback.
2. **Parse pipeline:** prose recipe → tree JSON via fluffylist-proxy
   (structured output). Lazy: parse on first unlock per recipe, never blocks
   import. Cache tree in Supabase alongside recipe.
3. **Fallbacks:** parse failure or non-tree recipe → silently no egg for that
   recipe. Multi-component recipes → one table per component (Chu's
   cake+frosting solution).

## Tree schema (v1)
```json
{
  "version": 1,
  "recipe_id": "uuid",
  "components": [
    {
      "name": "Banana bread",
      "nodes": [
        {"id": "i1", "kind": "ingredient", "label": "4 oz butter"},
        {"id": "s1", "kind": "step", "action": "melt", "inputs": ["i1"]},
        {"id": "s6", "kind": "step", "action": "bake 350F", "duration_min": 60, "inputs": ["s5"]}
      ],
      "root": "s6"
    }
  ]
}
```
Rendering rules: row-span = ingredient leaves beneath node; column = depth order
leaf→root; ingredient row order = depth-first leaf order. Parse constraint: LLM
must pick a leaf order where every step's inputs are contiguous — that's what
makes the table renderable.

Validation before caching: every node referenced exactly once except root, no
cycles, contiguity check passes. Any failure → don't cache, no egg.

## Constraints
- NO deep teal in table palette (standing design rule).
- Parse burns proxy quota only on first unlock per recipe (lazy).
