from pathlib import Path
import os

import fitz
import pytesseract
from PIL import Image


def main() -> None:
    pdf_path = Path("D:/project/saccmproject/docs/document-ref/คู่มือการปฎิบัติงานการเงิน.pdf")
    out_path = Path("D:/project/saccmproject/docs/document-ref/คู่มือการปฎิบัติงานการเงิน_ocr.md")
    tessdata_dir = Path("D:/project/saccmproject/docs/document-ref/.tessdata")
    pytesseract.pytesseract.tesseract_cmd = "C:/Program Files/Tesseract-OCR/tesseract.exe"
    os.environ["TESSDATA_PREFIX"] = tessdata_dir.as_posix()

    config = "--oem 1 --psm 6"
    doc = fitz.open(pdf_path)
    total_pages = doc.page_count

    parts = [
        "# คู่มือการปฏิบัติงานการเงิน (OCR)",
        "",
        "ไฟล์นี้ได้จาก OCR ของ PDF สแกน อาจมีตัวสะกดคลาดเคลื่อนบางจุด",
        "",
    ]

    for i, page in enumerate(doc, start=1):
        pix = page.get_pixmap(matrix=fitz.Matrix(2, 2), alpha=False)
        img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
        text = pytesseract.image_to_string(img, lang="tha+eng", config=config)

        parts.append(f"## หน้า {i}")
        parts.append("")
        parts.append(text.strip() if text.strip() else "[ไม่พบข้อความจาก OCR]")
        parts.append("")

        if i % 5 == 0:
            print(f"processed {i}/{total_pages}")

    out_path.write_text("\n".join(parts), encoding="utf-8")
    print(f"written: {out_path}")


if __name__ == "__main__":
    main()
