pub fn get(c: char) -> Option<Vec<String>> {
    KEYS.iter()
        .filter_map(|x| {
            if x.char_normal == c {
                Some(x.normal_key_seq())
            } else if x.char_shifted == Some(c) {
                Some(x.shifted_key_seq())
            } else {
                None
            }
        })
        .map(|xs| xs.iter().map(|x| two_digit_hex(*x)).collect())
        .next()
}

struct Key {
    code: u8,
    char_normal: char,
    char_shifted: Option<char>,
}

impl Key {
    const fn new(code: u8, char_normal: char, char_shifted: Option<char>) -> Key {
        Key {
            code,
            char_normal,
            char_shifted,
        }
    }

    fn normal_key_seq(&self) -> Vec<u8> {
        vec![self.code, self.code + RELEASE_ADDR]
    }

    fn shifted_key_seq(&self) -> Vec<u8> {
        vec![
            LEFT_SHIFT_PRESSED,
            self.code,
            self.code + RELEASE_ADDR,
            LEFT_SHIFT_RELEASED,
        ]
    }
}

fn two_digit_hex(i: u8) -> String {
    format!("{:02x}", i)
}

const RELEASE_ADDR: u8 = 0x80;
const LEFT_SHIFT_PRESSED: u8 = 0x2a;
const LEFT_SHIFT_RELEASED: u8 = LEFT_SHIFT_PRESSED + RELEASE_ADDR;

// See http://www.win.tue.nl/~aeb/linux/kbd/scancodes-1.html
// Not a complete list here
const KEYS: [Key; 47] = [
    Key::new(0x1e, 'a', Some('A')),
    Key::new(0x30, 'b', Some('B')),
    Key::new(0x2e, 'c', Some('C')),
    Key::new(0x20, 'd', Some('D')),
    Key::new(0x12, 'e', Some('E')),
    Key::new(0x21, 'f', Some('F')),
    Key::new(0x22, 'g', Some('G')),
    Key::new(0x23, 'h', Some('H')),
    Key::new(0x17, 'i', Some('I')),
    Key::new(0x24, 'j', Some('J')),
    Key::new(0x25, 'k', Some('K')),
    Key::new(0x26, 'l', Some('L')),
    Key::new(0x32, 'm', Some('M')),
    Key::new(0x31, 'n', Some('N')),
    Key::new(0x18, 'o', Some('O')),
    Key::new(0x19, 'p', Some('P')),
    Key::new(0x10, 'q', Some('Q')),
    Key::new(0x13, 'r', Some('R')),
    Key::new(0x1f, 's', Some('S')),
    Key::new(0x14, 't', Some('T')),
    Key::new(0x16, 'u', Some('U')),
    Key::new(0x2f, 'v', Some('V')),
    Key::new(0x11, 'w', Some('W')),
    Key::new(0x2d, 'x', Some('X')),
    Key::new(0x15, 'y', Some('Y')),
    Key::new(0x2c, 'z', Some('Z')),
    Key::new(0x02, '1', Some('!')),
    Key::new(0x03, '2', Some('@')),
    Key::new(0x04, '3', Some('#')),
    Key::new(0x05, '4', Some('$')),
    Key::new(0x06, '5', Some('%')),
    Key::new(0x07, '6', Some('^')),
    Key::new(0x08, '7', Some('&')),
    Key::new(0x09, '8', Some('*')),
    Key::new(0x0a, '9', Some('(')),
    Key::new(0x0b, '0', Some(')')),
    Key::new(0x27, ';', Some(':')),
    Key::new(0x0c, '-', Some('_')),
    Key::new(0x0d, '=', Some('+')),
    Key::new(0x2b, '\\', Some('|')),
    Key::new(0x29, '`', Some('~')),
    Key::new(0x33, ',', Some('<')),
    Key::new(0x34, '.', Some('>')),
    Key::new(0x35, '/', Some('?')),
    Key::new(0x28, '\'', Some('"')),
    Key::new(0x39, ' ', None),
    Key::new(0x1c, '\n', None),
];
