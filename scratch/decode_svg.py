import re
import base64

svg_path = r"c:\rearticle_app\lib\screens\profilelogo.svg"
png_path = r"c:\rearticle_app\assets\images\profilelogo.png"

with open(svg_path, "r", encoding="utf-8") as f:
    content = f.read()

# Find the base64 image data
match = re.search(r'xlink:href="data:image/png;base64,([^"]+)"', content)
if not match:
    # Also try without xlink:href (standard href)
    match = re.search(r'href="data:image/png;base64,([^"]+)"', content)

if match:
    base64_data = match.group(1)
    # Decode and write to png
    image_bytes = base64.b64decode(base64_data)
    with open(png_path, "wb") as f:
        f.write(image_bytes)
    print("Successfully decoded SVG base64 to PNG!")
else:
    print("Could not find base64 data in SVG.")
