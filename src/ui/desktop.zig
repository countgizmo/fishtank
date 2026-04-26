const log = @import("std").log;
const mem = @import("std").mem;

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

            try components.row(ui, "main_menu_row", main_menu_layout);

            try ui.pushLayout(&main_menu_layout);
                const file_menu_click = components.clickable_label(ui, "File");
                if (file_menu_click.is_clicked) {
                    ui.opened_dropdown_menu = "File";

                    var file_menu_dropdown_layout = Layout {
                        .id = "file_menu_dropdown_layout",
                        .x = file_menu_click.rect.x,
                        .y = file_menu_click.rect.y + file_menu_click.rect.height,
                        .available_width = screen_layout.available_width,
                        .available_height = screen_layout.available_height,
                        .padding = 3,
                        .gap = 5,
                        .type = .column,
                    };

                    try components.column(ui, "file_menu_dropdown", file_menu_dropdown_layout);
                    try ui.pushLayout(&file_menu_dropdown_layout);
                        components.label(ui, "About...");
                        components.label(ui, "Chooser");
                    ui.popLayout();
                }

                const edit_menu_click = components.clickable_label(ui, "Edit");
                if (edit_menu_click.is_clicked) {
                    ui.opened_dropdown_menu = "Edit";

                    var edit_menu_dropdown_layout = Layout {
                        .id = "edit_menu_dropdown_layout",
                        .x = edit_menu_click.rect.x,
                        .y = edit_menu_click.rect.y + file_menu_click.rect.height,
                        .available_width = screen_layout.available_width,
                        .available_height = screen_layout.available_height - main_menu_layout.available_height,
                        .padding = 3,
                        .gap = 5,
                        .type = .column,
                    };

                    try components.column(ui, "edit_menu_dropdown", edit_menu_dropdown_layout);
                    try ui.pushLayout(&edit_menu_dropdown_layout);
                        components.label(ui, "Row");
                        components.label(ui, "Column");
                        components.label(ui, "Shape");
                    ui.popLayout();
                }
                components.label(ui, "Go");
            ui.popLayout();
        ui.popLayout();
    ui.popLayout();
}
