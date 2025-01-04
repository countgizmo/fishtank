const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const token = @import("token.zig");
const Token = token.Token;

//TODO(evgheni): Add maps, sets, vectors
const ExpressionKind = enum {
    Module, // File/Namespace, kinda like a list of expressions but with metadata
    List,
    Symbol,
    Literal
};

pub const Expression = struct {
    kind: ExpressionKind,

    value: union(enum) {
        module: ArrayList(Expression),
        list: ArrayList(Expression),
        symbol: []const u8,
        literal: Token,
    },

    position: struct {
        line: usize,
        column: usize,
    },
};
