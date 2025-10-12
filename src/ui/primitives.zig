const std = @import("std");
const rl = @import("../raylib.zig").rl;
const UiState = @import("state.zig").UiState;

pub const bg_color = rl.Color{
    .r = 240,
    .g = 240,
    .b = 240,
    .a = 255
};

const terminal_bg_color = rl.Color{
    .r = 232,
    .g = 232,
    .b = 232,
    .a = 255
};

const terminal_border_color = rl.Color{
    .r = 204,
    .g = 204,
    .b = 204,
    .a = 255
};

pub const text_color = rl.Color{
    .r = 42,
    .g = 42,
    .b = 42,
    .a = 255
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
};

pub const border_width = 2;
pub const screen_padding = 2;
pub const big_font_size = 22;
pub const normal_font_size = 18;
pub const small_font_size = 14;
pub const text_padding = 5;

pub fn render_widget(ui: UiState, widget: Widget) void {
    const body_rect = rl.Rectangle{
        .x = widget.rect.x,
        .y = widget.rect.y,
        .width = widget.rect.width,
        .height = widget.rect.height,
    };
    rl.DrawRectangleRec(body_rect, terminal_bg_color);

    if (widget.flags.has_border) {
        const border_rect = rl.Rectangle{
            .x = widget.rect.x + border_width/2,
            .y = widget.rect.y + border_width/2,
            .width = widget.rect.width - border_width,
            .height = widget.rect.height - border_width,
        };

        var border_color = text_color;

        if (widget.flags.show_hover_effect) {
            const mouse_pos = rl.GetMousePosition();
            const is_hovered = rl.CheckCollisionPointRec(mouse_pos, body_rect);

            if (is_hovered) {
                border_color = rl.ColorBrightness(text_color, 0.5);
            }
        }
        rl.DrawRectangleLinesEx(border_rect, border_width, border_color);
    }

    if (widget.flags.has_text and widget.text != null) {
        var buf: [255:0] u8 = undefined;
        const label_text = std.fmt.bufPrintZ(&buf, "{s}", .{widget.text.?}) catch "";
        const text_pos = rl.Vector2{
            .x = widget.rect.x + text_padding,
            .y = widget.rect.y + text_padding
        };
        rl.DrawTextEx(
            ui.text_config.font,
            label_text,
            text_pos ,
            @as(f32, @floatFromInt(ui.active_text_style.font_size)),
            0,
            text_color);
    }
}
