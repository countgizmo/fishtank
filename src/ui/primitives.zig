const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

pub const bg_color = rl.Color{
    .r = 232,
    .g = 232,
    .b = 232,
    .a = 255
};

pub const fg_color = rl.Color{
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
    clickable: bool = false,
    has_border: bool = false,
    has_background: bool = false,
    has_text: bool = false,
};

pub const Widget = struct{
    rect: Rect,
    flags: WidgetFlags,
};

const BORDER_WIDTH = 2;
const screen_padding = 2;

pub fn render_widget(widget: Widget) void {
    const body_rect = rl.Rectangle{
        .x = widget.rect.x,
        .y = widget.rect.y,
        .width = widget.rect.width,
        .height = widget.rect.height,
    };
    rl.DrawRectangleRec(body_rect, bg_color);


    if (widget.flags.has_border) {
        const border_rect = rl.Rectangle{
            .x = widget.rect.x + screen_padding,
            .y = widget.rect.y + screen_padding,
            .width = widget.rect.width - (screen_padding*2),
            .height = widget.rect.height - (screen_padding*2),
        };
        rl.DrawRectangleLinesEx(border_rect, BORDER_WIDTH, fg_color);
    }
}
