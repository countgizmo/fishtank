const std = @import("std");
const rl = @import("../raylib.zig").rl;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Allocator = std.mem.Allocator;

pub const TextConfig = struct {
    font: rl.Font,
};

pub const ActiveTextStyle = struct {
    font_size: i32,
};

pub const ActiveModel = struct {
    x: f32,
    y: f32,
};

pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const WidgetFlags = packed struct {
    has_border: bool = false,
    has_background: bool = false,
    has_text: bool = false,
    show_hover_effect: bool = false,
};

pub const Widget = struct{
    rect: Rect,
    flags: WidgetFlags,
    text: ?[]const u8 = null,
    id: ?[]const u8 = null,
};

pub const LayoutType = enum {
    Free,
    Row,
    Column,
};

pub const UiState = struct {
    text_config: TextConfig,
    active_text_style: ActiveTextStyle,
    margin: i32 = 10,
    next_x: f32 = 0,
    next_y: f32 = 0,
    container_x: f32 = 0,
    container_y: f32 = 0,
    container_width: f32 = 0,
    container_height: f32 = 0,
    treemap_item_clicked: ?usize = null,
    active_modal: ?ActiveModel = null,
    max_scroll: usize = 0,
    scroll_offset: f32 = 0,
    padding: f32 = 10,
    layout_type: LayoutType = .Free,
    parentStack: ArrayList(usize) = .empty,
    cache: StringHashMap(Rect),


    pub fn reset(self: *UiState) void {
        self.next_x = 0;
        self.next_y = 0;
    }

    pub fn getXFloat(self: *UiState, width: f32) f32 {
        const x = self.next_x + self.padding;

        if (self.layout_type == .Row) {
            self.next_x = self.next_x + width + self.padding;
        }

        return x;
    }

    pub fn getYFloat(self: *UiState, height: f32) f32 {
        const y = self.next_y + self.padding;

        if (self.layout_type == .Column) {
            self.next_y = self.next_y + height + self.padding;
        }

        return y;
    }

    pub fn rowStart(self: *UiState) void {
        self.layout_type = .Row;
    }

    pub fn rowEnd(self: *UiState) void {
        self.layout_type = .Free;
    }

    pub fn deinite(self: *UiState, allocator: Allocator) void {
        self.parentStack.deinit(allocator);
    }
};

