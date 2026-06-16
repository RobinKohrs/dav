#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "beautifulsoup4",
# ]
# ///

# ---
# Converts Apple Mail exports to clean plain text or Markdown, ready for LLM ingestion.
#
# Supports:
#   .mbox / .mbox directory  — exported mailbox (File → Export Mailbox)
#   .eml                     — single message (drag mail to Finder)
#
# Output formats:
#   txt (default)  — plain text, backward-compatible
#   md             — Markdown with YAML frontmatter per message; auto-detected
#                    when output file ends in .md
#   split-md       — one .md file per email, sorted into YYYY-MM/ subdirs
#
# Usage:
#   dav_mbox_to_text <file.mbox|file.eml> [-o output.md]
#   dav_mbox_to_text mail.mbox | llm "summarize"
#
#   # Recommended for wiki vault — one .md per email, wikilink-ready:
#   dav_mbox_to_text mail.mbox --split-dir ~/vault/work/sources/emails/
#   dav_mbox_to_text message.eml --split-dir ~/vault/work/sources/emails/
# ---

import argparse
import email
import mailbox
import os
import re
import sys
from email.header import decode_header, make_header
from bs4 import BeautifulSoup

SEPARATOR = "\n\n=========================\n\n"

# ---------- helpers -----------------------------------------------------------

def _decode_header(raw):
    """Decode a potentially MIME-encoded (RFC 2047) header field like =?utf-8?B?...?=."""
    if not raw:
        return ""
    try:
        return str(make_header(decode_header(raw)))
    except Exception:
        return str(raw)


def _parse_date(date_str):
    """Return (ISO date string, datetime) or ("", None) on failure."""
    if not date_str:
        return "", None
    from email.utils import parsedate_to_datetime
    try:
        dt = parsedate_to_datetime(date_str)
        return dt.strftime("%Y-%m-%d"), dt
    except Exception:
        return "", None


def _slugify(text, max_len=60):
    """Lowercase, strip special chars, collapse spaces to hyphens."""
    text = text.lower()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text.strip())
    return text[:max_len].rstrip("-")


# Robin's employer signatures — see ~/vault/work/profil.md
_DST_SIGNALS = (
    "@derstandard.at",
    "team daten & interaktiv",
    "der standard",
    "standard verlagsgesellschaft",
    "vordere zollamtsstr",
)
_NDR_SIGNALS = (
    "@ndr.de",
    "ndr data",
    "norddeutscher rundfunk",
    "rothenbaumchaussee",
)
_ROBIN_FROM_RE = re.compile(
    r"(?:from|von):\s*[^<\n]*?(?:kohrs,\s*robin|kohrs\s+robin|robin\s+kohrs)"
    r"[^<\n]*<[^>]*(?:derstandard\.at|ndr\.de|gmx\.de)[^>]*>",
    re.IGNORECASE,
)


def detect_robin_context(msg, body):
    """
    Detect whether Robin appears as sender and which employer context applies.

    Returns (employer, robin_outbound) where employer is 'dst', 'ndr', or None.
    Scans From header and full body (including quoted threads).
    """
    from_header = (msg.get("from", "") or "").lower()
    text = f"{from_header}\n{body}".lower()

    robin_outbound = bool(
        _ROBIN_FROM_RE.search(text)
        or "kohrs, robin" in text
        or "kohrs robin" in text
        or re.search(r"robin\.kohrs@", text)
        or re.search(r"r\.kohrs\.fm@", text)
    )

    ndr_score = sum(1 for s in _NDR_SIGNALS if s in text)
    dst_score = sum(1 for s in _DST_SIGNALS if s in text)

    # Strong header signals
    if "@ndr.de" in from_header or "r.kohrs.fm@" in text:
        ndr_score += 2
    if "derstandard.at" in from_header or "robin.kohrs@derstandard" in text:
        dst_score += 2

    if ndr_score > dst_score and ndr_score >= 1:
        return "ndr", robin_outbound
    if dst_score > ndr_score and dst_score >= 1:
        return "dst", robin_outbound
    if ndr_score == dst_score and ndr_score >= 1:
        if "@ndr.de" in from_header or "r.kohrs.fm@" in text:
            return "ndr", robin_outbound
        if "derstandard" in from_header:
            return "dst", robin_outbound
    return None, robin_outbound


def extract_body(msg):
    body = ""
    if msg.is_multipart():
        for part in msg.walk():
            ctype = part.get_content_type()
            if ctype == "text/plain":
                payload = part.get_payload(decode=True)
                if payload:
                    body += payload.decode(errors="ignore")
            elif ctype == "text/html" and not body:
                payload = part.get_payload(decode=True)
                if payload:
                    html = payload.decode(errors="ignore")
                    body += BeautifulSoup(html, "html.parser").get_text()
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            body += payload.decode(errors="ignore")
    return body.strip()


# ---------- text format -------------------------------------------------------

def write_message_txt(msg, out):
    subject = _decode_header(str(msg.get("subject", "") or ""))
    sender  = _decode_header(str(msg.get("from", "") or ""))
    date    = msg.get("date", "")
    body    = extract_body(msg)
    out.write(f"SUBJECT: {subject}\n")
    out.write(f"FROM: {sender}\n")
    out.write(f"DATE: {date}\n\n")
    out.write(body)
    out.write(SEPARATOR)


# ---------- markdown format ---------------------------------------------------

def write_message_md(msg, out, message_index=0, total_messages=1):
    """
    Write a single email as a Markdown document.

    For single-message output (total_messages == 1): proper YAML frontmatter.
    For multi-message output: H2 section header per message, shared frontmatter
    at top of file is written by the caller (convert_mbox_md).
    """
    subject  = _decode_header(str(msg.get("subject", "") or "")).strip()
    sender   = _decode_header(str(msg.get("from",    "") or "")).strip()
    date_raw = str(msg.get("date",    "") or "").strip()
    iso_date, _dt = _parse_date(date_raw)
    body = extract_body(msg)
    employer, robin_outbound = detect_robin_context(msg, body)

    if total_messages == 1:
        # Full frontmatter for a standalone email file
        safe_subject = subject.replace('"', "'")
        safe_sender  = sender.replace('"', "'")
        out.write("---\n")
        out.write("type: source-email\n")
        out.write(f'from: "{safe_sender}"\n')
        out.write(f'subject: "{safe_subject}"\n')
        out.write(f'date: "{date_raw}"\n')
        if iso_date:
            out.write(f"date_iso: {iso_date}\n")
        if employer:
            out.write(f"employer: {employer}\n")
        if robin_outbound:
            out.write("robin_outbound: true\n")
        out.write("ingested: false\n")
        out.write("tags: []\n")
        out.write("---\n\n")
        out.write(f"# {subject}\n\n")
        out.write(f"**Von:** {sender}  \n")
        out.write(f"**Datum:** {date_raw}\n\n")
        out.write("---\n\n")
        out.write(body)
        out.write("\n")
    else:
        # Section inside a multi-message file
        heading = subject if subject else f"Nachricht {message_index + 1}"
        out.write(f"\n## {heading}\n\n")
        out.write(f"**Von:** {sender}  \n")
        out.write(f"**Datum:** {date_raw}\n\n")
        out.write("---\n\n")
        out.write(body)
        out.write("\n")


def write_collection_frontmatter(out, path, count, first_msg=None):
    """Write YAML frontmatter for a multi-message markdown file."""
    basename = os.path.basename(path)
    subject = ""
    sender  = ""
    if first_msg:
        subject = _decode_header(str(first_msg.get("subject", "") or "")).strip()
        sender  = _decode_header(str(first_msg.get("from",    "") or "")).strip()
    out.write("---\n")
    out.write("type: source-email-collection\n")
    out.write(f"source_file: \"{basename}\"\n")
    out.write(f"message_count: {count}\n")
    if sender:
        out.write(f'from: "{sender.replace(chr(34), chr(39))}"\n')
    if subject:
        out.write(f'first_subject: "{subject.replace(chr(34), chr(39))}"\n')
    out.write("ingested: false\n")
    out.write("tags: []\n")
    out.write("---\n\n")


# ---------- converters --------------------------------------------------------

def convert_eml(eml_path, out, fmt="txt"):
    with open(eml_path, "rb") as f:
        msg = email.message_from_bytes(f.read())
    if fmt == "md":
        write_message_md(msg, out, message_index=0, total_messages=1)
    else:
        write_message_txt(msg, out)
    return 1, 0


def convert_mbox(mbox_path, out, fmt="txt"):
    mb = mailbox.mbox(mbox_path)
    count  = 0
    errors = 0

    if fmt == "md":
        # Two-pass: count messages and get first for frontmatter
        messages = []
        for msg in mb:
            messages.append(msg)
        total = len(messages)
        write_collection_frontmatter(out, mbox_path, total,
                                     first_msg=messages[0] if messages else None)
        for i, msg in enumerate(messages):
            try:
                write_message_md(msg, out, message_index=i, total_messages=total)
                count += 1
            except Exception as e:
                errors += 1
                print(f"[warning] skipped message {i}: {e}", file=sys.stderr)
    else:
        for msg in mb:
            try:
                write_message_txt(msg, out)
                count += 1
            except Exception as e:
                errors += 1
                print(f"[warning] skipped a message: {e}", file=sys.stderr)

    return count, errors


def convert(path, out, fmt="txt"):
    if os.path.isfile(path) and path.lower().endswith(".eml"):
        return convert_eml(path, out, fmt=fmt)
    # Apple Mail exports .mbox as a bundle directory; the actual mbox data is inside
    if os.path.isdir(path):
        inner = os.path.join(path, "mbox")
        if os.path.isfile(inner):
            path = inner
        else:
            print(f"[error] Directory passed but no 'mbox' file found inside: {path}",
                  file=sys.stderr)
            return 0, 1
    return convert_mbox(path, out, fmt=fmt)


def convert_split(path, split_dir):
    """
    Write one .md file per email to split_dir/YYYY-MM/YYYY-MM-DD_slug.md.
    Creates subdirectories automatically. Returns (count, errors).
    """
    import email as _email

    os.makedirs(split_dir, exist_ok=True)

    def _write_one(msg):
        subject  = _decode_header(str(msg.get("subject", "") or "")).strip()
        date_raw = str(msg.get("date",    "") or "").strip()
        iso_date, _dt = _parse_date(date_raw)
        date_prefix = iso_date if iso_date else "0000-00-00"
        month_dir = os.path.join(split_dir, date_prefix[:7])   # YYYY-MM
        os.makedirs(month_dir, exist_ok=True)

        slug = _slugify(subject, max_len=55) or "no-subject"
        base = f"{date_prefix}_{slug}"
        # Avoid collisions
        candidate = os.path.join(month_dir, f"{base}.md")
        n = 2
        while os.path.exists(candidate):
            candidate = os.path.join(month_dir, f"{base}_{n}.md")
            n += 1

        with open(candidate, "w", encoding="utf-8") as f:
            write_message_md(msg, f, message_index=0, total_messages=1)
        return candidate

    count = 0
    errors = 0

    if os.path.isfile(path) and path.lower().endswith(".eml"):
        with open(path, "rb") as f:
            msg = _email.message_from_bytes(f.read())
        try:
            out_path = _write_one(msg)
            count = 1
            print(f"  → {out_path}", file=sys.stderr)
        except Exception as e:
            errors = 1
            print(f"[warning] skipped: {e}", file=sys.stderr)
    else:
        # mbox / bundle directory
        mbox_path = path
        if os.path.isdir(path):
            inner = os.path.join(path, "mbox")
            if os.path.isfile(inner):
                mbox_path = inner
            else:
                print(f"[error] No 'mbox' file found in: {path}", file=sys.stderr)
                return 0, 1
        mb = mailbox.mbox(mbox_path)
        for i, msg in enumerate(mb):
            try:
                out_path = _write_one(msg)
                count += 1
                print(f"  [{count}] → {out_path}", file=sys.stderr)
            except Exception as e:
                errors += 1
                print(f"[warning] skipped message {i}: {e}", file=sys.stderr)

    return count, errors


# ---------- main --------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description=(
            "Convert Apple Mail exports (.mbox or .eml) to plain text or Markdown. "
            "Output format is auto-detected from the -o filename extension "
            "(.md → Markdown with frontmatter, anything else → plain text). "
            "Use --split-dir to write one .md file per email to a directory."
        )
    )
    parser.add_argument("input",  help="Path to .mbox directory or .eml file")
    parser.add_argument("-o", "--output",
                        help="Write output to this file (default: stdout)")
    parser.add_argument("--split-dir", metavar="DIR",
                        help=(
                            "Write one .md file per email to DIR/YYYY-MM/YYYY-MM-DD_slug.md. "
                            "Ideal for sources/emails/ in the wiki vault."
                        ))
    parser.add_argument("--format", choices=["txt", "md"], default=None,
                        help="Output format. Default: auto-detect from -o extension.")
    args = parser.parse_args()

    # --split-dir mode: one .md per email
    if args.split_dir:
        count, errors = convert_split(args.input, args.split_dir)
        print(f"Done: {count} email(s) written to {args.split_dir} [split-md]",
              file=sys.stderr)
        if errors:
            print(f"Skipped {errors} messages due to errors.", file=sys.stderr)
        return

    # Determine format
    if args.format:
        fmt = args.format
    elif args.output and args.output.lower().endswith(".md"):
        fmt = "md"
    else:
        fmt = "txt"

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            count, errors = convert(args.input, f, fmt=fmt)
        print(f"Done: {count} email(s) written to {args.output} [{fmt}]",
              file=sys.stderr)
        if errors:
            print(f"Skipped {errors} messages due to errors.", file=sys.stderr)
    else:
        count, errors = convert(args.input, sys.stdout, fmt=fmt)
        print(f"\nDone: {count} email(s) written to stdout [{fmt}].", file=sys.stderr)
        if errors:
            print(f"Skipped {errors} messages due to errors.", file=sys.stderr)


if __name__ == "__main__":
    main()
