const UiState = @import("state.zig").UiState;
const Layout = @import("state.zig").Layout;
const components = @import("components.zig");

pub fn render(ui: *UiState) !void {
    components.screen(ui);

    const layout = ui.currentLayout();

    var main_menu_layout = Layout {
        .x = layout.x + layout.padding,
        .y = layout.y + layout.padding,
        .width = layout.getWidth(),
        .height = layout.getHeight(),
        .padding = 5,
        .gap = 10,
        .type = .Row
    };

    try ui.pushLayout(&main_menu_layout);
        try components.bordered_label(ui, "Text 1");
        try components.bordered_label(ui, "Text 2");
    ui.popLayout();
}
