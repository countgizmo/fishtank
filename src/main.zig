const std = @import("std");
const rl = @import("raylib.zig").rl;

const token_module = @import("token.zig");
const Token = token_module.Token;
const TokenWithPosition = token_module.TokenWithPosition;
const Parser = @import("parser.zig").Parser;
const Lexer = @import("lexer.zig").Lexer;
const Render = @import("render.zig");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Primitives = @import("ui/primitives.zig");
const Components = @import("ui/components.zig");
const UiState = @import("ui/state.zig").UiState;
const Project = @import("project.zig").Project;
const Treemap = @import("ui/treemap.zig").Treemap;

fn getFontPath(allocator: Allocator) ![:0]u8 {
    const exe_path = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_path);

    const font_path = "../resources/fonts/IosevkaFixed-Regular.ttf";
    var paths = [_][]const u8 { exe_path, font_path };
    const full_font_path = try std.fs.path.join(allocator, &paths);
    defer allocator.free(full_font_path);

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.fs.realpath(full_font_path, &path_buf);
    return allocator.dupeZ(u8, path);
}

pub const width = 1200;
pub const height = 800;

pub fn main() !void {
    rl.SetConfigFlags(rl.FLAG_WINDOW_HIGHDPI);
    rl.InitWindow(width, height, "Fishtank");
    defer rl.CloseWindow();
    rl.SetTargetFPS(30);
    rl.EnableEventWaiting();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        if (status != .ok) @panic("Memory leak detected!");
    }

    const allocator = gpa.allocator();
    const font_path = try getFontPath(allocator);
    defer allocator.free(font_path);

    var ui = UiState{
        .container_width = width, //@as(f32, @floatFromInt(rl.GetRenderWidth())),
        .container_height = height, //@as(f32, @floatFromInt(rl.GetRenderHeight())),
        .text_config = .{
            .font = rl.LoadFont(font_path.ptr)
        },
        .active_text_style = .{
            .font_size = Primitives.normal_font_size,
        },
    };
    defer rl.UnloadFont(ui.text_config.font);


    rl.SetTextureFilter(ui.text_config.font.texture, rl.TEXTURE_FILTER_BILINEAR);

    var project = try Project.init(allocator);
    defer project.deinit();
    // try project.analyze("test_subjects/very_simple_project");
    // try project.analyze("/Users/ziggy/Projects/private/clojure/zots/src");
    //
    // project.analyze("/Users/ziggy/Projects/humbleai/hai/main/projects/browser-extension/src/browser_ext") catch |err| {
    project.analyze("/Users/ziggy/Projects/private/clojure/zots/src") catch |err| {
        std.log.err("Analysis failed: {}", .{err});
        return err;
    };

    const items = try project.getModuleAsTreemapItems();
    defer allocator.free(items);

    var treemap = try Treemap.init(allocator, items, ui);
    defer treemap.deinit();

    std.log.debug("Container: {}x{}", .{ui.container_width, ui.container_height});

    // After calculateRows, check if rows actually fit:
    var total_row_height: f32 = 0;
    for (treemap.rows) |row| {
        total_row_height += row.height;
    }
    std.log.debug("Total row height: {} (should be {})", .{total_row_height, ui.container_height});

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(Primitives.bg_color);

        // if (rl.IsWindowResized()) {
        //     ui.container_height = @as(f32, @floatFromInt(rl.GetRenderHeight()));
        //     ui.container_width = @as(f32, @floatFromInt(rl.GetRenderWidth()));
        //     try treemap.recalculate(ui);
        // }
        // project.render(&ui);
        treemap.render(&ui);

        rl.EndDrawing();
    }
}
