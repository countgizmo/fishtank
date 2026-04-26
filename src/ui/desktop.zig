const log = @import("std").log;
const UiState = @import("state.zig").UiState;
const Layout = @import("state.zig").Layout;
const components = @import("components.zig");

pub fn render(ui: *UiState, width: f32, height: f32) !void {
    var initial_layout = Layout {
        .id = "root_layout",
        .x = 0,
        .y = 0,
        .available_width = width,
        .available_height = height,
        .padding = 10,
        .type = .free,
    };
    try ui.pushLayout(&initial_layout);

        components.screen(ui);

        var screen_layout = Layout {
            .id = "screen_layout",
            .x = initial_layout.x + initial_layout.padding,
            .y = initial_layout.y + initial_layout.padding,
            .available_width = initial_layout.available_width - (2*initial_layout.padding),
            .available_height = initial_layout.available_height - (2*initial_layout.padding),
            .padding = 0,
            .type = .column,
        };
        try ui.pushLayout(&screen_layout);

            var main_menu_layout = Layout {
                .id = "main_menu_layout",
                .x = screen_layout.x,
                .y = screen_layout.y,
                .available_width = initial_layout.available_width - initial_layout.padding,
                .available_height = initial_layout.available_height - initial_layout.padding,
                .padding = 5,
                .type = .row
            };

            try components.row_start(ui, "main_menu_row", main_menu_layout);

            try ui.pushLayout(&main_menu_layout);
                    if (components.clickable_label(ui, "File")) {
                        var menu_dropdown_layout = Layout {
                            .id = "main_menu_dropdown_layout",
                            .x = main_menu_layout.x,
                            .y = main_menu_layout.y,
                            .available_width = screen_layout.available_width,
                            .available_height = screen_layout.available_height - main_menu_layout.available_height,
                            .padding = 5,
                            .type = .column,
                        };

                        try ui.pushLayout(&menu_dropdown_layout);
                            try components.column(ui, "main_menu_dropdown");
                            components.label(ui, "About...");
                            components.label(ui, "Chooser");
                        ui.popLayout();
                    }
                    components.label(ui, "Edit");
                    components.label(ui, "Go");
            ui.popLayout();
        ui.popLayout();
    ui.popLayout();
}
