const std = @import("std");
const Tuple = std.meta.Tuple;
const rl = @import("../raylib.zig").rl;
const Primitives = @import("primitives.zig");
const UiState = @import("state.zig").UiState;
const Layout = @import("state.zig").Layout;
const Widget = @import("state.zig").Widget;
const Rect = @import("state.zig").Rect;
const WidgetFlags = @import("state.zig").WidgetFlags;

const Click = struct {
    rect: Rect,
    is_clicked: bool,
};

pub fn screen(ui: *UiState ) void {
    const layout = ui.currentLayout();
    const id = "screen";

    const screen_width = layout.available_width - (2*layout.padding);
    const screen_height = layout.available_height - (2*layout.padding);
    const screen_x = ui.getNextX(id);
    const screen_y = layout.y + layout.padding;

    const widget = Widget{
        .rect = Rect{
            .x = screen_x,
            .y = screen_y,
            .width = screen_width,
            .height = screen_height,
        },
        .id = id,
        .flags = .{},
    };

    Primitives.render_widget(ui, widget);

    ui.registerAsChild(id) catch |err| {
        std.log.err("Failed to register screen as child with id = {s}: {}", .{id, err});
    };
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
        .id = text,
        .flags = .{ .has_text = true },
    };

    Primitives.render_widget(ui, widget);
}

fn label_base_widget(ui: *UiState, text: []const u8) Widget {
    var buf: [255:0]u8 = undefined;
    const label_text = std.fmt.bufPrintZ(&buf, "{s}", .{text}) catch "";

    const text_size = rl.MeasureTextEx(ui.text_config.font, label_text, Primitives.normal_font_size, 1);

    const id = text;
    ui.active_text_style.font_size = Primitives.normal_font_size;

    const label_width = text_size.x + 2 * Primitives.text_padding;
    const label_height = text_size.y + 2 * Primitives.text_padding;
    const label_x = ui.getNextX(id);
    const label_y = ui.getNextY(id);

    const widget = Widget{
        .rect = Rect{
            .x = label_x,
            .y = label_y,
            .width = label_width,
            .height = label_height,
        },
        .text = text,
        .id = id,
        .flags = .{ .has_text = true },
    };

    ui.registerAsChild(id) catch |err| {
        std.log.err("Failed to register label as child with id = {s}: {}", .{id, err});
    };

    return widget;
}

pub fn label(ui: *UiState, text: []const u8) void {
    const widget = label_base_widget(ui, text);
    Primitives.render_widget(ui, widget);
}

pub fn bordered_label(ui: *UiState, text: []const u8) void {
    var widget = label_base_widget(ui, text);
    widget.flags = .{
        .has_text = true,
        .has_border = true,
    };

    Primitives.render_widget(ui, widget);
}

pub fn checkRectCollision(rect: Rect, x: f32, y: f32) bool {
    return ((x >= rect.x and x <= rect.x + rect.width) and
            (y >= rect.y and y <= rect.y + rect.height));
}

pub fn clickable_label(ui: *UiState, text: []const u8) Click {
    var widget = label_base_widget(ui, text);
    widget.flags = .{
        .has_text = true,
        .show_hover_effect = true,
    };


    if (rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT)) {
        const mouse = rl.GetMousePosition();
        if (checkRectCollision(widget.rect, mouse.x, mouse.y)) {
            return .{ .rect = widget.rect, .is_clicked = true};
        }
    }

    Primitives.render_widget(ui, widget);

    return .{ .rect = widget.rect, .is_clicked = false};
}

pub fn row(ui: *UiState, id: []const u8, children_layout: Layout) !void {
    const parent_layout = ui.currentLayout();

    // If the children are not yet registered, there's nothing to do
    const children = ui.children_by_layout.get(children_layout.id) orelse return;
    if (children.items.len == 0) return;

    // In row we are interested in the heighest child
    // and the sum of widths of all children.
    // We can use this information to calculate the height of the row
    // that will fit even the heighest child and the minimal width of the row.
    //
    // Some rows can take the space of the layout (main menu, for example).
    // Some rows might support line breaks.
    // In any case sum of widths is needed.

    var max_height: f32 = 0;
    var sum_width: f32 = 0;

    for (children.items) |child| {
        if (ui.getFromCache(child)) |child_rect| {
            sum_width += child_rect.width;

            if (child_rect.height > max_height) {
                max_height = child_rect.height;
            }
        } else {
            // If at least one child is missing in cache
            // we stop calculating the row.
            // We will have to wait for the next frame to render.
            return;
        }
    }

    const height =  children_layout.padding + max_height + children_layout.padding;
    const width = parent_layout.available_width;

    const row_rect: Rect = .{
        .x = ui.getNextX(id),
        .y = ui.getNextY(id),
        .height = height,
        .width = width,
    };

    const widget = Widget{
        .rect = row_rect,
        .id = id,
        .flags = .{
            .has_border = true,
        },
    };

    Primitives.render_widget(ui, widget);

    ui.registerAsChild(id) catch |err| {
        std.log.err("Failed to register row as child with id = {s}: {}", .{id, err});
    };
}

pub fn row_end(ui: *UiState) void {
    ui.popLayout();
}


// This component hugs the children.
// If you need another behaviour make another fucking component!
pub fn column(ui: *UiState, id: []const u8, children_layout: Layout) !void {

    // If the children are not yet registered, there's nothing to do
    const children = ui.children_by_layout.get(children_layout.id) orelse return;
    if (children.items.len == 0) return;

    var max_width: f32 = 0;
    var sum_height: f32 = 0;

    for (children.items) |child| {
        if (ui.getFromCache(child)) |child_rect| {
            sum_height += child_rect.height + children_layout.gap;

            const cur_width = child_rect.width;
            if (cur_width > max_width) {
                max_width = cur_width;
            }
        } else {
            // If at least one child is missing in cache
            // we stop calculating the row.
            // We will have to wait for the next frame to render.
            return;
        }
    }

    const height = children_layout.padding + sum_height + children_layout.padding;
    const width = children_layout.padding + max_width + children_layout.padding;

    const col_rect: Rect = .{
        .x = children_layout.x,
        .y = children_layout.y,
        .height = height,
        .width = width,
    };

    const widget = Widget{
        .rect = col_rect,
        .id = id,
        .flags = .{
            .has_border = true,
        },
    };

    Primitives.render_widget(ui, widget);

    ui.registerAsChild(id) catch |err| {
        std.log.err("Failed to register column as child with id = {s}: {}", .{id, err});
    };
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
        .id = text,
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
        .id = "modal",
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
        .id = text,
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
