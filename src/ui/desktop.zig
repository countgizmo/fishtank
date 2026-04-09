const UiState = @import("state.zig").UiState;
const components = @import("components.zig");


pub fn render(ui: *UiState) void {
    components.screen(ui, ui.container_width, ui.container_height);

    ui.rowStart();
        // components.row(ui);
        components.bordered_label(ui, "Text 1");
        components.bordered_label(ui, "Text 2");
    ui.rowEnd();
}
