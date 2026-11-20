# Prop art regeneration prompts (2026-11-20)

Why: when a prop's opening (a cup handle, the gaps in a chair) is drawn on a solid background, the vectorizer fills it in, so the prop shows a patch of color where the background should show through. These prompts ask for a transparent background and spell out every opening that must stay empty.

How: attach the matching `reference-*.png` from this folder, paste the prompt, and check the result before vectorizing. If ChatGPT gives a white or checkered background instead of a real transparent one, use the fallback line at the bottom.

After vectorizing in Figma, export the SVG to ~/Downloads with the prop's name (prop-cup.svg, prop-chair.svg, prop-bag.svg) and it gets copied into PretendThat/Resources/Assets.xcassets/prop-*.imageset/.

## 1. Cup (attach reference-cup.png)
Redraw the attached cup exactly: same yellow mug, same purple star on the front, same rim color, same flat vector style with soft rounded shapes and no outlines, same size and angle. Change only the handle: draw it as a real C-shaped loop with an open hole in the middle, the way a mug handle looks, so you can see right through the handle. Transparent background (a PNG with an alpha channel). The hole inside the handle must be fully transparent too, not white, not cream and not yellow. No shadow, no background, nothing else in the image.

## 2. Chair (attach reference-chair.png)
Redraw the attached wooden chair exactly: same warm brown colors, same shape, same flat vector style with soft rounded shapes and no outlines, same size and angle. Make every gap a real opening: the spaces between the back slats, the space under the seat between the four legs, and the gaps between the legs and their crossbars must all show straight through the chair. Transparent background (a PNG with an alpha channel). Every one of those gaps must be fully transparent too, not filled with brown, white or any other color. No floor, no shadow, nothing else in the image.

## 3. Bag (optional; attach reference-bag.png)
The bag fixed in Figma on 2026-11-20 lost its front straps and its bottom band (the lighter purple paths were deleted with the beige fill), so it wasn't imported. Either repair that file (keep the lighter purple strap and bottom-band paths, delete only the cream shape between the handles) or regenerate:

Redraw the attached tote bag exactly: same cream bag body, same yellow star on the front, same purple straps running down the front of the bag, same purple band along the bottom, same flat vector style with soft rounded shapes and no outlines, same size and angle. The two handles arch up over the top; the space inside each handle arch, between the handles and the top of the bag, must be a real opening you can see through. Transparent background (a PNG with an alpha channel). The openings inside the handles must be fully transparent too, not cream and not white. No shadow, nothing else in the image.

## Fallback when transparency doesn't come through
Replace the "Transparent background" sentences with: "Solid flat bright green background #00C853 everywhere around the object AND inside every opening (the same green must show through the handle hole / the gaps), nothing else in the image." The green makes any filled-in opening obvious, and it's easy to remove in Figma.
