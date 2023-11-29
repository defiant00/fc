const Self = @This();

r: u8,
g: u8,
b: u8,
a: u8,

//   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
//   0   8  16  24  33  41  49  57  66  74  82  90  99 107 115 123

//  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31
// 132 140 148 156 165 173 181 189 198 206 214 222 231 239 247 255

pub const black = from555(0, 0, 0);
pub const white = from555(31, 31, 31);

pub const pico8 = [_]Self{
    from555(0, 0, 1), // black
    from555(4, 5, 10), // dark blue
    from555(15, 4, 10), // dark purple
    from555(0, 16, 10), // dark green
    from555(21, 10, 7), // brown
    from555(12, 11, 10), // dark grey
    from555(24, 24, 24), // light grey
    from555(31, 29, 28), // white
    from555(31, 0, 9), // red
    from555(31, 20, 0), // orange
    from555(31, 29, 5), // yellow
    from555(0, 28, 7), // green
    from555(5, 21, 31), // blue
    from555(16, 14, 19), // lavender
    from555(31, 14, 20), // pink
    from555(31, 25, 21), // light peach
};

fn toByte(val: u5) u8 {
    return (@as(u8, val) << 3) | (val >> 2);
}

fn toColor(r: u5, g: u5, b: u5, a: u1) u16 {
    return r | (@as(u16, g) << 5) | (@as(u16, b) << 10) | (@as(u16, a) << 15);
}

pub fn from555(r: u5, g: u5, b: u5) Self {
    return from5551(r, g, b, 1);
}

pub fn from5551(r: u5, g: u5, b: u5, a: u1) Self {
    return .{
        .r = toByte(r),
        .g = toByte(g),
        .b = toByte(b),
        .a = if (a > 0) 0xff else 0,
    };
}
