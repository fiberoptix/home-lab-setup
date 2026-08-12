#!/usr/bin/env python3
"""Build Word versions of the education chapters.

Requirements this exists to satisfy:
  * 11pt body, single spaced, textbook-professional look
  * every figure fills the full width of the text column, so small type is
    as large as the page allows
  * no type inside a figure smaller than ~10pt on the printed page

The third one is the reason this script does arithmetic instead of just
handing pandoc a fixed width. Word scales an image uniformly, so a figure
whose source is 14in wide gets squashed to 45% and its 9pt annotations land
at 4pt. Two things fix that, and both are needed:

  1. The figures themselves were rewritten to be narrow (see
     education/tools/figcheck.py, which reports the on-page size of the
     smallest type in every figure).
  2. Here, each image is given an explicit width -- the full 7in column --
     but capped so a tall figure still fits the 9in text height rather than
     overflowing onto the next page.

This is shared across every study track, so the track comes first:

Usage:
    python3 education/tools/build_docx.py <track>          # every chapter
    python3 education/tools/build_docx.py <track> 3 6      # chapters 3 and 6
    python3 education/tools/build_docx.py --list           # available tracks
"""

import pathlib
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile

EDUCATION = pathlib.Path(__file__).resolve().parent.parent
CHAPTER_GLOB = "chapter[0-9][0-9]_*.md"

# Letter page, 0.75in side margins, 1in top/bottom -> 7.0 x 9.0in of text.
PAGE_W_TWIPS, PAGE_H_TWIPS = 12240, 15840
MARGIN_X, MARGIN_Y = 1080, 1440
COL_IN = (PAGE_W_TWIPS - 2 * MARGIN_X) / 1440
TEXT_H_IN = (PAGE_H_TWIPS - 2 * MARGIN_Y) / 1440
FIG_MAX_H_IN = TEXT_H_IN - 0.6          # leave room for the caption

BODY_FONT, HEAD_FONT, MONO_FONT = "Cambria", "Calibri", "Consolas"
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

# Review highlighting. Word's own highlighter (w:highlight) is a closed set of
# 15 named colours -- "yellow" is #FFFF00 at full strength, with no tint or
# opacity control, and it lays down a wet band of ink on an inkjet. Character
# shading takes an arbitrary fill instead, so this is a ~31% tint of yellow:
# obvious on screen, cheap to print, and still legible as grey in greyscale.
HIGHLIGHT_FILL = "FFF3B0"


def png_size(path):
    return struct.unpack(">II", path.read_bytes()[16:24])


# --------------------------------------------------------------- reference

def el(tag, **attrs):
    a = " ".join(f'w:{k.replace("_", ":")}="{v}"' for k, v in attrs.items())
    return f"<w:{tag} {a}/>" if a else f"<w:{tag}/>"


def style_block(sid, *, font, half_pt, bold=False, italic=False, color=None,
                before=0, after=120, line=240, indent=None, keep_next=False,
                border_left=None, shade=None):
    ppr = [f'<w:spacing w:before="{before}" w:after="{after}" '
           f'w:line="{line}" w:lineRule="auto"/>']
    if indent:
        ppr.append(f'<w:ind w:left="{indent}" w:right="120"/>')
    if keep_next:
        ppr.append('<w:keepNext/>')
    if border_left:
        ppr.append('<w:pBdr><w:left w:val="single" w:sz="18" w:space="10" '
                   f'w:color="{border_left}"/></w:pBdr>')
    if shade:
        ppr.append(f'<w:shd w:val="clear" w:fill="{shade}"/>')

    rpr = [f'<w:rFonts w:ascii="{font}" w:hAnsi="{font}" w:cs="{font}"/>']
    if bold:
        rpr.append("<w:b/>")
    if italic:
        rpr.append("<w:i/>")
    if color:
        rpr.append(f'<w:color w:val="{color}"/>')
    rpr.append(f'<w:sz w:val="{half_pt}"/><w:szCs w:val="{half_pt}"/>')

    return ("<w:pPr>" + "".join(ppr) + "</w:pPr>"), ("<w:rPr>" + "".join(rpr) + "</w:rPr>")


SPEC = {
    # style id       font        size  bold   extras
    "Normal":        dict(font=BODY_FONT, half_pt=22, after=120),
    "BodyText":      dict(font=BODY_FONT, half_pt=22, after=120),
    "FirstParagraph":dict(font=BODY_FONT, half_pt=22, after=120),
    "Compact":       dict(font=BODY_FONT, half_pt=22, after=40),
    "Title":         dict(font=HEAD_FONT, half_pt=44, bold=True, color="1F3864",
                          after=80, before=0),
    "Subtitle":      dict(font=HEAD_FONT, half_pt=26, color="595959", after=240),
    "Heading1":      dict(font=HEAD_FONT, half_pt=32, bold=True, color="1F3864",
                          before=360, after=140, keep_next=True),
    "Heading2":      dict(font=HEAD_FONT, half_pt=26, bold=True, color="2E5496",
                          before=280, after=110, keep_next=True),
    "Heading3":      dict(font=HEAD_FONT, half_pt=23, bold=True, color="2E5496",
                          before=220, after=90, keep_next=True),
    "Heading4":      dict(font=HEAD_FONT, half_pt=22, bold=True, italic=True,
                          color="404040", before=200, after=80, keep_next=True),
    # blockquotes carry the figure commentary, so make them read as pull-outs
    "BlockText":     dict(font=BODY_FONT, half_pt=21, after=120, indent=260,
                          border_left="8EAADB", shade="F2F6FC"),
    "ImageCaption":  dict(font=HEAD_FONT, half_pt=19, italic=True, color="404040",
                          before=60, after=240),
    "Caption":       dict(font=HEAD_FONT, half_pt=19, italic=True, color="404040",
                          before=60, after=240),
    "TableCaption":  dict(font=HEAD_FONT, half_pt=19, italic=True, color="404040",
                          before=60, after=120),
    "SourceCode":    dict(font=MONO_FONT, half_pt=18, after=60, line=240),
}

CHAR_SPEC = {
    "VerbatimChar": f'<w:rFonts w:ascii="{MONO_FONT}" w:hAnsi="{MONO_FONT}" '
                    f'w:cs="{MONO_FONT}"/><w:sz w:val="19"/><w:szCs w:val="19"/>'
                    '<w:shd w:val="clear" w:fill="F2F2F2"/>',
    # pandoc resolves custom-style="Key" by style NAME, so id and name match.
    "Key":          '<w:shd w:val="clear" w:color="auto" '
                    f'w:fill="{HIGHLIGHT_FILL}"/>',
}
CHAR_CUSTOM = {"Key"}


# pandoc decides whether to inject its own code style by matching the style
# NAME, not the id -- so this must be "Source Code", or the document ends up
# with two SourceCode styles and pandoc's (Cambria 11pt) is the one that wins.
NAME_OVERRIDE = {"SourceCode": "Source Code"}
CUSTOM = {"SourceCode"}


def patch_styles(xml):
    for sid, kw in SPEC.items():
        ppr, rpr = style_block(sid, **kw)
        pat = re.compile(
            rf'(<w:style [^>]*w:styleId="{sid}"[^>]*>)(.*?)(</w:style>)', re.S)
        m = pat.search(xml)
        name = NAME_OVERRIDE.get(sid, sid)
        body = f'<w:name w:val="{name}"/>'
        based = "" if sid == "Normal" else '<w:basedOn w:val="Normal"/>'
        custom = ' w:customStyle="1"' if sid in CUSTOM else ""
        link = '<w:link w:val="VerbatimChar"/>' if sid == "SourceCode" else ""
        new = (f'<w:style w:type="paragraph"{custom} w:styleId="{sid}">'
               f'{body}{based}{link}{ppr}{rpr}</w:style>')
        if m:
            xml = xml[:m.start()] + new + xml[m.end():]
        else:
            xml = xml.replace("</w:styles>", new + "</w:styles>")

    for sid, rpr_inner in CHAR_SPEC.items():
        pat = re.compile(
            rf'(<w:style [^>]*w:styleId="{sid}"[^>]*>)(.*?)(</w:style>)', re.S)
        custom = ' w:customStyle="1"' if sid in CHAR_CUSTOM else ""
        new = (f'<w:style w:type="character"{custom} w:styleId="{sid}">'
               f'<w:name w:val="{sid}"/><w:rPr>{rpr_inner}</w:rPr></w:style>')
        if pat.search(xml):
            xml = pat.sub(new, xml, count=1)
        else:
            xml = xml.replace("</w:styles>", new + "</w:styles>")

    # bordered, readable tables
    table = (
        '<w:style w:type="table" w:styleId="Table">'
        '<w:name w:val="Table"/>'
        '<w:tblPr><w:tblBorders>'
        + "".join(f'<w:{e} w:val="single" w:sz="4" w:space="0" w:color="A6A6A6"/>'
                  for e in ("top", "left", "bottom", "right", "insideH", "insideV"))
        + '</w:tblBorders>'
        '<w:tblCellMar>'
        '<w:top w:w="60" w:type="dxa"/><w:left w:w="90" w:type="dxa"/>'
        '<w:bottom w:w="60" w:type="dxa"/><w:right w:w="90" w:type="dxa"/>'
        '</w:tblCellMar></w:tblPr>'
        f'<w:rPr><w:rFonts w:ascii="{BODY_FONT}" w:hAnsi="{BODY_FONT}"/>'
        '<w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>'
        '<w:tblStylePr w:type="firstRow"><w:rPr><w:b/></w:rPr>'
        '<w:tcPr><w:shd w:val="clear" w:fill="DEEAF6"/></w:tcPr></w:tblStylePr>'
        '</w:style>')
    xml = re.sub(r'<w:style w:type="table" w:styleId="Table">.*?</w:style>',
                 table, xml, count=1, flags=re.S)
    return xml


def patch_sectpr(xml):
    sect = (f'<w:sectPr><w:pgSz w:w="{PAGE_W_TWIPS}" w:h="{PAGE_H_TWIPS}"/>'
            f'<w:pgMar w:top="{MARGIN_Y}" w:right="{MARGIN_X}" '
            f'w:bottom="{MARGIN_Y}" w:left="{MARGIN_X}" '
            'w:header="720" w:footer="720" w:gutter="0"/>'
            '<w:footnotePr><w:numRestart w:val="eachSect"/></w:footnotePr>'
            '</w:sectPr>')
    if "<w:sectPr" in xml:
        return re.sub(r"<w:sectPr.*?</w:sectPr>", sect, xml, count=1, flags=re.S)
    return xml.replace("</w:body>", sect + "</w:body>")


def build_reference(dest):
    with tempfile.TemporaryDirectory() as td:
        src = pathlib.Path(td) / "ref.docx"
        src.write_bytes(subprocess.run(
            ["pandoc", "--print-default-data-file", "reference.docx"],
            capture_output=True, check=True).stdout)
        work = pathlib.Path(td) / "x"
        with zipfile.ZipFile(src) as z:
            z.extractall(work)
        sp = work / "word" / "styles.xml"
        sp.write_text(patch_styles(sp.read_text()), encoding="utf-8")
        dp = work / "word" / "document.xml"
        dp.write_text(patch_sectpr(dp.read_text()), encoding="utf-8")
        with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
            for f in sorted(work.rglob("*")):
                if f.is_file():
                    z.write(f, f.relative_to(work))
    return dest


# ----------------------------------------------------------------- chapters

def size_images(md_text, track):
    """Give every image an explicit width: the full column, height-capped."""
    def repl(m):
        alt, rel = m.group(1), m.group(2)
        img = track / rel
        if not img.exists():
            return m.group(0)
        w, h = png_size(img)
        width = min(COL_IN, FIG_MAX_H_IN * w / h)
        return f'![{alt}]({rel}){{width={width:.2f}in}}'
    return re.sub(r"!\[([^\]]*)\]\((images/[^)]+\.png)\)", repl, md_text)


def build_chapter(md_path, reference, track):
    out_dir = track / "docx"
    out_dir.mkdir(exist_ok=True)
    text = size_images(md_path.read_text(), track)
    with tempfile.NamedTemporaryFile("w", suffix=".md", dir=track, delete=False) as t:
        t.write(text)
        tmp = pathlib.Path(t.name)
    out = out_dir / (md_path.stem + ".docx")
    try:
        subprocess.run(
            ["pandoc", str(tmp), "-o", str(out),
             "--reference-doc", str(reference),
             "--from", "markdown+pipe_tables+implicit_figures"
                       "+backtick_code_blocks+bracketed_spans",
             "--highlight-style=tango",
             "--resource-path", str(track)],
            check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as e:
        print(f"  FAILED {md_path.name}: {e.stderr.strip()[:300]}")
        return None
    finally:
        tmp.unlink(missing_ok=True)
    return out


def tracks():
    """A track is any education/ subdirectory holding numbered chapters."""
    return sorted(d for d in EDUCATION.iterdir()
                  if d.is_dir() and any(d.glob(CHAPTER_GLOB)))


def resolve_track(name):
    """Named explicitly, always. Defaulting here would silently build the
    wrong track the moment a second one exists."""
    track = EDUCATION / name
    if not track.is_dir():
        sys.exit(f"no such track: {name}\n"
                 f"available: {', '.join(t.name for t in tracks()) or '(none)'}")
    if not any(track.glob(CHAPTER_GLOB)):
        sys.exit(f"{name} holds no {CHAPTER_GLOB} files")
    return track


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        sys.exit(__doc__.strip().split("Usage:")[-1].strip())
    if args[0] == "--list":
        for t in tracks():
            print(f"  {t.name:<24}{len(list(t.glob(CHAPTER_GLOB)))} chapters")
        return

    track = resolve_track(args[0])
    wanted = [a.lstrip("0") for a in args[1:] if a.isdigit()]

    ref_path = track / "scratch" / "docx" / "reference.docx"
    ref_path.parent.mkdir(parents=True, exist_ok=True)
    reference = build_reference(ref_path)
    print(f"track: {track.name}\n"
          f"reference: {reference.relative_to(track)}  "
          f"({COL_IN:.2f}in column, {BODY_FONT} 11pt single-spaced)\n")

    for md in sorted(track.glob(CHAPTER_GLOB)):
        n = re.search(r"chapter(\d+)", md.name).group(1).lstrip("0")
        if wanted and n not in wanted:
            continue
        out = build_chapter(md, reference, track)
        if out:
            print(f"  {md.name:<36}-> docx/{out.name}  ({out.stat().st_size//1024} KB)")


if __name__ == "__main__":
    main()
