const std = @import("std");
const UiState = @import("state.zig").UiState;

const primitives = @import("primitives.zig");

pub const TreemapItem = struct {
    name: []const u8,
    weight: f32,
};

pub const SplitStrategy = enum {
    horizontal,
    vertical
};

fn compareByWeight(_: void, a: TreemapItem, b: TreemapItem) bool {
    return a.weight > b.weight;
}

pub fn render(ui: UiState, window_width: i32, window_height: i32, items: []TreemapItem) void {
    var split: SplitStrategy = .horizontal;

    std.mem.sort(TreemapItem, items, {}, compareByWeight);

    var total_weight: f32 = 0;
    for (items) |item| {
        total_weight += item.weight;
    }


    var current_x: f32 = 0;
    const current_y: f32 = 0;

    const container_width = @as(f32, @floatFromInt(window_width));
    const container_height = @as(f32, @floatFromInt(window_height));

    for (items) |item| {
        switch (split) {
            .horizontal => {
                split = .vertical;

                const current_width = container_width/total_weight*item.weight;

                const current_rect = primitives.Rect {
                    .height = container_height,
                    .width = current_width,
                    .x = current_x,
                    .y = current_y,
                };

                current_x += current_width;

                const widget = primitives.Widget{
                    .rect = current_rect,
                    .flags = .{
                        .has_border = true,
                    },
                    .text = item.name,
                };
                std.log.debug("Text = {s}", .{item.name});

                primitives.render_widget(ui, widget);
            },
            .vertical => {
                split = .horizontal;
                std.log.debug("Text = {s}", .{item.name});
            },
        }
    }

}
