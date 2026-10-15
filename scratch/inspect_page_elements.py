import pymupdf

doc = pymupdf.open(r'C:\Users\ravim\.gemini\antigravity-ide\brain\a2e3f22c-63d8-4684-809b-8678339211c6\.user_uploaded\media_1791619577167.pdf')
p1 = doc[0]

# Check drawings on Page 1
drawings = p1.get_drawings()
with open(r'c:\rearticle_app\scratch\drawings_info.txt', 'w', encoding='utf-8') as f:
    f.write(f"Page 1 drawings count: {len(drawings)}\n")
    for i, page in enumerate(doc):
        f.write(f"\n--- PAGE {i+1} BLOCKS & FONTS ---\n")
        blocks = page.get_text("dict")["blocks"]
        for b in blocks:
            if "lines" in b:
                for line in b["lines"]:
                    for span in line["spans"]:
                        f.write(f"Text: '{span['text']}' | Font: {span['font']} | Size: {span['size']:.1f} | Color: {hex(span['color'])} | BBox: {[round(x,1) for x in span['bbox']]}\n")

print("Inspection complete!")
