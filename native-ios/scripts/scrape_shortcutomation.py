#!/usr/bin/env python3
"""
Scrape shortcutomation.com for all 531 shortcuts.

Strategy:
  1. Parse the GitHub README (one source of truth) to extract every
     (category, name, emoji, slug) tuple.
  2. For each slug, fetch the per-shortcut page concurrently and pluck the
     iCloud UUID from the href that points at icloud.com/shortcuts/<uuid>.
  3. Emit a single JSON file the iOS app loads at runtime.
"""

import json
import re
import sys
import time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import urllib.request

README_URL = "https://raw.githubusercontent.com/huaminghuangtw/Shortcutomation/main/README.md"
OUT = Path(__file__).parent.parent / "App" / "Resources" / "shortcutomation.json"
OUT.parent.mkdir(parents=True, exist_ok=True)
SHORTCUT_PAGE = "https://shortcutomation.com/{slug}"
ICLOUD_RE = re.compile(r"icloud\.com/shortcuts/([0-9a-f]{32})")
SLUG_RE = re.compile(
    r'<a\s+href="https://shortcutomation\.com/([^"#]+?)"\s*>\s*([^<]+?)\s*</a>',
    re.IGNORECASE,
)
CATEGORY_HEADER_RE = re.compile(
    r'<a\s+href="https://shortcutomation\.com/gallery/([^"]+)"\s*>'
    r'\s*([^<(]+?)\s*\((\d+)\)\s*</a>',
    re.IGNORECASE,
)


def fetch(url: str, retries: int = 3, timeout: int = 15) -> str:
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(
                url,
                headers={"User-Agent": "Mozilla/5.0 (Islet scraper)"},
            )
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.read().decode("utf-8", errors="replace")
        except Exception as e:
            last = e
            time.sleep(0.5 * (i + 1))
    raise last


def parse_readme(md: str):
    """Walk the README top-to-bottom. Track current category from the gallery
    header anchors, attach each subsequent shortcut anchor to that category."""
    seen = set()
    current_category = "Uncategorized"
    out = []

    events = []
    for m in CATEGORY_HEADER_RE.finditer(md):
        events.append((m.start(), "cat", (m.group(2).strip(), m.group(1))))
    for m in SLUG_RE.finditer(md):
        slug = m.group(1).rstrip("/")
        text = m.group(2).strip()
        events.append((m.start(), "slug", (slug, text)))
    events.sort(key=lambda x: x[0])

    SKIP_SLUGS = {
        "gallery", "blog", "dashboard", "changelog", "contact",
        "shortcuts", "all", "", "about",
    }

    for _, kind, payload in events:
        if kind == "cat":
            name, _ = payload
            current_category = name
        else:
            slug, text = payload
            if "/" in slug or slug in SKIP_SLUGS or slug in seen:
                continue
            seen.add(slug)
            # Strip leading emoji from display name.
            emoji, name = "", text
            if text and not text[0].isalnum() and text[0] not in "_-":
                i = 0
                while i < len(text) and not text[i].isalnum() and text[i] not in "_-":
                    i += 1
                emoji, name = text[:i].strip(), text[i:].strip()
            out.append({
                "slug": slug,
                "name": name or text,
                "emoji": emoji,
                "category": current_category,
            })
    return out


def fetch_uuid(entry: dict) -> dict:
    url = SHORTCUT_PAGE.format(slug=entry["slug"])
    try:
        html = fetch(url)
        m = ICLOUD_RE.search(html)
        entry["uuid"] = m.group(1) if m else None
        meta = re.search(
            r'(\d+)\s+actions\s+(\d+(?:\.\d+)?)\s+(KB|MB)', html, re.IGNORECASE
        )
        if meta:
            entry["actions"] = int(meta.group(1))
            entry["size"] = f"{meta.group(2)} {meta.group(3)}"

        # Extract Required Apps · the page renders this as
        # <h3>Required Apps</h3><ul><li><a href="...">Name</a></li>...</ul>
        required = []
        m2 = re.search(
            r'Required\s+Apps?\s*</h3>\s*<ul[^>]*>(.*?)</ul>',
            html,
            re.DOTALL | re.IGNORECASE,
        )
        if m2:
            block = m2.group(1)
            seen_names = set()
            for am in re.finditer(
                r'<a[^>]+href="(https?://[^"]+)"[^>]*>(.*?)</a>',
                block,
                re.DOTALL,
            ):
                href, label = am.group(1), am.group(2)
                label = re.sub(r'\s+', ' ', label).strip()
                label = label.lstrip("→").strip()
                if "shortcutomation.com" in href or "icloud.com" in href:
                    continue
                if label and label not in seen_names:
                    seen_names.add(label)
                    required.append({"name": label, "url": href})
        if required:
            entry["requiredApps"] = required
    except Exception as e:
        entry["uuid"] = None
        entry["error"] = str(e)[:80]
    return entry


def main():
    print("Fetching README...", file=sys.stderr)
    md = fetch(README_URL)
    print(f"  {len(md)} chars", file=sys.stderr)

    print("Parsing slugs...", file=sys.stderr)
    entries = parse_readme(md)
    print(f"  {len(entries)} unique slugs", file=sys.stderr)

    print("Scraping per-shortcut iCloud UUIDs (12 workers)...", file=sys.stderr)
    done = 0
    with ThreadPoolExecutor(max_workers=12) as ex:
        futures = {ex.submit(fetch_uuid, e): e for e in entries}
        for f in as_completed(futures):
            f.result()
            done += 1
            if done % 25 == 0:
                print(f"  {done}/{len(entries)}", file=sys.stderr)

    with_uuid = [e for e in entries if e.get("uuid")]
    without = [e for e in entries if not e.get("uuid")]
    print(f"Got UUIDs for {len(with_uuid)}/{len(entries)}", file=sys.stderr)
    if without:
        print(f"Skipped {len(without)} without iCloud link:", file=sys.stderr)
        for e in without[:15]:
            print(f"  - {e['slug']} ({e['category']})", file=sys.stderr)

    OUT.write_text(json.dumps(with_uuid, indent=2, ensure_ascii=False))
    print(f"Wrote {OUT} ({OUT.stat().st_size} bytes)", file=sys.stderr)


if __name__ == "__main__":
    main()
