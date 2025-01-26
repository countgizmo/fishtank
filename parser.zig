const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const token_module = @import("token.zig");
const Token = token_module.Token;
const TokenWithPosition = token_module.TokenWithPosition;

// Main idea:
// Read a Clojure file
// Give it to the main program
// Main program gets the contents and the meta data
// Main program runs lexer to get all the tokens
// Main program runs the parser giving it the meta data so that it can create Module
// and put all the parsed Expressions into the module
// Main program calls visualization module

// Represents a Clojure file
pub const Module = struct {
    name: []const u8,
    file_path: []const u8,

    // TODO(evgheni): important bit is to represent requires.
    // Initially can be a simple way to just track which other namespaces (modules) it requires
    // so we can build graphs for example.

    expressions: ArrayList(Expression),


    //TODO(evgheni): add more meta data like the list of requires, line counts, etc.

    pub fn init(allocator: Allocator, file_path: []const u8) !Module {
        return Module{
            .name = file_path, //TODO(evgheni): extract the file name only or the ns name
            .file_path = file_path,
            .expressions = ArrayList(Expression).init(allocator),
        };
    }

    pub fn deinit(self: *Module) void {
        for (self.expressions.items) |*expression| {
            expression.deinit();
        }
        self.expressions.deinit();
    }

    pub fn addExpression(self: *Module, expr: Expression) !void {
        try self.expressions.append(expr);
    }
};


//TODO(evgheni): Add maps, sets, vectors
const ExpressionKind = enum {
    List,
    Symbol,
    Literal
};

pub const Expression = struct {
    kind: ExpressionKind,

    value: union(enum) {
        list: ArrayList(Expression),
        symbol: []const u8,
        literal: Token,
    },

    position: struct {
        line: usize,
        column: usize,
    },

    pub fn create(allocator: Allocator, kind: ExpressionKind, token: TokenWithPosition) !Expression {
        return switch (kind) {
            .List => Expression {
                .kind = kind,
                .value = .{
                    .list = ArrayList(Expression).init(allocator),
                },
                .position = .{
                    .line = token.line,
                    .column = token.column,
                },
            },
        };
    }

    pub fn deinit(self: *Expression) void {
        switch (self.kind) {
            .List => {
                for (self.value.list.items) |*expr| {
                    expr.deinit();
                }
                self.value.list.deinit();
            },
            else => {}, // Other types don't own memory
        }
    }
};

pub const ParseError = error{
    UnexpectedToken,
    UnexpectedEOF,
    UnbalancedParentheses,
    OutOfMemory,
};

pub const Parser = struct {
    allocator: Allocator,
    current: usize,
    tokens: []const TokenWithPosition,

    pub fn init(allocator: Allocator) Parser {
        return Parser{
            .current = 0,
            .allocator = allocator,
            .tokens =  &[_]TokenWithPosition{},
        };
    }

    pub fn parse(self: *Parser, file_path: []const u8, tokens: []const TokenWithPosition) !Module {
        if (tokens.len == 0) {
            return ParseError.UnexpectedEOF;
        }

        self.tokens = tokens;

        var module = try Module.init(self.allocator, file_path);
        errdefer module.deinit();

        return module;
    }

    fn peek(self: Parser) ?TokenWithPosition {
        if (self.current >= self.tokens.len) {
            return null;
        }

        return self.tokens[self.current];
    }

    fn advance(self: Parser) ?TokenWithPosition {
        if (self.current >= self.tokens.len) {
            return null;
        }

        const token = self.tokens[self.current];
        self.current += 1;
        return token;
    }
};


test "parse namespace with multiple expressions" {
    const testing = std.testing;
    const tokens = [_]TokenWithPosition{
        // (ns my-namespace)
        .{ .token = .LeftParen, .line = 1, .column = 1 },
        .{ .token = .{ .Symbol = "ns" }, .line = 1, .column = 2 },
        .{ .token = .{ .Symbol = "my-namespace" }, .line = 1, .column = 5 },
        .{ .token = .RightParen, .line = 1, .column = 16 },

        // (def x 42)
        .{ .token = .LeftParen, .line = 3, .column = 1 },
        .{ .token = .{ .Symbol = "def" }, .line = 3, .column = 2 },
        .{ .token = .{ .Symbol = "x" }, .line = 3, .column = 6 },
        .{ .token = .{ .Int = 42 }, .line = 3, .column = 8 },
        .{ .token = .RightParen, .line = 3, .column = 10 },

        .{ .token = .EOF, .line = 4, .column = 1 },
    };

    var parser = Parser.init(testing.allocator);
    var result = try parser.parse("test_file.clj", &tokens);
    defer result.deinit();

    // Check that we got a module
    try testing.expectEqualStrings(result.file_path, "test_file.clj");
    // try testing.expectEqual(result.expressions.items.len, 2);


    // // Check that we have two top-level expressions
    // try testing.expectEqual(result.value.module.items.len, 2);
    //
    // // Check the ns expression
    // const ns_expr = result.value.module.items[0];
    // try testing.expectEqual(ns_expr.kind, .List);
    // try testing.expectEqual(ns_expr.value.list.items.len, 2);
    // try testing.expectEqualStrings(ns_expr.value.list.items[0].value.symbol, "ns");
    // try testing.expectEqualStrings(ns_expr.value.list.items[1].value.symbol, "my-namespace");
    //
    // // Check the def expression
    // const def_expr = result.value.module.items[1];
    // try testing.expectEqual(def_expr.kind, .List);
    // try testing.expectEqual(def_expr.value.list.items.len, 3);
    // try testing.expectEqualStrings(def_expr.value.list.items[0].value.symbol, "def");
    // try testing.expectEqualStrings(def_expr.value.list.items[1].value.symbol, "x");
    // try testing.expectEqual(def_expr.value.list.items[2].value.literal, Token{ .Int = 42 });
}
