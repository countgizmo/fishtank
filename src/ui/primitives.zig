const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

pub const bg_color = rl.Color{
    .r = 232,
    .g = 232,
    .b = 232,
    .a = 255
};

pub const fg_color = rl.Color{
    .r = 42,
    .g = 42,
    .b = 42,
    .a = 255
};
