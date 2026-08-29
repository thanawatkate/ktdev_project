"""Try extracting PDF manual with multiple libraries."""
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
from pathlib import Path

PDF = Path(__file__).resolve().parents[1] / "docs" / "document-ref" / "คู่มือการปฎิบัติงานการเงิน.pdf"
OUT = Path(__file__).resolve().parents[1] / "tool" / "_pdf_extract.txt"

print("PDF:", PDF, "exists:", PDF.exists())

with OUT.open("w", encoding="utf-8") as w:
    try:
        import fitz  # pymupdf
        doc = fitz.open(str(PDF))
        w.write(f"# PyMuPDF extraction (pages={doc.page_count})\n")
        total_chars = 0
        for i, page in enumerate(doc):
            t = page.get_text("text")
            total_chars += len(t)
            if t.strip():
                w.write(f"\n--- page {i+1} ---\n{t}\n")
        w.write(f"\n[total chars extracted: {total_chars}]\n")
        print("PyMuPDF text chars:", total_chars)
        doc.close()
    except Exception as e:
        w.write(f"PyMuPDF error: {e}\n")
        print("PyMuPDF error:", e)

    try:
        import pdfplumber
        w.write("\n\n##### pdfplumber attempt #####\n")
        with pdfplumber.open(str(PDF)) as pdf:
            for i, page in enumerate(pdf.pages):
                t = page.extract_text() or ""
                if t.strip():
                    w.write(f"\n--- page {i+1} ---\n{t}\n")
        print("pdfplumber done")
    except Exception as e:
        w.write(f"pdfplumber error: {e}\n")
        print("pdfplumber error:", e)
