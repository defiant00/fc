const Color = @This();

r: u8,
g: u8,
b: u8,
a: u8,

pub const transparent = from8888(0, 0, 0, 0);
pub const black = from888(0, 0, 0);
pub const white = from888(0xff, 0xff, 0xff);

pub const pico8 = [_]Color{
    from888(0, 0, 0), // black
    from888(29, 43, 83), // dark blue
    from888(126, 37, 83), // dark purple
    from888(0, 135, 81), // dark green
    from888(171, 82, 54), // brown
    from888(95, 87, 79), // dark grey
    from888(194, 195, 199), // light grey
    from888(255, 241, 232), // white
    from888(255, 0, 77), // red
    from888(255, 163, 0), // orange
    from888(255, 236, 39), // yellow
    from888(0, 228, 54), // green
    from888(41, 173, 255), // blue
    from888(131, 118, 156), // lavender
    from888(255, 119, 168), // pink
    from888(255, 204, 170), // light peach
};

fn toByte(val: u5) u8 {
    return (@as(u8, val) << 3) | (val >> 2);
}

pub fn from16(c: u16) Color {
    return .{
        .r = toByte(@intCast(c & 0x1f)),
        .g = toByte(@intCast((c >> 5) & 0x1f)),
        .b = toByte(@intCast((c >> 10) & 0x1f)),
        .a = if ((c >> 15) > 0) 0xff else 0,
    };
}

pub fn from555(r: u5, g: u5, b: u5) Color {
    return from5551(r, g, b, 1);
}

pub fn from5551(r: u5, g: u5, b: u5, a: u1) Color {
    return .{
        .r = toByte(r),
        .g = toByte(g),
        .b = toByte(b),
        .a = if (a > 0) 0xff else 0,
    };
}

pub fn from888(r: u8, g: u8, b: u8) Color {
    return from8888(r, g, b, 0xff);
}

pub fn from8888(r: u8, g: u8, b: u8, a: u8) Color {
    const qr = r >> 3;
    const qg = g >> 3;
    const qb = b >> 3;
    const qa = a >> 7;
    return .{
        .r = (qr << 3) | (qr >> 2),
        .g = (qg << 3) | (qg >> 2),
        .b = (qb << 3) | (qb >> 2),
        .a = if (qa > 0) 0xff else 0,
    };
}

pub fn to5551(r: u8, g: u8, b: u8, a: u8) u16 {
    const r16: u16 = r >> 3;
    const g16: u16 = g >> 3;
    const b16: u16 = b >> 3;
    const a16: u16 = a >> 7;
    return r16 | (g16 << 5) | (b16 << 10) | (a16 << 15);
}
