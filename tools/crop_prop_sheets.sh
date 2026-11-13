#!/bin/zsh
# Interim prop art: splits Haylee's household-prop sheets into prop-<id> imagesets (tools/crop_props.swift finds
# the white gaps). Replace with her final vectors under the same names.
cd "${0:A:h:h}"
A=PretendThat/Resources/Assets.xcassets
swift tools/crop_props.swift design/nutmeg/household-props-sheet1.webp $A stuffed-animal chair table couch pillow blanket rug cardboard-box plate cup bowl tray spoon pot towel
swift tools/crop_props.swift design/nutmeg/household-props-sheet2.webp $A laundry-basket books hat bag backpack toy-car flashlight broom teddy-bed lamp-off cushion stool sheet basket bucket
