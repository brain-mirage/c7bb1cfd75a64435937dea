"""Generate native-color grass alpha cuts using tile-43 as the ground reference."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source"
ART = ROOT.parent / "art"


def cut_grass(tile_name: str, output_name: str) -> None:
    """Keep native RGB; make pixels identical to tile-43 transparent."""
    with Image.open(SOURCE / "tile-43.png") as ref_image:
        reference = ref_image.convert("RGBA")
    with Image.open(SOURCE / tile_name) as source_image:
        native = source_image.convert("RGBA")

    if native.size != reference.size:
        raise ValueError(f"Dimension mismatch: {tile_name} {native.size} vs tile-43 {reference.size}")

    result = Image.new("RGBA", native.size)
    src = native.load()
    ref = reference.load()
    dst = result.load()
    for y in range(native.height):
        for x in range(native.width):
            r, g, b, alpha = src[x, y]
            if src[x, y] == ref[x, y]:
                alpha = 0
            dst[x, y] = (r, g, b, alpha)

    ART.mkdir(parents=True, exist_ok=True)
    result.save(ART / output_name, format="PNG")


if __name__ == "__main__":
    cut_grass("tile-65.png", "grass65.png")
    cut_grass("tile-66.png", "grass66.png")
