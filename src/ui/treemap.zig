const std = @import("std");
const UiState = @import("state.zig").UiState;
const primitives = @import("primitives.zig");
const Components = @import("components.zig");
const Module = @import("../parser.zig").Module;
const rl = @cImport({
    @cInclude("raylib.h");
});

pub const TreemapItemContext = struct {
    module: *Module,
};

pub const TreemapItem = struct {
    name: []const u8,
    weight: f32,
    context: TreemapItemContext,
};

pub const SplitStrategy = enum {
    horizontal,
    vertical
};

fn compareByWeight(_: void, a: TreemapItem, b: TreemapItem) bool {
    return a.weight > b.weight;
}

pub fn render(ui: *UiState, window_width: i32, window_height: i32, items: []TreemapItem) void {
    var split: SplitStrategy = .horizontal;

    std.mem.sort(TreemapItem, items, {}, compareByWeight);

    var total_weight: f32 = 0;
    for (items) |item| {
        total_weight += item.weight;
    }


    var current_x: f32 = 0;
    var current_y: f32 = 0;

    var container_width = @as(f32, @floatFromInt(window_width));
    var container_height = @as(f32, @floatFromInt(window_height));

    var item_clicked: ?usize = null;

    for (items, 0..) |item, idx| {
        switch (split) {
            .horizontal => {
                const current_width = container_width / total_weight * item.weight;

                const current_rect = primitives.Rect {
                    .height = container_height,
                    .width = current_width,
                    .x = current_x,
                    .y = current_y,
                };

                if (Components.treemapitem(ui, current_rect, item.name)) {
                    item_clicked = idx;
                }


                // Getting ready for the next item.
                split = .vertical;
                current_x += current_width;
                container_width = container_width - current_width;
                total_weight -= item.weight;
            },
            .vertical => {
                const current_height = container_height / total_weight * item.weight;

                const current_rect = primitives.Rect {
                    .height = current_height,
                    .width = container_width,
                    .x = current_x,
                    .y = current_y,
                };

                if (Components.treemapitem(ui, current_rect, item.name)) {
                    item_clicked = idx;
                }

                // Getting ready for the next item.
                split = .horizontal;
                current_y += current_height;
                container_height = container_height - current_height;
                total_weight -= item.weight;
            },
        }
    }

    if (item_clicked) |clicked_idx| {
        const item = items[clicked_idx];
        std.log.debug("Clicked {s}", .{ item.name });
        const mouse = rl.GetMousePosition();
        Components.modal(ui, mouse.x, mouse.y);

        const start_x = @as(i32, @intFromFloat(mouse.x));
        const start_y = @as(i32, @intFromFloat(mouse.y));

        const header_x = start_x + 5;
        const header_y = start_y + 10;

        Components.header(ui, header_x, header_y, "Functions:");

        for (item.context.module.functions.items, 0..) |function, idx| {
            const fn_item_count = 1 + @as(i32, @intCast(idx));
            const label_x = header_x + 5;
            const label_y = header_y + (24 * fn_item_count);
            Components.label(ui, label_x, label_y, function.name);
        }
    }
}
