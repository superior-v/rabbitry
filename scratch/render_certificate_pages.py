import pymupdf

pdf_path = r'C:\Users\ravim\.gemini\antigravity-ide\brain\a2e3f22c-63d8-4684-809b-8678339211c6\.user_uploaded\media_1791619577167.pdf'
doc = pymupdf.open(pdf_path)

with open("scratch/pdf_details.txt", "w", encoding="utf-8") as log:
    log.write(f"Total pages: {len(doc)}\n")
    for i, page in enumerate(doc):
        log.write(f"\n--- PAGE {i + 1} ---\n")
        log.write(f"Rect: {page.rect}\n")
        log.write(f"Text:\n{page.get_text()}\n")
        
        # Check images on page
        images = page.get_images()
        log.write(f"Images on page {i + 1}: {len(images)}\n")
        for img_idx, img in enumerate(images):
            xref = img[0]
            base_img = doc.extract_image(xref)
            img_bytes = base_img["image"]
            img_ext = base_img["ext"]
            out_path = f"assets/images/pdf_extracted_p{i+1}_{img_idx}.{img_ext}"
            with open(out_path, "wb") as f:
                f.write(img_bytes)
            log.write(f"  Extracted image {xref} ({base_img['width']}x{base_img['height']}) -> {out_path}\n")

        # Render page to high-res PNG (200 DPI)
        pix = page.get_pixmap(dpi=200)
        page_out = f"assets/images/certificate_reference_p{i+1}.png"
        pix.save(page_out)
        log.write(f"Rendered page {i + 1} to {page_out} ({pix.width}x{pix.height})\n")

print("Done extracting and rendering!")
