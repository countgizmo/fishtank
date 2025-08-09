const std = @import("std");
const UiState = @import("state.zig").UiState;
const primitives = @import("primitives.zig");
const Components = @import("components.zig");


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

    for (items) |item| {
        switch (split) {
            .horizontal => {

                const current_width = container_width / total_weight * item.weight;

                const current_rect = primitives.Rect {
                    .height = container_height,
                    .width = current_width,
                    .x = current_x,
                    .y = current_y,
                };


                const widget = primitives.Widget{
                    .rect = current_rect,
                    .flags = .{
                        .has_border = true,
                    },
                    .text = item.name,
                };

                primitives.render_widget(ui.*, widget);
                const label_x = @as(i32, @intFromFloat(current_x + 20));
                const label_y = @as(i32, @intFromFloat(current_y + 20));
                Components.label(ui, label_x, label_y, item.name);


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


                const widget = primitives.Widget{
                    .rect = current_rect,
                    .flags = .{
                        .has_border = true,
                    },
                    .text = item.name,
                };

                primitives.render_widget(ui.*, widget);
                const label_x = @as(i32, @intFromFloat(current_x + 20));
                const label_y = @as(i32, @intFromFloat(current_y + 20));
                Components.label(ui, label_x, label_y, item.name);

                // Getting ready for the next item.
                split = .horizontal;
                current_y += current_height;
                container_height = container_height - current_height;
                total_weight -= item.weight;
            },
        }
    }

}
