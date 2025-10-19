const std = @import("std");
const rl = @import("../raylib.zig").rl;
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
        .flags = .{},
    };

    Primitives.render_widget(ui, widget);
}

pub fn header(ui: *UiState, x: i32, y: i32, text: []const u8) void {
    var buf: [255:0]u8 = undefined;
    const label_text = std.fmt.bufPrintZ(&buf, "{s}", .{text}) catch "";

    const text_size = rl.MeasureTextEx(ui.text_config.font, label_text, Primitives.big_font_size, 1);

    ui.active_text_style.font_size = Primitives.big_font_size;

    const label_x = @as(f32, @floatFromInt(x));
    const label_y = @as(f32, @floatFromInt(y));
    const widget = Widget{
        .rect = Rect{ .x = label_x, .y = label_y, .width = text_size.x, .height = text_size.y },
        .text = text,
        .flags = .{ .has_text = true },
    };

    Primitives.render_widget(ui.*, widget);
}

pub fn label(ui: *UiState, x: i32, y: i32, text: []const u8) void {
    var buf: [255:0]u8 = undefined;
    const label_text = std.fmt.bufPrintZ(&buf, "{s}", .{text}) catch "";

    const text_size = rl.MeasureTextEx(ui.text_config.font, label_text, Primitives.normal_font_size, 1);

    ui.active_text_style.font_size = Primitives.normal_font_size;

    const label_x = @as(f32, @floatFromInt(x));
    const label_y = @as(f32, @floatFromInt(y));
    const widget = Widget{
        .rect = Rect{ .x = label_x, .y = label_y, .width = text_size.x, .height = text_size.y },
        .text = text,
        .flags = .{ .has_text = true },
    };

    Primitives.render_widget(ui.*, widget);
}

pub fn graphnode(ui: *UiState, x: i32, y: i32, text: []const u8) void {
    var buf: [255:0]u8 = undefined;
    const label_text = std.fmt.bufPrintZ(&buf, "{s}", .{text}) catch "";

    const text_size = rl.MeasureTextEx(ui.text_config.font.?, label_text, Primitives.normal_font_size, 1);

    ui.active_text_style.font_size = Primitives.normal_font_size;

    const label_x = @as(f32, @floatFromInt(x));
    const label_y = @as(f32, @floatFromInt(y));
    const widget = Widget{
        .rect = Rect{ .x = label_x, .y = label_y, .width = text_size.x, .height = text_size.y },
        .text = text,
        .flags = .{ .has_text = true, .has_border = true },
    };

    Primitives.render_widget(ui.*, widget);
}

pub const modal_width = 300;
pub const modal_height = 500;

// TODO(evgheni): return an enum action to support different actions
pub fn modal(ui: *UiState, x: f32, y: f32) bool {
    const rect = Rect {
        .x = x,
        .y = y,
        .width = modal_width,
        .height = modal_height};

    const widget = Widget{
        .rect = rect,
        .flags = .{ .has_border = true },
    };

    Primitives.render_widget(ui.*, widget);

    // Check for scrolling

    const modal_rect = rl.Rectangle {
        .height = rect.height,
        .width = rect.width,
        .x = rect.x,
        .y = rect.y,
    };

    if (rl.GetMouseWheelMove() != 0 and rl.CheckCollisionPointRec(rl.GetMousePosition(), modal_rect)) {
        return true;
    }

    return false;
}

pub fn treemapitem(ui: *UiState, rect: Primitives.Rect, text: []const u8) bool {
    ui.active_text_style.font_size = Primitives.small_font_size;

    const widget = Primitives.Widget{
        .rect = rect,
        .flags = .{
            .has_border = true,
            .has_text = true,
            .show_hover_effect = true,
        },
        .text = text,
    };

    Primitives.render_widget(ui.*, widget);

    if (rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT)) {
        const mouse = rl.GetMousePosition();
        if ((mouse.x >= rect.x and mouse.x <= rect.x + rect.width) and
            (mouse.y >= rect.y and mouse.y <= rect.y + rect.height))
        {
            return true;
        }
    }

    return false;
}
