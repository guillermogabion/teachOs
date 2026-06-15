from PIL import Image

# ─── CONFIG ───────────────────────────────────────────────────────────────────
INPUT  = "assets/icon/teachOs_logo.png"   # your original logo
OUTPUT = "assets/icon/teachOs_logo_small.png"

# Android 12 adaptive icon safe zone = 66/108 ≈ 61% of canvas
# We use 40% so the logo has generous breathing room and won't be sliced
CANVAS   = 1080   # large canvas = crisp on all densities
LOGO_PCT = 0.38   # logo occupies 38% of canvas width — tweak this if needed
# ──────────────────────────────────────────────────────────────────────────────

logo_px = int(CANVAS * LOGO_PCT)

logo = Image.open(INPUT).convert("RGBA")
logo = logo.resize((logo_px, logo_px), Image.LANCZOS)

canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
offset = (CANVAS - logo_px) // 2
canvas.paste(logo, (offset, offset), logo)

canvas.save(OUTPUT, "PNG")
print(f"✅  Saved {OUTPUT}  ({CANVAS}x{CANVAS} canvas, logo at {logo_px}x{logo_px}px)")
print(f"    To make the logo bigger, increase LOGO_PCT (e.g. 0.45)")
print(f"    To make it smaller,      decrease LOGO_PCT (e.g. 0.30)")