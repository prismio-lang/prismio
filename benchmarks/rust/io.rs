use std::fs;

use crate::common::{next_random, BENCH_MOD};

fn byte_sum(text: &[u8]) -> i32 {
    let mut checksum = 0; for byte in text { checksum = (checksum + *byte as i32) % BENCH_MOD; } checksum + text.len() as i32
}

pub fn file_read(path: &str) -> i32 { fs::read(path).map(|text| byte_sum(&text)).unwrap_or(-1) }

pub fn file_write(scale: i32, path: &str) -> i32 {
    let content = "0123456789abcdef\n".repeat((4096*scale) as usize);
    if fs::write(path, &content).is_ok() { byte_sum(content.as_bytes()) } else { -1 }
}

pub fn line_processing(path: &str) -> i32 {
    let text = match fs::read_to_string(path) { Ok(text) => text, Err(_) => return -1 };
    let lines: Vec<String> = text.split_terminator('\n').map(|raw| raw.strip_suffix('\r').unwrap_or(raw).to_string()).collect();
    let mut checksum = 0;
    for line in &lines { let as_count = line.bytes().filter(|b| *b == b'a').count() as i32; checksum = (checksum + line.len() as i32*31 + as_count)%BENCH_MOD; }
    checksum + lines.len() as i32
}

fn alpha(c:u8)->bool {(c>=b'a'&&c<=b'z')||(c>=b'A'&&c<=b'Z')}
fn digit(c:u8)->bool {c>=b'0'&&c<=b'9'}
fn space(c:u8)->bool {c==b' '||c==b'\t'||c==b'\n'||c==b'\r'}

pub fn tokenization(scale:i32)->i32 {
    let text="let value_17 = alpha + beta * 17;\n".repeat((1500*scale) as usize); let bytes=text.as_bytes(); let mut position=0; let mut tokens=0; let mut checksum=0;
    while position<bytes.len() { let c=bytes[position]; if space(c){position+=1;continue;} let start=position;
        if alpha(c)||c==b'_' {position+=1;while position<bytes.len()&&(alpha(bytes[position])||digit(bytes[position])||bytes[position]==b'_'){position+=1;}}
        else if digit(c){position+=1;while position<bytes.len()&&digit(bytes[position]){position+=1;}} else {position+=1;}
        let token=text[start..position].to_string(); tokens+=1; checksum=(checksum+token.len() as i32*tokens)%BENCH_MOD;
    } checksum+tokens
}

pub fn base64_codec(scale: i32) -> i32 {
    let n = 30000 * scale;
    let mut input = Vec::with_capacity(n as usize);
    let mut seed = 17;
    for _ in 0..n {
        seed = next_random(seed);
        input.push((seed % 256) as u8);
    }

    const B64_CHARS: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let encoded_len = ((n / 3) * 4) as usize;
    let mut encoded = vec![0u8; encoded_len];

    let mut j = 0;
    for i in (0..n as usize).step_by(3) {
        let b0 = input[i] as u32;
        let b1 = input[i + 1] as u32;
        let b2 = input[i + 2] as u32;

        encoded[j] = B64_CHARS[(b0 >> 2) as usize];
        encoded[j + 1] = B64_CHARS[(((b0 & 3) << 4) | (b1 >> 4)) as usize];
        encoded[j + 2] = B64_CHARS[(((b1 & 15) << 2) | (b2 >> 6)) as usize];
        encoded[j + 3] = B64_CHARS[(b2 & 63) as usize];
        j += 4;
    }

    let mut inv = [0u8; 256];
    for (i, &b) in B64_CHARS.iter().enumerate() {
        inv[b as usize] = i as u8;
    }

    let mut decoded = vec![0u8; n as usize];
    let mut di = 0;
    for i in (0..encoded_len).step_by(4) {
        let c0 = inv[encoded[i] as usize] as u32;
        let c1 = inv[encoded[i + 1] as usize] as u32;
        let c2 = inv[encoded[i + 2] as usize] as u32;
        let c3 = inv[encoded[i + 3] as usize] as u32;

        decoded[di] = ((c0 << 2) | (c1 >> 4)) as u8;
        decoded[di + 1] = (((c1 & 15) << 4) | (c2 >> 2)) as u8;
        decoded[di + 2] = (((c2 & 3) << 6) | c3) as u8;
        di += 3;
    }

    let mut checksum: i64 = 0;
    for &b in &decoded {
        checksum = (checksum * 31 + b as i64) % BENCH_MOD as i64;
    }
    ((checksum + encoded_len as i64) % BENCH_MOD as i64) as i32
}

pub fn csv_parse(scale: i32) -> i32 {
    let rows = 2500 * scale;
    let mut csv_data = String::with_capacity((rows * 60) as usize);

    let mut seed = 61;
    for r in 0..rows {
        seed = next_random(seed);
        let id = 1000 + (seed % 9000);
        seed = next_random(seed);
        let amount = seed % 10000;
        seed = next_random(seed);
        let score = seed % 100;

        let name_str = if r % 3 == 0 {
            format!("\"User \"\"Super\"\" {}\",", r % 100)
        } else {
            format!("User_{},", r % 500)
        };

        let status_str = if r % 2 == 0 { "active" } else { "pending" };
        csv_data.push_str(&format!("{id},{name_str}{amount},{status_str},{score}\n"));
    }

    let bytes = csv_data.as_bytes();
    let mut sum_id: i64 = 0;
    let mut sum_len: i64 = 0;
    let mut sum_amount: i64 = 0;
    let mut sum_status: i64 = 0;
    let mut sum_score: i64 = 0;

    let mut col = 0;
    let mut field_int: i64 = 0;
    let mut field_len: i64 = 0;
    let mut in_quote = false;

    let mut pos = 0;
    let n = bytes.len();
    while pos < n {
        let b = bytes[pos];
        if b == b'"' {
            if in_quote && pos + 1 < n && bytes[pos + 1] == b'"' {
                field_len += 1;
                pos += 2;
                continue;
            } else {
                in_quote = !in_quote;
            }
        } else if !in_quote && (b == b',' || b == b'\n') {
            if col == 0 { sum_id = (sum_id + field_int) % BENCH_MOD as i64; }
            else if col == 1 { sum_len = (sum_len + field_len) % BENCH_MOD as i64; }
            else if col == 2 { sum_amount = (sum_amount + field_int) % BENCH_MOD as i64; }
            else if col == 3 { sum_status = (sum_status + field_len) % BENCH_MOD as i64; }
            else if col == 4 { sum_score = (sum_score + field_int) % BENCH_MOD as i64; }

            field_int = 0;
            field_len = 0;
            col = if b == b',' { col + 1 } else { 0 };
        } else {
            if b >= b'0' && b <= b'9' {
                field_int = field_int * 10 + (b - b'0') as i64;
            }
            field_len += 1;
        }
        pos += 1;
    }

    let checksum = (sum_id * 10007 + sum_len * 31 + sum_amount * 17 + sum_status * 13 + sum_score) % BENCH_MOD as i64;
    checksum as i32
}
