const std = @import("std");
const rl = @import("../raylib.zig").rl;

pub const TextConfig = struct{
    font: rl.Font,
};

pub const ActiveTextStyle = struct{
    font_size: i32,
};

pub const UiState = struct{
    text_config: TextConfig,
    active_text_style: ActiveTextStyle,
    margin: i32 = 10,
    next_x: i32 = 0,
    next_y: i32 = 0,
};

