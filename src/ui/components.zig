const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const Primitives = @import("primitives.zig");
const UiState = @import("state.zig").UiState;
const Widget = Primitives.Widget;
const WidgetFlags = Primitives.WidgetFlags;
const Rect = Primitives.Rect;


pub fn screen(ui: UiState, width: i32, height: i32) void {
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

    Primitives.render_widget(ui, widget);
}

pub fn header(ui: *UiState, x: i32, y: i32, text: []const u8) void {
    var buf: [255:0] u8 = undefined;
    const label_text = std.fmt.bufPrintZ(&buf, "{s}", .{text}) catch "";

    const text_size = rl.MeasureTextEx(
        ui.text_config.font.?,
        label_text,
        Primitives.big_font_size,
        1);


    ui.active_text_style.font_size = Primitives.big_font_size;

    const label_x = @as(f32, @floatFromInt(x));
    const label_y = @as(f32, @floatFromInt(y));
    const widget = Widget{
        .rect = Rect{
            .x = label_x,
            .y = label_y,
            .width = text_size.x,
            .height = text_size.y
        },
        .text = text,
        .flags = .{
            .has_text = true
        },
    };

    Primitives.render_widget(ui.*, widget);
}


pub fn label(ui: *UiState, x: i32, y: i32, text: []const u8) void {
    var buf: [255:0] u8 = undefined;
    const label_text = std.fmt.bufPrintZ(&buf, "{s}", .{text}) catch "";

    const text_size = rl.MeasureTextEx(
        ui.text_config.font.?,
        label_text,
        Primitives.normal_font_size,
        1);

    ui.active_text_style.font_size = Primitives.normal_font_size;

    const label_x = @as(f32, @floatFromInt(x));
    const label_y = @as(f32, @floatFromInt(y));
    const widget = Widget{
        .rect = Rect{
            .x = label_x,
            .y = label_y,
            .width = text_size.x,
            .height = text_size.y
        },
        .text = text,
        .flags = .{
            .has_text = true
        },
    };

    Primitives.render_widget(ui.*, widget);
}

pub fn graphnode(ui: *UiState, x: i32, y: i32, text: []const u8) void {
    var buf: [255:0] u8 = undefined;
    const label_text = std.fmt.bufPrintZ(&buf, "{s}", .{text}) catch "";

    const text_size = rl.MeasureTextEx(
        ui.text_config.font.?,
        label_text,
        Primitives.normal_font_size,
        1);

    ui.active_text_style.font_size = Primitives.normal_font_size;

    const label_x = @as(f32, @floatFromInt(x));
    const label_y = @as(f32, @floatFromInt(y));
    const widget = Widget{
        .rect = Rect{
            .x = label_x,
            .y = label_y,
            .width = text_size.x,
            .height = text_size.y
        },
        .text = text,
        .flags = .{
            .has_text = true,
            .has_border = true
        },
    };

    Primitives.render_widget(ui.*, widget);
}
