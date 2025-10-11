const std = @import("std");
const Allocator = std.mem.Allocator;
const UiState = @import("state.zig").UiState;
const primitives = @import("primitives.zig");
const Components = @import("components.zig");
const Module = @import("../parser.zig").Module;
const rl = @import("../raylib.zig").rl;

pub const TreemapItemContext = struct {
    module: *Module,
};

pub const TreemapItem = struct {
    name: []const u8,
    weight: f32,
    context: ?TreemapItemContext = null,
};

pub const TreemapRow = struct {
    weight: f32,
    height: f32,
    start_index: usize,
    count: usize
};

pub const Treemap = struct {
    items: []TreemapItem,
    rows: []TreemapRow,
    total_weight: f32 = 0,
    allocator: Allocator,

    pub fn init(allocator: Allocator, items: []TreemapItem) !Treemap {
        const sorted_items = try allocator.dupe(TreemapItem, items);
        std.mem.sort(TreemapItem, sorted_items, {}, compareByWeight);

        var total: f32 = 0;
        for (sorted_items) |item| {
            total += item.weight;
        }

        return Treemap{
            .items = sorted_items,
            .total_weight = total,
            .rows = try calculateRows(allocator, sorted_items, total, 768),
            .allocator = allocator
        };
    }

    fn compareByWeight(_: void, a: TreemapItem, b: TreemapItem) bool {
        return a.weight > b.weight;
    }

    fn calculateRows(allocator: Allocator, items: []TreemapItem, total_weight: f32,  height: f32) ![]TreemapRow {
        var rows = try allocator.alloc(TreemapRow, 1);
        rows[0] = TreemapRow {
            .weight = total_weight,
            .height = height,
            .start_index = 0,
            .count = items.len,

        };

        return rows;
    }

    pub fn deinit(self: *Treemap) void {
        self.allocator.free(self.items);
        self.allocator.free(self.rows);
    }

    pub fn render(self: Treemap, ui: *UiState) void {
        for (self.rows) |row| {
            const row_items = self.items[row.start_index..row.start_index + row.count];
            var x: f32 = 0;
            for (row_items) |item| {
                const width = (item.weight / row.weight) * ui.container_width;
                const rect = primitives.Rect {
                    .x = x,
                    .y = 0,
                    .width = width,
                    .height = row.height,

                };
                _ = Components.treemapitem(ui, rect, item.name);
                x += width;
            }
        }
    }
};

