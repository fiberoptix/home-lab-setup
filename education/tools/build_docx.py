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
     education/scratch/figcheck.py, which reports the on-page size of the
     smallest type in every figure).
  2. Here, each image is given an explicit width -- the full 7in column --
     but capped so a tall figure still fits the 9in text height rather than
     overflowing onto the next page.

Usage:
    python3 build_docx.py            # build every chapter
    python3 build_docx.py 3 6        # build chapters 3 and 6 only
"""

import pathlib
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile

EDU = pathlib.Path(__file__).resolve().parent.parent
OUT = EDU / "docx"

# Letter page, 0.75in side margins, 1in top/bottom -> 7.0 x 9.0in of text.
PAGE_W_TWIPS, PAGE_H_TWIPS = 12240, 15840
MARGIN_X, MARGIN_Y = 1080, 1440
COL_IN = (PAGE_W_TWIPS - 2 * MARGIN_X) / 1440
TEXT_H_IN = (PAGE_H_TWIPS - 2 * MARGIN_Y) / 1440
FIG_MAX_H_IN = TEXT_H_IN - 0.6          # leave room for the caption

BODY_FONT, HEAD_FONT, MONO_FONT = "Cambria", "Calibri", "Consolas"
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"


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
    # The table of contents. Pandoc emits a Word TOC field and relies on the
    # reference doc for these three; the stock reference styles them in the
    # default theme font, which reads as a different document.
    "TOCHeading":    dict(font=HEAD_FONT, half_pt=28, bold=True, color="1F3864",
                          before=0, after=200),
    "TOC1":          dict(font=BODY_FONT, half_pt=22, bold=True, before=100, after=40),
    "TOC2":          dict(font=BODY_FONT, half_pt=21, after=40, indent=220),
}

CHAR_SPEC = {
    "VerbatimChar": f'<w:rFonts w:ascii="{MONO_FONT}" w:hAnsi="{MONO_FONT}" '
                    f'w:cs="{MONO_FONT}"/><w:sz w:val="19"/><w:szCs w:val="19"/>'
                    '<w:shd w:val="clear" w:fill="F2F2F2"/>',
}


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
        new = (f'<w:style w:type="character" w:styleId="{sid}">'
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


def patch_settings(xml):
    """Tell Word to evaluate fields when the document opens.

    Pandoc's --toc writes a real Word TOC *field*, not literal text, and a
    field carries a cached result that is displayed until something
    recalculates it. The cached result inherited from pandoc's stock reference
    document is the string "No table of contents entries found." -- so every
    chapter opened with that sitting at the top of page one, which is what
    this flag fixes. `fill_toc` below populates the cache as well, so the
    document still reads correctly in a viewer that ignores this.
    """
    if "<w:updateFields" in xml:
        return xml
    flag = '<w:updateFields w:val="true"/>'
    # CT_Settings is an ordered sequence, so this cannot simply be appended --
    # Word reports a corrupt file if the elements are out of schema order.
    # updateFields sits after savePreviewPicture and before footnotePr.
    for anchor in ("<w:footnotePr", "<w:endnotePr", "<w:compat",
                   "<w:docVars", "<w:rsids", "<m:mathPr", "<w:themeFontLang"):
        i = xml.find(anchor)
        if i != -1:
            return xml[:i] + flag + xml[i:]
    return xml.replace("</w:settings>", flag + "</w:settings>")


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
        stp = work / "word" / "settings.xml"
        stp.write_text(patch_settings(stp.read_text()), encoding="utf-8")
        with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
            for f in sorted(work.rglob("*")):
                if f.is_file():
                    z.write(f, f.relative_to(work))
    return dest


# ----------------------------------------------------------------- chapters

def size_images(md_text):
    """Give every image an explicit width: the full column, height-capped."""
    def repl(m):
        alt, rel = m.group(1), m.group(2)
        img = EDU / rel
        if not img.exists():
            return m.group(0)
        w, h = png_size(img)
        width = min(COL_IN, FIG_MAX_H_IN * w / h)
        return f'![{alt}]({rel}){{width={width:.2f}in}}'
    return re.sub(r"!\[([^\]]*)\]\((images/[^)]+\.png)\)", repl, md_text)


def xml_escape(s):
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def fill_toc(docx_path):
    """Give the TOC field a real cached result, and the headings anchors.

    Pandoc writes the table of contents as a Word *field*, which carries a
    cached result that is shown until something recalculates it. Left alone
    that cache is either empty or -- inherited from pandoc's stock reference
    document -- the string "No table of contents entries found.", which is
    what appeared at the top of page one of every chapter.

    `patch_settings` asks Word to recalculate on open, and pandoc marks the
    field dirty, so in Word the contents populate themselves. This function is
    the belt to those braces: it bookmarks every heading and writes the
    entries into the field's cached result, so the contents are present and
    clickable even in a reader that never evaluates a field. Word replaces the
    lot on open and adds the page numbers, which cannot be known here without
    laying the document out.
    """
    with zipfile.ZipFile(docx_path) as z:
        parts = {n: z.read(n) for n in z.namelist()}
    doc = parts["word/document.xml"].decode("utf-8")

    sdt = re.search(r'<w:sdt>(?:(?!</w:sdt>).)*?Table of Contents.*?</w:sdt>',
                    doc, re.S)
    if not sdt:
        return 0
    head, body_xml = doc[:sdt.start()], doc[sdt.end():]

    # Pandoc's own writer self-closes with a space (`<w:pStyle ... />`) while
    # the Word-authored reference does not, and which one produces a given
    # paragraph depends on the styles present. Tolerate both.
    style_re = re.compile(r'<w:pStyle w:val="Heading([12])"\s*/>')
    entries, seq = [], 0

    def anchor_heading(m):
        nonlocal seq
        p = m.group(0)
        lvl = style_re.search(p)
        if not lvl:
            return p
        text = "".join(re.findall(r"<w:t(?:\s[^>]*)?>(.*?)</w:t>", p, re.S))
        if not text.strip():
            return p
        seq += 1
        name = f"_Toc{9000 + seq}"
        entries.append((int(lvl.group(1)), name, text))
        mark = (f'<w:bookmarkStart w:id="{9000 + seq}" w:name="{name}"/>'
                f'<w:bookmarkEnd w:id="{9000 + seq}"/>')
        # After </w:pPr> so the bookmark sits inside the paragraph but ahead of
        # its runs; a heading always has a pPr because it carries pStyle.
        return p.replace("</w:pPr>", "</w:pPr>" + mark, 1)

    body_xml = re.sub(r"<w:p\b(?:(?!</w:p>).)*?</w:p>", anchor_heading,
                      body_xml, flags=re.S)
    if not entries:
        return 0

    def para(level, name, text, lead="", tail=""):
        return (f'<w:p><w:pPr><w:pStyle w:val="TOC{level}"/></w:pPr>{lead}'
                f'<w:hyperlink w:anchor="{name}">'
                f'<w:r><w:t xml:space="preserve">{xml_escape(text)}</w:t></w:r>'
                f'</w:hyperlink>{tail}</w:p>')

    # The field must stay well formed across the paragraphs it spans:
    # begin / instruction / separate open it, the entries are its result, and
    # exactly one end closes it.
    lead = ('<w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/>'
            '<w:instrText xml:space="preserve">TOC \\o "1-2" \\h \\z \\u</w:instrText>'
            '<w:fldChar w:fldCharType="separate"/></w:r>')
    tail = '<w:r><w:fldChar w:fldCharType="end"/></w:r>'

    paras = [para(*entries[0], lead=lead)]
    paras += [para(*e) for e in entries[1:-1]]
    if len(entries) > 1:
        paras.append(para(*entries[-1], tail=tail))
    else:
        paras[0] = paras[0][: -len("</w:p>")] + tail + "</w:p>"

    toc = ("<w:sdt><w:sdtPr><w:docPartObj>"
           '<w:docPartGallery w:val="Table of Contents"/><w:docPartUnique/>'
           "</w:docPartObj></w:sdtPr><w:sdtContent>"
           '<w:p><w:pPr><w:pStyle w:val="TOCHeading"/></w:pPr>'
           "<w:r><w:t>Contents</w:t></w:r></w:p>"
           + "".join(paras) +
           # Start the chapter on a fresh page rather than running straight on
           # from the contents list.
           '<w:p><w:pPr><w:spacing w:after="0"/></w:pPr>'
           '<w:r><w:br w:type="page"/></w:r></w:p>'
           "</w:sdtContent></w:sdt>")

    parts["word/document.xml"] = (head + toc + body_xml).encode("utf-8")
    with zipfile.ZipFile(docx_path, "w", zipfile.ZIP_DEFLATED) as z:
        for name, data in parts.items():
            z.writestr(name, data)
    return len(entries)


def build_chapter(md_path, reference):
    OUT.mkdir(exist_ok=True)
    text = size_images(md_path.read_text())
    with tempfile.NamedTemporaryFile("w", suffix=".md", dir=EDU, delete=False) as t:
        t.write(text)
        tmp = pathlib.Path(t.name)
    out = OUT / (md_path.stem + ".docx")
    try:
        subprocess.run(
            ["pandoc", str(tmp), "-o", str(out),
             "--reference-doc", str(reference),
             "--from", "markdown+pipe_tables+implicit_figures+backtick_code_blocks",
             "--toc", "--toc-depth=2", "--highlight-style=tango",
             "--resource-path", str(EDU)],
            check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as e:
        print(f"  FAILED {md_path.name}: {e.stderr.strip()[:300]}")
        return None, 0
    finally:
        tmp.unlink(missing_ok=True)
    return out, fill_toc(out)


def main():
    wanted = [a for a in sys.argv[1:] if a.isdigit()]
    reference = build_reference(EDU / "scratch" / "docx" / "reference.docx")
    print(f"reference: {reference.relative_to(EDU)}  "
          f"({COL_IN:.2f}in column, {BODY_FONT} 11pt single-spaced)\n")
    for md in sorted(EDU.glob("chapter0*.md")):
        n = re.search(r"chapter0(\d)", md.name).group(1)
        if wanted and n not in wanted:
            continue
        out, toc = build_chapter(md, reference)
        if out:
            print(f"  {md.name:<36}-> docx/{out.name}  "
                  f"({out.stat().st_size//1024} KB, {toc} contents entries)")


if __name__ == "__main__":
    main()
