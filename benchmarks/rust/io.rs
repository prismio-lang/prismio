use std::fs;

use crate::common::BENCH_MOD;

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
