# UsxToPlainText — Scripture Formatting Extractor for USX / USFM / SFM

`UsxToPlainText.ps1` is a PowerShell script that converts **USX**, **USFM**, and **SFM** Bible source files into clean, publish-ready **plain text** for typesetting software such as **Adobe InDesign**.

The script removes all structural markup, extracts verse text with controlled formatting, handles poetry correctly, and normalizes the output into a format that designers can flow directly into layouts.

---

## ✨ Key Features

### ✔ Supports all major Scripture formats
- **USX** (XML format used by many translation systems)
- **USFM** (`.usfm`)
- **SFM** (`.sfm`, legacy Paratext format)

### ✔ Clean, consistent text output
- Inline styling removed (`\wj`, `\add`, `\nd`, `\it`, `\+qt`, etc.)
- Superscript markers (`<char style="sup">`) removed
- Notes and cross-references removed

### ✔ Poetry preserved correctly
- Poetry markers in USFM: `\q`, `\q1`–`q4`, `\qt`, `\qt1`–`qt4`
- Poetry markers in USX: `<para style="q1">`, etc.

➡ **Each poetry verse becomes its own line**

### ✔ Prose paragraphs merged
Prose paragraphs (`\p`, `\m`, `\pi`, `<para style="p">`, etc.) are joined into **one line per paragraph**, with verse numbers inserted:

```
1 In the beginning... 2 The earth was formless...
```

### ✔ Section headings extracted
Headings like `\s`, `\s1`, `\ms`, `\mr` become standalone lines.

### ✔ Whitespace normalization
Extra whitespace collapsed; output ready for InDesign.

### ✔ UTF-8 with BOM output

---

## 📁 Example Output Structure

```
1
Greeting
1 The elder to the beloved Gaius, whom I love in truth.
2 Beloved, I pray that all may go well with you...
```

Poetry example:

```
5 I rejoiced greatly
6 when the brothers came and testified to your truth
```

---

## 🚀 Usage

### Single File

```powershell
.\UsxToPlainText.ps1 ".\3JN.usx"
.\UsxToPlainText.ps1 ".\3JN.usfm"
.\UsxToPlainText.ps1 ".\3JN.sfm"
```

### Folder of Mixed Files

```powershell
.\UsxToPlainText.ps1 ".\InputFolder"
```

### Specify Output Folder

```powershell
.\UsxToPlainText.ps1 ".\InputFolder" ".\PlainTextOutput"
```

---

## 🧠 Supported Marker Summary

### Paragraph markers
| Type | USFM | USX |
|------|------|------|
| Prose | `\p`, `\m`, `\pi` | `<para style="p">`, `<para style="m">` |
| Poetry | `\q`, `\q1`–`\q4`, `\qt`, `\qt1`–`qt4` | `<para style="q1">`, `<para style="q2">` |
| Headings | `\s`, `\s1`, `\ms`, `\mr` | `<para style="s">`, `<para style="ms">` |

### Verse markers
- `\v N`
- `<verse number="N">`

### Inline markers removed
- `\wj`, `\nd`, `\add`, `\it`, `\bd`, `\bdit`
- `\+qt` and `\+qt*`
- `<char style="sup">…</char>`
- Notes (`\f...\f*`, `\x...\x*`, `<note>…</note>`)

---

## 🛠 Behavior Summary

### ✔ Prose → one line per paragraph  
### ✔ Poetry → one line per verse  
### ✔ Headings → standalone lines  
### ✔ Continuation paragraphs handled cleanly  

---

## 📦 Output

Each input file produces a `.txt` file with the same basename:

```
Input:   3JN.usx
Output:  3JN.txt
```

---

## 🤝 Contributing

Suggestions and improvements welcome!

Future enhancements:
- Poetry indentation by level (`q1`, `q2`, etc.)
- Optional blank lines between paragraphs
- Combined-book output mode
- Inline-tag configuration

---

## 📜 License

MIT License.

---

## 🙌 Acknowledgements

Designed for real-world Scripture publishing workflows, compatible with Paratext USFM/USX pipelines, DBL extracts, and professional typesetting environments.
