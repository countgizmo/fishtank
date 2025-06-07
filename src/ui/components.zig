const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const Primitives = @import("primitives.zig");
const Widget = Primitives.Widget;
const WidgetFlags = Primitives.WidgetFlags;
const Rect = Primitives.Rect;


pub fn screen(width: i32, height: i32) void {
    const widget = Widget{
        .rect = Rect{
            .x = 0,
            .y = 0,
            .width = @as(f32, @floatFromInt(width)),
            .height = @as(f32, @floatFromInt(height)),
        },
        .flags = .{
            .has_border = true
        },
    };

    Primitives.render_widget(widget);
}
