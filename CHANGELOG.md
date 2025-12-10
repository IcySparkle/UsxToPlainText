# Changelog — UsxToPlainText.ps1

All notable changes to **UsxToPlainText.ps1** are documented here.

This script converts USX / USFM / SFM Bible manuscripts into plain, styling‑free text suitable for flowing into Adobe InDesign, preserving prose paragraphs and poetry structure.

---

## **0.4.0 — 2025-12-10**
### 🌟 Major Release — Unified USX + USFM/SFM Support
**Highlights**
- Added **full USFM (`.usfm`) and SFM (`.sfm`) support**.
- Unified text extraction model across formats:
  - One paragraph block for prose
  - Poetry lines broken into separate lines
  - Verse numbers prefixed to each verse
- Introduced **poetry indentation logic** for:
  - `q`, `q1`, `q2`, `q3`, `q4`
- Superscript removal now consistent:
  - USX: `<char style="sup">…</char>`
  - USFM: `\sup...\sup*` and `\+sup...\+sup*`
- Notes fully removed:
  - USX `<note>`
  - USFM `\f...\f*` and `\x...\x*`
- Improved whitespace normalization.
- Output is now ideal for direct InDesign import (paragraphs + poetry).

---

## **0.3.0 — 2025-12-10**
### ✨ Poetry Engine Added
- Introduced `q`, `q1–q4` detection.
- Poetry exported with newline separation.
- Basic indentation rules implemented.

---

## **0.2.0 — 2025-12-10**
### 📄 Paragraph + Verse Handling
- Verse numbers now inserted inline.
- Paragraph merging for prose implemented.
- Basic USX milestone (`sid` / `eid`) parsing added.

---

## **0.1.0 — 2025-12-10**
### 🎉 Initial Version
- USX-only plain-text generator.
- Removed inline tags, kept plain text only.
- Basic whitespace cleanup.
- Exported one `.txt` per `.usx` file.

---
