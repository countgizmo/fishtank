const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const UiState = @import("state.zig").UiState;
const TreemapItemClicked = @import("state.zig").TreemapItemClicked;
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

    pub fn init(allocator: Allocator, items: []TreemapItem, ui: UiState) !Treemap {
        const sorted_items = try allocator.dupe(TreemapItem, items);
        std.mem.sort(TreemapItem, sorted_items, {}, compareByWeight);

        var total: f32 = 0;
        for (sorted_items) |item| {
            total += item.weight;
        }

        return Treemap{
            .items = sorted_items,
            .total_weight = total,
            .rows = try calculateRows(allocator, sorted_items, total, ui.container_width, ui.container_height),
            .allocator = allocator
        };
    }

    pub fn recalculate(self: *Treemap, ui: UiState) !void {

        // TODO(evgheni): fix the memory leak.
        // just track rows as an arraylist in the Treemap struct and just reset it and recalculate in place.
        // free only at the end.
        self.rows = try calculateRows(self.allocator, self.items, self.total_weight, ui.container_width, ui.container_height);
    }

    fn compareByWeight(_: void, a: TreemapItem, b: TreemapItem) bool {
        return a.weight > b.weight;
    }

    fn calculateRows(allocator: Allocator, items: []TreemapItem, total_weight: f32, width: f32, height: f32) ![]TreemapRow {
        var rows: ArrayList(TreemapRow) = .empty;
        defer rows.deinit(allocator);

        var current_row = TreemapRow {
            .weight = 0,
            .height = 0,
            .start_index = 0,
            .count = 0,
        };

        var previous_worst_ratio: f32 = 0;

        for (items, 0..) |item, idx| {
            const hypothetical_weight = current_row.weight + item.weight;
            const hypothetical_height = (hypothetical_weight / total_weight) * height;

            // Finding the worst ratio for items 0...current
            var worst_ratio: f32 = 0;
            var i: usize = current_row.start_index;
            while (i <= idx) {
                const hypothetical_width = (items[i].weight / hypothetical_weight) * width;
                const hypothetical_ratio = @max(
                    hypothetical_width / hypothetical_height,
                    hypothetical_height / hypothetical_width
                );

                if (hypothetical_ratio > worst_ratio) {
                    worst_ratio = hypothetical_ratio;
                }

                i += 1;
            }


            // if the ratio becomes worst, create a new row
            // else continue adding weight of the item to the current row
            if (current_row.count > 0 and worst_ratio > previous_worst_ratio) {
                try rows.append(allocator, current_row);

                current_row = TreemapRow {
                    .weight = item.weight,
                    .height = 0,
                    .start_index = idx,
                    .count = 1,
                };
                const single_item_width = width;  // Takes full width when alone
                const single_item_ratio = @max(
                    single_item_width / current_row.height,
                    current_row.height / single_item_width
                );
                previous_worst_ratio = single_item_ratio;

            } else {
                current_row.count += 1;
                current_row.weight += item.weight;
                previous_worst_ratio = worst_ratio;
            }

            const current_row_percentage = current_row.weight / total_weight;
            current_row.height = current_row_percentage * height;
        }

        if (current_row.count > 0) {
            try rows.append(allocator, current_row);
        }


        // After the loop, before returning
        // Adjust last row to perfectly fill remaining space
        if (rows.items.len > 0) {
            const used_height = blk: {
                var sum: f32 = 0;
                for (rows.items[0..rows.items.len-1]) |r| sum += r.height;
                break :blk sum;
            };
            rows.items[rows.items.len-1].height = height - used_height;
        }

        return rows.toOwnedSlice(allocator);
    }

    pub fn deinit(self: *Treemap) void {
        self.allocator.free(self.items);
        self.allocator.free(self.rows);
    }

    pub fn render(self: Treemap, ui: *UiState) void {
        var y: f32 = ui.container_y;
        var current_item_idx: usize = 0;

        for (self.rows) |row| {
            const row_items = self.items[row.start_index..row.start_index + row.count];
            var x: f32 = ui.container_x;
            for (row_items) |item| {
                const width = (item.weight / row.weight) * ui.container_width;
                const rect = primitives.Rect {
                    .x = x,
                    .y = y,
                    .width = width,
                    .height = row.height,

                };

                if (Components.treemapitem(ui, rect, item.name)) {
                    if (ui.treemap_item_clicked == current_item_idx) {
                        ui.treemap_item_clicked = null;
                    } else {
                        ui.treemap_item_clicked = current_item_idx;
                        const mouse = rl.GetMousePosition();
                        ui.active_modal = .{
                            .x = mouse.x,
                            .y = mouse.y,
                        };
                    }
                }

                x += width;
                current_item_idx += 1;
            }
            y += row.height;
        }

        if (ui.treemap_item_clicked) |item_clicked| {
            const item = self.items[item_clicked];
            if (ui.active_modal) |active_modal| {
                Components.modal(ui, active_modal.x, active_modal.y);

                const start_x = @as(i32, @intFromFloat(active_modal.x));
                const start_y = @as(i32, @intFromFloat(active_modal.y));

                const header_x = start_x + 5;
                const header_y = start_y + 10;

                Components.header(ui, header_x, header_y, "Functions:");

                if (item.context) |context| {
                    for (context.module.functions.items, 0..) |function, idx| {
                        const fn_item_count = 1 + @as(i32, @intCast(idx));
                        const label_x = header_x + 5;
                        const label_y = header_y + (24 * fn_item_count);
                        Components.label(ui, label_x, label_y, function.name);
                    }
                }
            }
        }

    }
};

