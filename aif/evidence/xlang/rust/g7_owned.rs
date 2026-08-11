// G7 tokenizer -- the OWNED variant. A diagnostic, not a port.
//
// Identical to g7_idiomatic.rs except for one line: the token text is copied
// into a fresh allocation instead of borrowed. That is the same methodology
// g1_boxed.rs / g2_boxed.rs / g4_boxed.rs use for the container
// representation -- hold everything else fixed in ONE language, so the cost of
// a representation choice is priced without the backend gap mixed in.
//
// What this isolates: the malloc-and-copy that `str_substring` performs and a
// view would delete. What it deliberately does NOT include: `str_substring`
// also calls strlen over the *whole source buffer* on every call, which is a
// separate defect and is why the Prismio port is superlinear. Rust knows the
// length, so this variant is linear -- read the two costs apart, not together.

#[path = "harness.rs"]
mod harness;

const TK_IDENT: i64 = 1;
const TK_NUMBER: i64 = 2;
const TK_OPERATOR: i64 = 3;
const TK_PUNCT: i64 = 4;

const LINES: usize = 400;
const ITERATIONS: usize = 200;

fn is_digit(c: u8) -> bool {
    c >= b'0' && c <= b'9'
}

fn is_alpha(c: u8) -> bool {
    (c >= b'a' && c <= b'z') || (c >= b'A' && c <= b'Z') || c == b'_'
}

fn is_alnum(c: u8) -> bool {
    is_alpha(c) || is_digit(c)
}

fn is_space(c: u8) -> bool {
    c == b' ' || c == b'\t' || c == b'\n'
}

fn is_operator(c: u8) -> bool {
    matches!(c, b'+' | b'-' | b'*' | b'/' | b'=' | b'<' | b'>')
}

/// Byte-for-byte the same buffer prismio/g7.psm's buildSource produces. The
/// checksums would not agree otherwise, which is the point of asserting them.
fn build_source(lines: usize) -> String {
    let mut out = String::new();
    for i in 0..lines {
        let n = i % 97;
        out.push_str("let value_");
        out.push_str(&n.to_string());
        out.push_str(" = alpha_");
        out.push_str(&n.to_string());
        out.push_str(" + beta * ");
        out.push_str(&(n * 3).to_string());
        out.push_str(" - gamma_");
        out.push_str(&n.to_string());
        out.push_str(" / 7 ;\n");
    }
    out
}

fn tokenize(src: &[u8]) -> i64 {
    let src_len = src.len();
    let mut pos = 0usize;
    let mut sum: i64 = 0;
    let mut keywords: i64 = 0;
    let mut count: i64 = 0;

    while pos < src_len {
        let c = src[pos];

        if is_space(c) {
            pos += 1;
            continue;
        }

        let start = pos;
        let mut kind = TK_PUNCT;

        if is_alpha(c) {
            kind = TK_IDENT;
            while pos < src_len && is_alnum(src[pos]) {
                pos += 1;
            }
        } else if is_digit(c) {
            kind = TK_NUMBER;
            while pos < src_len && is_digit(src[pos]) {
                pos += 1;
            }
        } else {
            if is_operator(c) {
                kind = TK_OPERATOR;
            }
            pos += 1;
        }

        // The line the benchmark exists for. Copied, not borrowed.
        let text: Vec<u8> = src[start..pos].to_vec();

        if text.as_slice() == b"let" {
            keywords += 1;
        }
        sum += kind * (pos - start) as i64;
        count += 1;
    }

    sum + keywords * 1000 + count
}

fn main() {
    let src = build_source(LINES);
    let bytes = src.as_bytes();
    let mut frames = harness::Frames::new(ITERATIONS);
    let mut checksum: i64 = 0;

    for it in 0..ITERATIONS {
        let t0 = harness::now_ns();
        let s = tokenize(bytes);
        let t1 = harness::now_ns();
        checksum = s;
        frames.set(it, t1 - t0);
    }

    harness::report(
        &[("tokens", checksum), ("bytes", bytes.len() as i64)],
        &frames,
    );
}
