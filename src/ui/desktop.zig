const UiState = @import("state.zig").UiState;
const Layout = @import("state.zig").Layout;
const components = @import("components.zig");

pub fn render(ui: *UiState, width: f32, height: f32) !void {
    var initial_layout = Layout{
        .id = "root",
        .x = 0,
        .y = 0,
        .width = width,
        .height = height,
        .padding = 10,
        .next_x = 10,
        .next_y = 10,
    };
    try ui.pushLayout(&initial_layout);

    components.screen(ui);

    const layout = ui.currentLayout();

    var main_menu_layout = Layout {
        .id = "main_menu_layout",
        .x = layout.x + layout.padding,
        .y = layout.y + layout.padding,
        .next_x = layout.x + layout.padding + 5,
        .next_y = layout.y + layout.padding + 5,
        .width = layout.getWidth(),
        .height = layout.getHeight(),
        .padding = 5,
        .gap = 10,
        .type = .Row
    };

    try ui.pushLayout(&main_menu_layout);
        try components.row(ui, "main_menu_row");
        try components.label(ui, "File");
        try components.label(ui, "Edit");
        try components.label(ui, "Go");
    ui.popLayout();
}
