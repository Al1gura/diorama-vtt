from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
READING_DIR = ROOT / "docs" / "cpr_reading"
PAGES_PATH = READING_DIR / "pages.jsonl"
OUT_DIR = READING_DIR / "agent_index"

MAX_CHARS = 1800
OVERLAP_CHARS = 180

TERMS = [
    "伏击",
    "突然袭击",
    "掩体",
    "护甲",
    "SP",
    "伤害",
    "严重伤势",
    "死亡豁免",
    "先攻",
    "移动",
    "近战",
    "远程",
    "自动开火",
    "爆炸物",
    "手雷",
    "射击",
    "瞄准",
    "网行者",
    "黑冰",
    "程序",
    "接口",
    "赛博空间",
    "独狼",
    "技术专家",
    "摇滚小子",
    "公司人",
    "执法者",
    "媒体",
    "中间人",
    "游牧民",
    "创伤小队",
    "赛博殖装",
    "人性损失",
    "武器",
    "装备",
    "应用程序",
    "线性框架",
    "夜之城",
    "GM",
    "DV",
    "REF",
    "DEX",
    "BODY",
    "WILL",
    "INT",
    "COOL",
    "TECH",
    "MOVE",
    "EMP",
    "LUCK",
]


def load_pages() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    with PAGES_PATH.open("r", encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                rows.append(json.loads(line))
    return rows


def compact_text(text: str) -> str:
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def split_page_text(page: dict[str, object]) -> list[dict[str, object]]:
    source_slug = str(page["source_slug"])
    source_title = str(page["source_title"])
    source_pdf = str(page["source_pdf"])
    page_number = int(page["page"])
    text = compact_text(str(page["text"]))
    if not text:
        return [
            {
                "id": f"{source_slug}-p{page_number:04d}-c001",
                "source_slug": source_slug,
                "source_title": source_title,
                "source_pdf": source_pdf,
                "page_start": page_number,
                "page_end": page_number,
                "needs_pdf_check": True,
                "char_count": 0,
                "text": "",
            }
        ]

    chunks: list[dict[str, object]] = []
    start = 0
    chunk_number = 1
    while start < len(text):
        end = min(len(text), start + MAX_CHARS)
        if end < len(text):
            boundary = max(text.rfind("\n", start, end), text.rfind("。", start, end), text.rfind("；", start, end))
            if boundary > start + 600:
                end = boundary + 1
        chunk_text = text[start:end].strip()
        chunks.append(
            {
                "id": f"{source_slug}-p{page_number:04d}-c{chunk_number:03d}",
                "source_slug": source_slug,
                "source_title": source_title,
                "source_pdf": source_pdf,
                "page_start": page_number,
                "page_end": page_number,
                "needs_pdf_check": bool(page["needs_pdf_check"]),
                "char_count": len(chunk_text),
                "text": chunk_text,
            }
        )
        if end >= len(text):
            break
        start = max(0, end - OVERLAP_CHARS)
        chunk_number += 1
    return chunks


def build_keyword_index(chunks: list[dict[str, object]]) -> dict[str, list[dict[str, object]]]:
    index: dict[str, list[dict[str, object]]] = defaultdict(list)
    for chunk in chunks:
        text = str(chunk["text"])
        for term in TERMS:
            if term in text:
                index[term].append(
                    {
                        "chunk_id": chunk["id"],
                        "source_title": chunk["source_title"],
                        "page": chunk["page_start"],
                        "needs_pdf_check": chunk["needs_pdf_check"],
                    }
                )
    return dict(sorted(index.items(), key=lambda item: item[0].lower()))


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8", newline="\n")


def write_jsonl(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def write_readme(chunks: list[dict[str, object]], pages: list[dict[str, object]], keyword_index: dict[str, list[dict[str, object]]]) -> None:
    source_counts: dict[str, int] = defaultdict(int)
    for chunk in chunks:
        source_counts[str(chunk["source_title"])] += 1

    lines = [
        "# CPR Codex 查阅模式",
        "",
        "这层资料不是给人翻页看的，而是给后续规则问答、模组拆解和页码核对用的。",
        "",
        "## 文件",
        "",
        "- `agent_chunks.jsonl`：按页切成小块的正文，每块带来源、PDF 路径、页码和是否需要回看原 PDF。",
        "- `agent_keyword_index.json`：常用 CPR/地图实现关键词到块和页码的索引。",
        "- `agent_page_catalog.json`：每页字符数、来源和校对状态。",
        "",
        "## 使用原则",
        "",
        "- 回答具体规则时，先搜 `agent_keyword_index.json` 或 `agent_chunks.jsonl`。",
        "- 引用结论时必须带资料名和页码。",
        "- `needs_pdf_check=true` 或涉及图标/表格/分栏时，必须回看原 PDF 页面。",
        "- 不把阅读包当作规则系统设计本身；Gvtt 当前仍是 GM 桌面工具，不自动掷骰、不自动结算伤害。",
        "",
        "## 统计",
        "",
        f"- 原始页数：{len(pages)}",
        f"- 分块数：{len(chunks)}",
        f"- 关键词数：{len(keyword_index)}",
    ]
    for source_title, count in sorted(source_counts.items()):
        lines.append(f"- {source_title}：{count} 块")
    (OUT_DIR / "agent_readme.md").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    pages = load_pages()
    chunks: list[dict[str, object]] = []
    for page in pages:
        chunks.extend(split_page_text(page))

    page_catalog = [
        {
            "source_slug": page["source_slug"],
            "source_title": page["source_title"],
            "source_pdf": page["source_pdf"],
            "page": page["page"],
            "char_count": page["char_count"],
            "needs_pdf_check": page["needs_pdf_check"],
        }
        for page in pages
    ]
    keyword_index = build_keyword_index(chunks)

    write_jsonl(OUT_DIR / "agent_chunks.jsonl", chunks)
    write_json(OUT_DIR / "agent_keyword_index.json", keyword_index)
    write_json(OUT_DIR / "agent_page_catalog.json", page_catalog)
    write_readme(chunks, pages, keyword_index)


if __name__ == "__main__":
    main()
