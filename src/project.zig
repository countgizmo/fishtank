const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Module = @import("parser.zig").Module;

pub const Project = struct {
    allocator: Allocator,
    modules: ArrayList(Module),

    pub fn init(allocator: Allocator) !Project {
        return Project {
            .allocator = allocator,
            .modules = ArrayList(Module).init(allocator),
        };
    }

    pub fn deinit(self: *Project) void {
        self.modules.deinit();
    }

    fn getcontent(self: Project, file_path: []const u8) ![]u8 {
        return try std.fs.cwd().readFileAlloc(
            self.allocator,
            file_path,
            1024 * 1024 * 10,
        );
    }

    pub fn analyze(self: Project, folder_path: []const u8) !void {
        var dir = try std.fs.cwd().openDir(folder_path, .{ .iterate = true });
        defer dir.close();

        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".clj")) {
                std.log.info("Found Clojure file: {s}", .{entry.name});

                const file_path = try std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ folder_path, entry.name });
                const contents = try self.getcontent(file_path);
                std.log.debug("Contents: \n {s}" ,.{contents});
                self.allocator.free(contents);
            }
        }
    }

};


