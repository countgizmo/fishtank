const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Module = @import("parser.zig").Module;
const Parser = @import("parser.zig").Parser;
const Lexer = @import("lexer.zig").Lexer;
const Components = @import("ui/components.zig");
const UiState = @import("ui/state.zig").UiState;
const Treemap = @import("ui/treemap.zig");
const TreemapItem = Treemap.TreemapItem;

pub const Project = struct {
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    modules: ArrayList(Module),
    modules_by_folder: std.StringArrayHashMap(usize),

    pub fn init(allocator: Allocator) !Project {
        return Project {
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .modules = .empty,
            .modules_by_folder = std.StringArrayHashMap(usize).init(allocator),
        };
    }

    pub fn deinit(self: *Project) void {
        self.arena.deinit();
        for (self.modules.items) |*module| {
            module.deinit();
        }
        self.modules.deinit(self.allocator);
        self.modules_by_folder.deinit();
    }

    fn getcontent(self: *Project, file_path: []const u8) ![]u8 {
        return try std.fs.cwd().readFileAlloc(
            self.arena.allocator(),
            file_path,
            1024 * 1024 * 10,
        );
    }

    pub fn getModuleAsTreemapItems(self: *Project) ![]TreemapItem {
        var treeMapItems: ArrayList(TreemapItem) = .empty;
        defer treeMapItems.deinit(self.allocator);

        for (self.modules.items) |*project_module| {
            const mapitem = TreemapItem {
                .name = project_module.name,
                .weight = @as(f32, @floatFromInt(project_module.functions.items.len)),
                .context = .{
                    .module = project_module,
                },
            };
            try treeMapItems.append(self.allocator, mapitem);
        }

        return treeMapItems.toOwnedSlice(self.allocator);
    }


    pub fn getFoldersAsTreemapItems(self: *Project) ![]TreemapItem {
        var treeMapItems: ArrayList(TreemapItem) = .empty;
        defer treeMapItems.deinit(self.allocator);

        var iterator = self.modules_by_folder.iterator();
        while (iterator.next()) |entry| {
            std.log.debug("map key ={s} map value = {d}", .{entry.key_ptr.*, entry.value_ptr.*});
            const mapitem = TreemapItem {
                .name = entry.key_ptr.*,
                .weight = @as(f32, @floatFromInt(entry.value_ptr.*)),
            };
            try treeMapItems.append(self.allocator, mapitem);
        }

        return treeMapItems.toOwnedSlice(self.allocator);
    }


    pub fn analyze(self: *Project, folder_path: []const u8) !void {
        std.log.debug("Analyzing folder: {s}", .{ folder_path });
        var dir = try std.fs.cwd().openDir(folder_path, .{ .iterate = true });
        defer dir.close();

        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            const file_path = try std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ folder_path, entry.name });
            switch (entry.kind) {
                .file => {
                    if (std.mem.endsWith(u8, entry.name, ".clj") or
                        std.mem.endsWith(u8, entry.name, ".cljs") or
                        std.mem.endsWith(u8, entry.name, ".cljc")) {

                        const folder_path_copy = try self.arena.allocator().dupe(u8, folder_path);
                        if (self.modules_by_folder.get(folder_path_copy)) |current_modules_count| {
                            try self.modules_by_folder.put(folder_path_copy, current_modules_count + 1);
                        } else {
                            try self.modules_by_folder.put(folder_path_copy, 0);
                        }

                        const contents = try self.getcontent(file_path);

                        // std.log.debug("Lexing file: {s}", .{file_path});
                        var lexer = Lexer.init(self.allocator, contents);
                        var tokens = try lexer.getTokens();
                        defer tokens.deinit(self.allocator);

                        // std.log.debug("Parsing file: {s}", .{file_path});
                        var parser = Parser.init(self.allocator, tokens.items);
                        const module = try parser.parse(file_path);
                        try self.modules.append(self.allocator, module);
                    }
                },
                .directory => {
                    self.analyze(file_path) catch |err| {
                        std.log.warn("Skipping {s}: {}", .{file_path, err});
                    };
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


