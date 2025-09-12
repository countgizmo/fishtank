const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Module = @import("parser.zig").Module;
const Parser = @import("parser.zig").Parser;
const Lexer = @import("lexer.zig").Lexer;
const Components = @import("ui/components.zig");
const UiState = @import("ui/state.zig").UiState;

pub const Project = struct {
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    modules: ArrayList(Module),

    pub fn init(allocator: Allocator) !Project {
        return Project {
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .modules = .empty,
        };
    }

    pub fn deinit(self: *Project) void {
        self.arena.deinit();
        for (self.modules.items) |*module| {
            module.deinit();
        }
        self.modules.deinit(self.allocator);
    }

    fn getcontent(self: *Project, file_path: []const u8) ![]u8 {
        return try std.fs.cwd().readFileAlloc(
            self.arena.allocator(),
            file_path,
            1024 * 1024 * 10,
        );
    }

    pub fn analyze(self: *Project, folder_path: []const u8) !void {
        var dir = try std.fs.cwd().openDir(folder_path, .{ .iterate = true });
        defer dir.close();

        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        errdefer self.deinit();

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            const file_path = try std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ folder_path, entry.name });
            switch (entry.kind) {
                .file => {
                    if (std.mem.endsWith(u8, entry.name, ".clj") or
                        std.mem.endsWith(u8, entry.name, ".cljs") or
                        std.mem.endsWith(u8, entry.name, ".cljc")) {
                        const contents = try self.getcontent(file_path);

                        std.log.debug("Lexing file: {s}", .{entry.name});
                        var lexer = Lexer.init(self.allocator, contents);
                        var tokens = try lexer.getTokens();
                        defer tokens.deinit(self.allocator);

                        std.log.debug("Parsing file: {s}", .{entry.name});
                        var parser = Parser.init(self.allocator, tokens.items);
                        const module = try parser.parse(file_path);
                        try self.modules.append(self.allocator, module);
                    }
                },
                .directory => {
                    try self.analyze(file_path);
                },
                else => {}
            }
        }
    }

    pub fn render(self: Project, ui: *UiState) void {
        for (self.modules.items, 0..) |module, idx| {
            ui.next_x = ui.margin + @as(i32, @intCast(idx * 400));
            module.render(ui);
        }
    }
};


