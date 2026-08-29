"""Render PDF pages as PNG images to enable visual analysis."""
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from pathlib import Path
import fitz

PDF = Path(__file__).resolve().parents[1] / "docs" / "document-ref" / "คู่มือการปฎิบัติงานการเงิน.pdf"
OUT_DIR = Path(__file__).resolve().parents[1] / "tool" / "_pdf_pages"
OUT_DIR.mkdir(parents=True, exist_ok=True)

doc = fitz.open(str(PDF))
print("pages:", doc.page_count)

# Render pages with reasonable resolution. We render every page as PNG
# so we can view contents page-by-page.
for i, page in enumerate(doc):
    pix = page.get_pixmap(matrix=fitz.Matrix(1.6, 1.6))
    out = OUT_DIR / f"page_{i+1:02d}.png"
    pix.save(str(out))
print("done. saved to:", OUT_DIR)
