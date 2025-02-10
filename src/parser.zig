const std = @import("std");
const testing = std.testing;
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
            .name = "",
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
    Int,
    Keyword,
    Vector
};

pub const Expression = struct {
    kind: ExpressionKind,

    value: union(enum) {
        list: ArrayList(Expression),
        symbol: []const u8,
        int: i64,
        keyword: []const u8,
        vector: ArrayList(Expression),
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
            .Symbol => Expression {
                .kind = kind,
                .value = .{
                    .symbol = switch(token.token) {
                        .Symbol => |s| s,
                        else => return ParseError.UnexpectedToken,
                    },
                },
                .position = .{
                    .line = token.line,
                    .column = token.column,
                },
            },
            .Keyword => Expression {
                .kind = kind,
                .value = .{
                    .keyword = token.token.Keyword,
                },
                .position = .{
                    .line = token.line,
                    .column = token.column,
                },
            },
            .Int => Expression {
                .kind = kind,
                .value = .{
                    .int = token.token.Int,
                },
                .position = .{
                    .line = token.line,
                    .column = token.column,
                },
            },
            .Vector => Expression {
                .kind = kind,
                .value = .{
                    .vector = ArrayList(Expression).init(allocator),
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
            .Vector => {
                for (self.value.vector.items) |*expr| {
                    expr.deinit();
                }
                self.value.vector.deinit();
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

    pub fn init(allocator: Allocator, tokens: []const TokenWithPosition) Parser {
        return Parser{
            .current = 0,
            .allocator = allocator,
            .tokens =  tokens,
        };
    }

    fn isNs(expression: Expression) bool {
        if (expression.kind == .List) {
            return std.mem.eql(u8, "ns", expression.value.list.items[0].value.symbol);
        }

        return false;
    }

    pub fn parse(self: *Parser, file_path: []const u8) !Module {
        if (self.tokens.len == 0) {
            return ParseError.UnexpectedEOF;
        }

        var module = try Module.init(self.allocator, file_path);
        errdefer module.deinit();

        while (self.peek()) |current_token | {
            switch (current_token.token) {
                .EOF => break,
                else => {
                    const expression = try self.parseExpression();
                    if (std.mem.eql(u8, module.name, "") and isNs(expression)) {
                        module.name = expression.value.list.items[1].value.symbol;
                    }
                    try module.addExpression(expression);
                },
            }
        }

        return module;
    }

    fn parseExpression(self: *Parser) ParseError!Expression {
        const current_token = self.peek() orelse return ParseError.UnexpectedToken;

        return switch (current_token.token) {
            .LeftParen => self.parseList(),
            .LeftBracket => self.parseVector(),
            .Symbol => blk: {
                _ = self.advance();
                break :blk try Expression.create(self.allocator, .Symbol, current_token);
            },
            .Keyword => blk: {
                _ = self.advance();
                break :blk try Expression.create(self.allocator, .Keyword, current_token);
            },
            .Int => blk: {
                _ = self.advance();
                break :blk try Expression.create(self.allocator, .Int, current_token);
            },

            else => ParseError.UnexpectedToken,
        };
    }

    fn parseList(self: *Parser) ParseError!Expression {
        const left_paren = self.advance() orelse return ParseError.UnexpectedEOF;
        var list_expression = try Expression.create(self.allocator, .List, left_paren);
        errdefer list_expression.deinit();

        while (self.peek()) |current_token| {
            switch (current_token.token) {
                .RightParen => {
                    _ = self.advance();
                    return list_expression;
                },
                .EOF => return ParseError.UnbalancedParentheses,
                else => {
                    const expression = try self.parseExpression();
                    try list_expression.value.list.append(expression);
                },
            }
        }

        return ParseError.UnexpectedEOF;
    }

    fn parseVector(self: *Parser) ParseError!Expression {
        const left_bracket = self.advance() orelse return ParseError.UnexpectedEOF;
        var list_expression = try Expression.create(self.allocator, .Vector, left_bracket);
        errdefer list_expression.deinit();

        while (self.peek()) |current_token| {
            switch (current_token.token) {
                .RightBracket => {
                    _ = self.advance();
                    return list_expression;
                },
                .EOF => return ParseError.UnbalancedParentheses,
                else => {
                    const expression = try self.parseExpression();
                    try list_expression.value.vector.append(expression);
                },
            }
        }

        return ParseError.UnexpectedEOF;
    }

    fn peek(self: Parser) ?TokenWithPosition {
        if (self.current >= self.tokens.len) {
            return null;
        }

        return self.tokens[self.current];
    }

    fn advance(self: *Parser) ?TokenWithPosition {
        if (self.current >= self.tokens.len) {
            return null;
        }

        const token = self.tokens[self.current];
        self.current += 1;
        return token;
    }
};


test "parse namespace with multiple expressions" {
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

    var parser = Parser.init(testing.allocator, &tokens);
    var result = try parser.parse("test_file.clj");
    defer result.deinit();

    // Check module's name
    try testing.expectEqualStrings("my-namespace", result.name);

    // Check that we got a module with 2 expressions
    try testing.expectEqualStrings(result.file_path, "test_file.clj");
    try testing.expectEqual(result.expressions.items.len, 2);

    // Check the ns expression
    const ns_expr = result.expressions.items[0];
    try testing.expectEqual(ns_expr.kind, .List);
    try testing.expectEqual(ns_expr.value.list.items.len, 2);
    try testing.expectEqualStrings(ns_expr.value.list.items[0].value.symbol, "ns");
    try testing.expectEqualStrings(ns_expr.value.list.items[1].value.symbol, "my-namespace");

    // Check the def expression
    const def_expr = result.expressions.items[1];
    try testing.expectEqual(def_expr.kind, .List);
    try testing.expectEqual(def_expr.value.list.items.len, 3);
    try testing.expectEqualStrings(def_expr.value.list.items[0].value.symbol, "def");
    try testing.expectEqualStrings(def_expr.value.list.items[1].value.symbol, "x");
    try testing.expectEqual(def_expr.value.list.items[2].value.int, 42);
}

test "parse a simple vector" {
    const tokens = [_]TokenWithPosition{
        // [my-fun 2 :potato]
        .{ .token = .LeftBracket, .line = 1, .column = 1 },
        .{ .token = .{ .Symbol = "my-fun" }, .line = 1, .column = 2 },
        .{ .token = .{ .Int = 2 }, .line = 1, .column = 9 },
        .{ .token = .{ .Keyword = ":potato" }, .line = 1, .column = 11 },
        .{ .token = .RightBracket, .line = 1, .column = 18 },

        .{ .token = .EOF, .line = 2, .column = 1 },
    };

    var parser = Parser.init(testing.allocator, &tokens);
    var result = try parser.parse("test_file.clj");
    defer result.deinit();

    const vec = result.expressions.items[0];
    try testing.expectEqual(vec.kind, .Vector);
    try testing.expectEqual(vec.value.vector.items.len, 3);
    try testing.expectEqualStrings(vec.value.vector.items[0].value.symbol, "my-fun");
    try testing.expectEqual(vec.value.vector.items[1].value.int, 2);
    try testing.expectEqual(vec.value.vector.items[2].value.keyword, ":potato");
}
