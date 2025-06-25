const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

pub const TextConfig = struct{
    font: ?rl.Font = null
};

pub const UiState = struct{
    text_config: TextConfig,
};

