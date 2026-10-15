import pymupdf

doc = pymupdf.open(r'C:\Users\ravim\.gemini\antigravity-ide\brain\a2e3f22c-63d8-4684-809b-8678339211c6\.user_uploaded\media_1791619577167.pdf')

for page_num in range(len(doc)):
    page = doc[page_num]
    
    # Redact all text on the page to leave only the background graphics/drawings
    text_instances = []
    # Search common words or get all text rects
    blocks = page.get_text("dict")["blocks"]
    for b in blocks:
        if "lines" in b:
            for line in b["lines"]:
                for span in line["spans"]:
                    text_instances.append(pymupdf.Rect(span["bbox"]))
    
    for r in text_instances:
        # Add white fill redaction
        page.add_redact_annot(r, fill=(1, 1, 1))
    page.apply_redactions()
    
    # Save high-res 300 DPI background
    pix = page.get_pixmap(dpi=300)
    out_file = f"assets/images/birth_cert_template_p{page_num+1}.png"
    pix.save(out_file)
    print(f"Saved background template {out_file} ({pix.width}x{pix.height})")

print("Templates created successfully!")
