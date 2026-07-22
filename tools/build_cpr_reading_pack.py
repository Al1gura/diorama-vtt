from __future__ import annotations

import html
import json
import re
import unicodedata
from dataclasses import dataclass
from pathlib import Path

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "个人资产"
OUT_DIR = ROOT / "docs" / "cpr_reading"


@dataclass(frozen=True)
class SourcePdf:
    slug: str
    title: str
    pdf_path: Path


SOURCES = [
    SourcePdf(
        slug="cyberpunk_red_core",
        title="赛博朋克 RED 核心规则书",
        pdf_path=ASSET_DIR / "赛博朋克红2.50.14规则书精修版-高清版(1).pdf",
    ),
    SourcePdf(
        slug="night_city_catalog",
        title="夜之城装备图鉴",
        pdf_path=ASSET_DIR / "赛博装备图鉴.pdf",
    ),
]


def normalize_text(text: str) -> str:
    normalized = unicodedata.normalize("NFKC", text)
    normalized = normalized.replace("\r\n", "\n").replace("\r", "\n")
    normalized = re.sub(r"[ \t]+\n", "\n", normalized)
    normalized = re.sub(r"\n{4,}", "\n\n\n", normalized)
    return normalized.strip()


def page_to_markdown(page_number: int, text: str) -> str:
    if not text:
        return f"## p.{page_number}\n\n> 本页未抽出文字，请回看原 PDF 页面。\n"
    return f"## p.{page_number}\n\n{text}\n"


def extract_source(source: SourcePdf) -> list[dict[str, object]]:
    reader = PdfReader(str(source.pdf_path))
    pages: list[dict[str, object]] = []
    for index, page in enumerate(reader.pages):
        raw_text = page.extract_text() or ""
        text = normalize_text(raw_text)
        pages.append(
            {
                "source_slug": source.slug,
                "source_title": source.title,
                "source_pdf": str(source.pdf_path.relative_to(ROOT)).replace("\\", "/"),
                "page": index + 1,
                "char_count": len(text),
                "needs_pdf_check": len(text) < 80,
                "text": text,
            }
        )
    return pages


def write_jsonl(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def write_markdown(source: SourcePdf, pages: list[dict[str, object]]) -> None:
    lines = [
        f"# {source.title}",
        "",
        f"- 原始 PDF：`{source.pdf_path.relative_to(ROOT)}`",
        f"- 页数：{len(pages)}",
        "- 说明：这是按 PDF 文字层抽出的阅读版。表格、图标、分栏和装饰标题可能需要对照原 PDF。",
        "",
    ]
    for page in pages:
        lines.append(page_to_markdown(int(page["page"]), str(page["text"])))
    (OUT_DIR / f"{source.slug}.md").write_text("\n".join(lines), encoding="utf-8", newline="\n")


def write_summary(all_pages: list[dict[str, object]], by_source: dict[str, list[dict[str, object]]]) -> None:
    lines = [
        "# CPR 资料阅读包",
        "",
        "用途：把 CPR 首个模组需要的规则书和装备扩展整理成便于搜索、引用、对照的资料包。",
        "",
        "## 文件",
        "",
        "- `cyberpunk_red_core.md`：核心规则书按页文字版。",
        "- `night_city_catalog.md`：装备图鉴按页文字版。",
        "- `pages.jsonl`：逐页检索数据，每行一页。",
        "- `reader.html`：本地搜索阅读页，保留原 PDF 页码链接。",
        "",
        "## 可靠性说明",
        "",
        "- 两本 PDF 都有文字层，不是纯扫描图，所以可以直接抽文字。",
        "- 复杂表格、分栏、图标、勾选框和装饰标题不能只信文字抽取；阅读包保留原 PDF 路径和页码用于校对。",
        "- `needs_pdf_check=true` 的页面文字很少，通常是封面、插图页、版权页或图片密集页，应回看原 PDF。",
        "",
        "## 统计",
        "",
        "| 资料 | 页数 | 抽出字符数 | 需回看原 PDF 页数 |",
        "|---|---:|---:|---:|",
    ]
    for source in SOURCES:
        pages = by_source[source.slug]
        chars = sum(int(page["char_count"]) for page in pages)
        check_count = sum(1 for page in pages if bool(page["needs_pdf_check"]))
        lines.append(f"| {source.title} | {len(pages)} | {chars} | {check_count} |")
    lines.extend(
        [
            "",
            "## 工具判断",
            "",
            "- 当前本机可用：`pypdf`、`pdfplumber`、Poppler 页面渲染工具；本次先用可用文字层抽取。",
            "- 推荐后续试用：Docling、Marker、olmOCR、OCRmyPDF/Tesseract、PaddleOCR；Docling/Marker/olmOCR 更适合复杂排版转 Markdown，OCRmyPDF/Tesseract 更适合扫描件加文字层。",
            "- 不开源但常见的参考：Adobe Acrobat、ABBYY FineReader，通常排版/OCR 强，但本机这里不默认可用。",
        ]
    )
    (OUT_DIR / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def pdf_link(source_pdf: str, page: int) -> str:
    return "../" + source_pdf + f"#page={page}"


def write_reader(all_pages: list[dict[str, object]]) -> None:
    data_json = json.dumps(all_pages, ensure_ascii=False)
    root_marker = "__CPR_READER_ROOT__"
    document = f"""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CPR 资料阅读包</title>
<style>
:root {{
  color-scheme: light;
  --bg: #f7f5ef;
  --ink: #1b1d21;
  --muted: #666b76;
  --line: #d9d2c5;
  --panel: #fffdf8;
  --accent: #b0182a;
}}
* {{ box-sizing: border-box; }}
body {{
  margin: 0;
  background: var(--bg);
  color: var(--ink);
  font-family: "Microsoft YaHei", "Noto Sans CJK SC", system-ui, sans-serif;
  line-height: 1.65;
}}
header {{
  position: sticky;
  top: 0;
  z-index: 10;
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 12px;
  align-items: center;
  padding: 14px 18px;
  border-bottom: 1px solid var(--line);
  background: rgba(255, 253, 248, 0.96);
}}
h1 {{
  margin: 0;
  font-size: 20px;
  letter-spacing: 0;
}}
.search {{
  display: flex;
  gap: 8px;
  align-items: center;
}}
input, select {{
  min-height: 36px;
  border: 1px solid var(--line);
  border-radius: 6px;
  background: white;
  color: var(--ink);
  padding: 0 10px;
  font-size: 14px;
}}
input {{ width: min(44vw, 520px); }}
main {{
  width: min(1180px, calc(100vw - 28px));
  margin: 18px auto 48px;
}}
.meta {{
  color: var(--muted);
  margin: 0 0 14px;
}}
.page {{
  margin: 0 0 14px;
  padding: 16px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: var(--panel);
}}
.page h2 {{
  display: flex;
  justify-content: space-between;
  gap: 12px;
  margin: 0 0 10px;
  font-size: 16px;
}}
.page a {{
  color: var(--accent);
  font-weight: 600;
  text-decoration: none;
}}
.text {{
  margin: 0;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}}
.warn {{
  color: #8a5b00;
  font-weight: 600;
}}
mark {{
  background: #ffe08a;
  padding: 0 2px;
}}
@media (max-width: 760px) {{
  header {{ grid-template-columns: 1fr; }}
  .search {{ flex-wrap: wrap; }}
  input {{ width: 100%; }}
}}
</style>
</head>
<body>
<header>
  <h1>CPR 资料阅读包</h1>
  <div class="search">
    <select id="source"></select>
    <input id="query" type="search" placeholder="搜索规则、装备、页码关键词">
  </div>
</header>
<main>
  <p class="meta" id="count"></p>
  <div id="pages"></div>
</main>
<script>
const pages = {data_json};
const sourceSelect = document.getElementById("source");
const queryInput = document.getElementById("query");
const count = document.getElementById("count");
const pagesEl = document.getElementById("pages");
const sources = Array.from(new Set(pages.map(page => page.source_title)));
sourceSelect.innerHTML = ["全部资料", ...sources].map(name => `<option>${{name}}</option>`).join("");

function escapeHtml(value) {{
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
}}

function highlight(text, query) {{
  const safe = escapeHtml(text || "本页未抽出文字，请回看原 PDF 页面。");
  if (!query) return safe;
  const escapedQuery = query.replace(/[.*+?^${{}}()|[\\]\\\\]/g, "\\\\$&");
  return safe.replace(new RegExp(escapedQuery, "gi"), match => `<mark>${{match}}</mark>`);
}}

function render() {{
  const source = sourceSelect.value;
  const query = queryInput.value.trim();
  const lowered = query.toLowerCase();
  const filtered = pages.filter(page => {{
    const sourceOk = source === "全部资料" || page.source_title === source;
    const queryOk = !lowered || `${{page.page}} ${{page.text}}`.toLowerCase().includes(lowered);
    return sourceOk && queryOk;
  }});
  count.textContent = `显示 ${{filtered.length}} / ${{pages.length}} 页。复杂版面请点“原 PDF”。`;
  pagesEl.innerHTML = filtered.slice(0, 160).map(page => {{
    const link = "{root_marker}" + page.source_pdf + "#page=" + page.page;
    const warn = page.needs_pdf_check ? `<span class="warn">需回看原 PDF</span>` : "";
    return `<section class="page">
      <h2><span>${{escapeHtml(page.source_title)}} p.${{page.page}} ${{warn}}</span><a href="${{link}}">原 PDF</a></h2>
      <p class="text">${{highlight(page.text, query)}}</p>
    </section>`;
  }}).join("");
}}

sourceSelect.addEventListener("change", render);
queryInput.addEventListener("input", render);
render();
</script>
</body>
</html>
""".replace(root_marker, "../")
    (OUT_DIR / "reader.html").write_text(document, encoding="utf-8", newline="\n")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    by_source: dict[str, list[dict[str, object]]] = {}
    all_pages: list[dict[str, object]] = []
    for source in SOURCES:
        pages = extract_source(source)
        by_source[source.slug] = pages
        all_pages.extend(pages)
        write_markdown(source, pages)
    write_jsonl(OUT_DIR / "pages.jsonl", all_pages)
    write_summary(all_pages, by_source)
    write_reader(all_pages)


if __name__ == "__main__":
    main()
