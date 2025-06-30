const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

pub const TextConfig = struct{
    font: ?rl.Font = null
};

pub const ActiveTextStyle = struct{
    font_size: i32,
};

pub const UiState = struct{
    text_config: TextConfig,
    active_text_style: ActiveTextStyle,
};

