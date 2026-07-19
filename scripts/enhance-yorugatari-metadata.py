from __future__ import annotations

import json
import re
from pathlib import Path
from urllib.parse import quote


ROOT = Path(__file__).resolve().parents[1] / "yorugatari"
VERSION = "20260719-112"
SHARE_IMAGE = "https://allsunday1122.github.io/yorugatari/assets/yorugatari-share.png"


def replace_asset_version(text: str, asset: str) -> str:
    pattern = rf'({re.escape(asset)})(?:\?v=[^"\']+)?'
    return re.sub(pattern, rf"\1?v={VERSION}", text)


def add_share_metadata(text: str) -> str:
    text = text.replace(
        '<meta name="twitter:card" content="summary">',
        '<meta name="twitter:card" content="summary_large_image">',
    )
    if 'name="twitter:card"' not in text:
        text = text.replace(
            '</head>',
            '  <meta name="twitter:card" content="summary_large_image">\n</head>',
            1,
        )
    if 'property="og:image"' in text:
        return text

    tags = (
        f'  <meta property="og:image" content="{SHARE_IMAGE}">\n'
        '  <meta property="og:image:width" content="2048">\n'
        '  <meta property="og:image:height" content="683">\n'
        '  <meta property="og:image:alt" content="月明かりと提灯が照らす夜の町並み">\n'
        f'  <meta name="twitter:image" content="{SHARE_IMAGE}">\n'
    )
    marker = '  <meta name="twitter:card" content="summary_large_image">\n'
    if marker in text:
        return text.replace(marker, marker + tags, 1)
    return text.replace('</head>', tags + '</head>', 1)


def enhance_story(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    text = replace_asset_version(text, "../assets/styles.css")
    text = replace_asset_version(text, "../assets/story.js")
    text = add_share_metadata(text)
    if 'rel="preconnect" href="https://page-views-api.ratneshc.com"' not in text:
        text = re.sub(
            r'(<link rel="canonical")',
            r'<link rel="preconnect" href="https://page-views-api.ratneshc.com" crossorigin>\n\1',
            text,
            count=1,
        )

    if '"@type":"BreadcrumbList"' not in text:
        title_match = re.search(r'<h1>([^<]+)</h1>', text)
        category_match = re.search(r'<span class="badge">([^<]+)</span>', text)
        canonical_match = re.search(r'<link rel="canonical" href="([^"]+)">', text)
        if not (title_match and category_match and canonical_match):
            raise RuntimeError(f"Story metadata markers missing: {path}")
        title = title_match.group(1)
        category = category_match.group(1)
        canonical = canonical_match.group(1)
        breadcrumb = {
            "@context": "https://schema.org",
            "@type": "BreadcrumbList",
            "itemListElement": [
                {
                    "@type": "ListItem",
                    "position": 1,
                    "name": "夜語り",
                    "item": "https://allsunday1122.github.io/yorugatari/",
                },
                {
                    "@type": "ListItem",
                    "position": 2,
                    "name": "全100話",
                    "item": "https://allsunday1122.github.io/yorugatari/archive.html",
                },
                {
                    "@type": "ListItem",
                    "position": 3,
                    "name": category,
                    "item": "https://allsunday1122.github.io/yorugatari/archive.html#" + quote(category),
                },
                {
                    "@type": "ListItem",
                    "position": 4,
                    "name": title,
                    "item": canonical,
                },
            ],
        }
        script = (
            '  <script type="application/ld+json">'
            + json.dumps(breadcrumb, ensure_ascii=False, separators=(",", ":"))
            + "</script>\n"
        )
        text = text.replace('</head>', script + '</head>', 1)

    path.write_text(text, encoding="utf-8")


def enhance_index() -> None:
    path = ROOT / "index.html"
    text = path.read_text(encoding="utf-8")
    text = text.replace(
        '<title>夜語り｜オリジナル怖い話</title>',
        '<title>夜語り｜無料で読めるオリジナル怖い話100選</title>',
    )
    text = re.sub(
        r'<meta name="description" content="[^"]+">',
        '<meta name="description" content="心霊・人怖・意味怖・ネット怪談など、無料で読める一話完結のオリジナル怖い話100作品。約5〜10分、眠る前にひとつだけ。">',
        text,
        count=1,
    )
    text = text.replace(
        '<meta property="og:title" content="夜語り｜オリジナル怖い話">',
        '<meta property="og:title" content="夜語り｜無料で読めるオリジナル怖い話100選">',
    )
    text = text.replace(
        '<meta property="og:description" content="一話完結の中編・長編怪談を掲載する、オリジナル怖い話サイト。">',
        '<meta property="og:description" content="眠る前にひとつだけ。無料で読める一話完結のオリジナル怖い話100作品。">',
    )
    text = add_share_metadata(text)
    text = replace_asset_version(text, "assets/styles.css")
    text = replace_asset_version(text, "assets/app.js")
    path.write_text(text, encoding="utf-8")


def enhance_archive() -> None:
    path = ROOT / "archive.html"
    text = add_share_metadata(path.read_text(encoding="utf-8"))
    text = replace_asset_version(text, "assets/styles.css")
    text = replace_asset_version(text, "assets/archive.js")
    path.write_text(text, encoding="utf-8")


def main() -> None:
    stories = sorted((ROOT / "stories").glob("*.html"))
    if len(stories) != 100:
        raise RuntimeError(f"Expected 100 story pages, found {len(stories)}")
    enhance_index()
    enhance_archive()
    for story in stories:
        enhance_story(story)
    print(f"Enhanced metadata for {len(stories)} stories.")


if __name__ == "__main__":
    main()
