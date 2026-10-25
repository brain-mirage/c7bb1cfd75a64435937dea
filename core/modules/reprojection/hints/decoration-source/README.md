# Cloud 1 run 53 decoration inputs

Native alpha-cut overrides for the G64 second drawing layer. The original pack files are unchanged. Each picture uses a shared four-triangle crossed shape; its fine detail stays in these native pixels.

## Provenance

Authoritative native PNG exports, copied byte-for-byte into source/:

- G:/Nexus/work/s6-reprojection-cloud-1/owner-feedback/food-and-flowers-native/stalls-ground/tiles/tile-43.png — reference ground tile.
- G:/Nexus/work/s6-reprojection-cloud-1/owner-feedback/food-and-flowers-native/stalls-ground/tiles/tile-65.png — source for ../art/grass65.png.
- G:/Nexus/work/s6-reprojection-cloud-1/owner-feedback/food-and-flowers-native/stalls-ground/tiles/tile-66.png — source for ../art/grass66.png.

make-grass.py regenerates the outputs from the three copied inputs. It retains each source pixel's RGB and alpha, setting alpha to zero only where the source RGBA equals tile 43 RGBA.

## Comparison and alpha bounds

Coordinates use (left, top, right, bottom) with right/bottom exclusive; bounds enclose nonzero output alpha.

| Output | Pixels differing from tile 43 | Nonzero alpha bounds |
|---|---:|---|
| ../art/grass65.png | 313 | (5, 13, 48, 41) |
| ../art/grass66.png | 102 | (12, 28, 35, 43) |

## SHA-256

| File | SHA-256 |
|---|---|
| source/tile-43.png | f3c5a1e5419b22c35f9c51189f5b31a6936497364f1793011362da83485cd26e |
| source/tile-65.png | be67895963e80f7e1d1f9c6ef2484a9b14ad77c35398f59ab8afdb63296f21f5 |
| source/tile-66.png | f039feafab8720917ffd0c3e7bed348900eb107d8753a1ef6a622fa396f59a64 |
| ../art/grass65.png | 18968387c372052afcf7f973921b06d61b9521fefc74030af4e04686be31f52b |
| ../art/grass66.png | 334e1267bd040d75186ed79a7dadb9db83cb9ca516565ad7902f8cac6ae490b1 |

Run `python make-grass.py` with Pillow installed to regenerate the runtime PNGs in `../art/`. The native inputs were exported through Source-6 AssetCatalog.GroundImage.
