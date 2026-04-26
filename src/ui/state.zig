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
    free,
    row,
    column,
};

pub const Layout = struct {
    x: f32,
    y: f32,
    available_width: f32,
    available_height: f32,
    padding: f32,
    type: LayoutType = .free,
    id: []const u8,

    // pub fn getXFloat(self: *Layout, width: f32) f32 {
    //     const x = self.next_x;
    //     if (self.type == .Row) {
    //         self.next_x = x + width + self.gap;
    //     }
    //     return x;
    // }
    //
    // pub fn getYFloat(self: *Layout, height: f32) f32 {
    //     const y = self.next_y;
    //     if (self.type == .Column) {
    //         self.next_y = self.next_y + height + self.padding;
    //     }
    //     return y;
    // }
    //
    // pub fn getWidth(self: *Layout) f32 {
    //     return self.available_width - (self.padding * 2);
    // }
    //
    // pub fn getHeight(self: *Layout) f32 {
    //     return self.available_height - (self.padding * 2);
    // }


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

    pub fn getFromCache(self: UiState, key: []const u8) ?Rect{
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

    pub fn getNextX(self: UiState, for_id: []const u8) f32 {
        if (self.getFromCache(for_id)) |rect| {
            return rect.x;
        }

        const layout = self.currentLayout();

        switch (layout.type) {
            .column, .free => return layout.x + layout.padding,
            .row => {
                const children = self.children_by_layout.get(layout.id) orelse return layout.x + layout.padding;
                if (children.items.len == 0) return layout.x + layout.padding;

                var sum_width: f32 = 0;

                for (children.items) |child| {
                    if (self.getFromCache(child)) |child_rect| {
                        sum_width += child_rect.width;
                    }
                }

                return layout.x + layout.padding +  sum_width + layout.padding;
            },
        }
    }

    pub fn getNextY(self: UiState, for_id: []const u8) f32 {
        if (self.getFromCache(for_id)) |rect| {
            return rect.y;
        }

        const layout = self.currentLayout();

        switch (layout.type) {
            .row, .free => return layout.y + layout.padding,
            .column =>  {
                const children = self.children_by_layout.get(layout.id) orelse return layout.y + layout.padding;
                if (children.items.len == 0) return layout.y + layout.padding;

                var sum_height: f32 = 0;

                for (children.items) |child| {
                    if (self.getFromCache(child)) |child_rect| {
                        sum_height += child_rect.height;
                    }
                }

                return layout.y + layout.padding + sum_height + layout.padding;
            },
        }

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

