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

pub const Layout = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    padding: f32,
    gap: f32 = 0,
    type: LayoutType = .Free,
    next_x: ?f32 = null,
    next_y: ?f32 = null,
    children: ArrayList([]const u8) = ArrayList([]const u8).empty,

    pub fn getXFloat(self: *Layout, width: f32) f32 {
        if (self.next_x) |next_x| {
            const x = next_x;
            if (self.type == .Row) {
                self.next_x = x + width;
            }
            return x + self.padding + self.gap;
        } else {
            self.next_x = self.x + width;
            return self.x + self.padding;
        }
    }

    pub fn getYFloat(self: *Layout, height: f32) f32 {
        if (self.next_y) |next_y| {
            if (self.type == .Column) {
                self.next_y = next_y + height + self.padding;
            }
            return self.next_y.? + self.padding;
        } else {
            self.next_y = self.y;
            return self.y + self.padding;
        }
    }

    pub fn getWidth(self: *Layout) f32 {
        return self.width - (self.padding * 2);
    }

    pub fn getHeight(self: *Layout) f32 {
        return self.height - (self.padding * 2);
    }

    pub fn registerAsChild(self: *Layout, allocator: Allocator, id: []const u8) !void {
        try self.children.append(allocator, id);
    }
};

pub const UiState = struct {
    text_config: TextConfig,
    active_text_style: ActiveTextStyle,
    treemap_item_clicked: ?usize = null,
    active_modal: ?ActiveModel = null,
    max_scroll: usize = 0,
    scroll_offset: f32 = 0,

    arena: std.heap.ArenaAllocator,
    cache: StringHashMap(Rect),
    layout_stack: ArrayList(*Layout) = ArrayList(*Layout).empty,
    current_layout_idx: usize = 0,

    pub fn pushLayout(self: *UiState, layout: *Layout) !void {
        if (self.layout_stack.items.len > 0) {
            self.current_layout_idx += 1;
        }

        try self.layout_stack.append(self.arena.allocator(), layout);
    }

    pub fn popLayout(self: *UiState) void {
        if (self.current_layout_idx > 0) {
            self.current_layout_idx -= 1;
        }
    }

    pub fn currentLayout(self: UiState) *Layout {
        return self.layout_stack.items[self.current_layout_idx];
    }

    pub fn reset(self: *UiState) void {
        _ = self.arena.reset(.retain_capacity);
        self.layout_stack = .empty;
    }

    pub fn deinite(self: *UiState, allocator: Allocator) void {
        self.parentStack.deinit(allocator);
    }
};

