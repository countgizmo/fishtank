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
    next_x: f32 = 0 ,
    next_y: f32 = 0,
    id: []const u8,

    pub fn getXFloat(self: *Layout, width: f32) f32 {
        const x = self.next_x;
        if (self.type == .Row) {
            self.next_x = x + width + self.gap;
        }
        return x;
    }

    pub fn getYFloat(self: *Layout, height: f32) f32 {
        const y = self.next_y;
        if (self.type == .Column) {
            self.next_y = self.next_y + height + self.padding;
        }
        return y;
    }

    pub fn getWidth(self: *Layout) f32 {
        return self.width - (self.padding * 2);
    }

    pub fn getHeight(self: *Layout) f32 {
        return self.height - (self.padding * 2);
    }
};

pub const UiState = struct {
    pass: enum { measure, draw },
    text_config: TextConfig,
    active_text_style: ActiveTextStyle,
    treemap_item_clicked: ?usize = null,
    active_modal: ?ActiveModel = null,
    max_scroll: usize = 0,
    scroll_offset: f32 = 0,

    arena: std.heap.ArenaAllocator,
    layout_stack: ArrayList(*Layout) = .empty,
    children_by_layout: StringHashMap(ArrayList([]const u8)),
    cache: StringHashMap(Rect),

    pub fn addToCache(self: *UiState, key: []const u8, rect: Rect) !void {
        try self.cache.put(key, rect);
    }

    pub fn getFromCache(self: *UiState, key: []const u8) ?Rect{
        return self.cache.get(key);
    }

    pub fn pushLayout(self: *UiState, layout: *Layout) !void {
        try self.layout_stack.append(self.arena.allocator(), layout);
    }

    pub fn popLayout(self: *UiState) void {
        _ = self.layout_stack.pop();
    }

    pub fn currentLayout(self: UiState) *Layout {
        return self.layout_stack.items[self.layout_stack.items.len - 1];
    }

    pub fn registerAsChild(self: *UiState, child_id: []const u8) !void {
        const layout = self.currentLayout();
        const entry = try self.children_by_layout.getOrPut(layout.id);
        if (!entry.found_existing) entry.value_ptr.* = .empty;
        try entry.value_ptr.append(self.arena.allocator(), child_id);
    }


    pub fn reset(self: *UiState) void {
        _ = self.arena.reset(.retain_capacity);
        self.layout_stack = .empty;
        self.children_by_layout.clearRetainingCapacity();
    }

    pub fn deinite(self: *UiState, allocator: Allocator) void {
        self.parentStack.deinit(allocator);
    }
};

