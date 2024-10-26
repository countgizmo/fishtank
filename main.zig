const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ascii = std.ascii;
const expect = std.testing.expect;

const NodeType = enum { atom, list, vector, set, map };

const Node = struct {
    name: []const u8,
    type: NodeType,
    children: ArrayList(*Node),
};

fn createNode(allocator: Allocator, name: []const u8, nodeType: NodeType) ?*Node {
    const node_result = allocator.create(Node);

    if (node_result) |node| {
        node.name = name;
        node.type = nodeType;
        node.children = ArrayList(*Node).init(allocator);
        return node;
    } else |err| {
        std.debug.print("Failed to allocated Node: {}\n", .{err});
    }

    return null;
}


fn parseList(allocator: Allocator, buffer: []const u8, bytes_walked: *usize) ?*Node {
    std.debug.print("Parsing a list...\n", .{});
    var current: [100]u8 = undefined;
    var current_idx: usize = 0;
    var list = createNode(allocator, "list", .list);

    if (list == null) {
        return null;
    }

    var i: usize = 0;
    while (i < buffer.len) {
        bytes_walked.* +=1;
        const byte = buffer[i];
        if (ascii.isAlphabetic(byte) or ascii.isDigit(byte)) {
            current[current_idx] = byte;
            current_idx+=1;
        } else if (ascii.isWhitespace(byte)) {
            //TODO(evgheni): eat the whitespace.
            if (createNode(allocator, current[0..current_idx], .atom)) |node| {
                std.debug.print("Node before whitespace found: {s}\n", .{node.name});
                list.?.children.append(node) catch |err| {
                    std.debug.print("Failed to append Node to List: {}\n", .{err});
                };
            }
            current_idx = 0;
        } else if (byte == ')') {
            // If the list ends right after another list ends. Example: (def a (+ 1 1)) <--- like so
            if (current_idx == 0) {
                return list;
            }
            if (createNode(allocator, current[0..current_idx], .atom)) |node| {
                std.debug.print("Node before ')' found: {s}\n", .{node.name});
                list.?.children.append(node) catch |err| {
                    std.debug.print("Failed to append Node to List: {}\n", .{err});
                };
            }
            return list;
        } else if (byte == '(') {
            var list_bytes: usize = 0;
            const list_result = parseList(allocator,  buffer[i+1..], &list_bytes);
            if (list_result) |nested_list| {
                std.debug.print("List of size {d} found\n", .{list.?.children.items.len});
                list.?.children.append(nested_list) catch |err| {
                    std.debug.print("Failed to append List to List: {}\n", .{err});
                };
                i += list_bytes;
            }
            current_idx = 0;
        }
        i+=1;
    }

    return null;
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const buffer = "(def magic (1 1))";
    var bytes_walked: usize = 0;
    const list = parseList(gpa.allocator(), buffer[1..buffer.len], &bytes_walked);
    std.debug.print("Main list size: {d}\n", .{list.?.children.items.len});
}


// test "parse a simple node" {
//     const buffer = "(def 69)";
//     parse(buffer);
// }
