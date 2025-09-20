const std = @import("std");
const testing = std.testing;
const expectEqual = testing.expectEqual;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const Allocator = std.mem.Allocator;
const token_module = @import("token.zig");
const Token = token_module.Token;
const TokenWithPosition = token_module.TokenWithPosition;
const Components = @import("ui/components.zig");
const UiState = @import("ui/state.zig").UiState;

pub const ReferOption = union(enum) {
    all,
    symbols: ArrayList([]const u8)
};

pub const RequiredLib = struct {
    name: []const u8,
    as: ?[]const u8,
    refer: ?ReferOption,
    //TODO(evgheni): as-alias, etc.

    pub fn deinit(self: *RequiredLib, allocator: Allocator) void {
        if (self.refer) |*ref| {
            switch (ref.*) {
                .symbols => |*list| list.deinit(allocator),
                .all => {},
            }
        }
    }
};

pub const Position = struct {
    line: usize,
    column: usize,
};

pub const Function = struct {
    name: []const u8,
    position: Position,
};

// Represents a Clojure file
pub const Module = struct {
    name: []const u8,
    file_path: []const u8,
    allocator: Allocator,

    required_modules: ArrayList(RequiredLib),
    expressions: ArrayList(Expression),
    functions: ArrayList(Function),


    //TODO(evgheni): add more meta data like line counts, etc.

    pub fn init(allocator: Allocator, file_path: []const u8) !Module {
        return Module {
            .name = "",
            .file_path = file_path,
            .allocator = allocator,
            .required_modules = .empty,
            .expressions = .empty,
            .functions = .empty,
        };
    }

    pub fn deinit(self: *Module) void {
        for (self.expressions.items) |*expression| {
            expression.deinit(self.allocator);
        }


        for (self.required_modules.items) |*req_module| {
            req_module.deinit(self.allocator);
        }

        self.expressions.deinit(self.allocator);
        self.required_modules.deinit(self.allocator);
        self.functions.deinit(self.allocator);
    }

    pub fn addRequiredLib(self: *Module, lib: RequiredLib) !void {
        try self.required_modules.append(self.allocator, lib);
    }

    pub fn addExpression(self: *Module, expr: Expression) !void {
        try self.expressions.append(self.allocator, expr);
    }

    pub fn render(self: Module, ui: *UiState) void {
        Components.header(ui, ui.next_x + 20, 100, "Module:");
        Components.header(ui, ui.next_x + 100, 100, self.name);

        if (self.required_modules.items.len > 0) {
            Components.header(ui, ui.next_x + 20, 120, "Requires:");
            for (self.required_modules.items, 0..) |req, idx| {
                const step = @as(i32, @intCast(idx * 20));
                Components.label(ui, ui.next_x + 40, 140+step, req.name);

                if (req.as) |alias| {
                    Components.label(ui, ui.next_x + 40+170, 140 + step, "->");
                    Components.label(ui, ui.next_x + 40+200, 140 + step, alias);
                }
            }
        }

        Components.header(ui, ui.next_x + 20, 220, "Functions:");
        for (self.functions.items, 0..) |defn, idx| {
            const step = @as(i32, @intCast(idx * 20));
            Components.label(ui, ui.next_x + 40, 240+step, defn.name);
        }
    }
};

const ExpressionKind = enum {
    List,
    String,
    Symbol,
    Int,
    Keyword,
    Vector,
    Map,
    Set,

    Unparsed,
};

pub const Expression = struct {
    kind: ExpressionKind,

    value: union(enum) {
        list: ArrayList(Expression),
        symbol: []const u8,
        int: i64,
        keyword: []const u8,
        string: []const u8,
        vector: ArrayList(Expression),
        map: HashMap(Expression, Expression, Expression.HashContext, 80),
        set: ArrayList(Expression),
        unparsed: struct {
            reason: []const u8,
            start_token: TokenWithPosition,
            skipped_token: ?TokenWithPosition,
        },
    },

    position: Position,
    quoted: bool = false,
    deref: bool = false,
    unquoted: bool = false,

    // fn hashExpression(expr: Expression) u64 {
    //     var hasher = std.hash.Wyhash.init(0);
    //
    //     switch (expr.kind) {
    //         .String => {
    //             hasher.update(expr.value.string);
    //         },
    //         .Symbol => {
    //             hasher.update(expr.value.symbol);
    //         },
    //         .Int => {
    //             hasher.update(std.mem.asBytes(&expr.value.int));
    //         },
    //         .Keyword => {
    //             hasher.update(expr.value.keyword);
    //         },
    //         .Map => {
    //             hasher.update(std.mem.asBytes(&expr.value.int));
    //         }
    //     }
    //     // Hash the slice contents, not the pointer
    //     hasher.update(expr.name);
    //
    //     // Hash other fields
    //     hasher.update(std.mem.asBytes(&expr.value));
    //
    //     return hasher.final();
    // }

    pub const HashContext = struct {
        pub fn hash(_: HashContext, e: Expression) u64 {
            var hasher = std.hash.Wyhash.init(0);
            std.hash.autoHashStrat(&hasher, &e, .Deep);
            return hasher.final();
        }

        pub fn eql(_: HashContext, a: Expression, b: Expression) bool {
            return std.meta.eql(a, b);
        }
    };

    pub fn create(allocator: Allocator, kind: ExpressionKind, token: TokenWithPosition) !Expression {
        return switch (kind) {
            .List => Expression {
                .kind = kind,
                .value = .{
                    .list = .empty,
                },
                .position = .{
                    .line = token.line,
                    .column = token.column,
                },
            },
            .Set => Expression {
                .kind = kind,
                .value = .{
                    .set = .empty,
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
            .String => Expression {
                .kind = kind,
                .value = .{
                    .string = token.token.String,
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
                    .vector = .empty,
                },
                .position = .{
                    .line = token.line,
                    .column = token.column,
                },
            },
            .Map => Expression {
                .kind = kind,
                .value = .{
                    .map = HashMap(Expression, Expression, Expression.HashContext, 80).init(allocator),
                },
                .position = .{
                    .line = token.line,
                    .column = token.column,
                },
            },
            .Unparsed => return ParseError.UnexpectedToken,
        };
    }

    pub fn deinit(self: *Expression, allocator: Allocator) void {
        switch (self.kind) {
            .List => {
                for (self.value.list.items) |*expr| {
                    expr.deinit(allocator);
                }
                self.value.list.deinit(allocator);
            },
            .Vector => {
                for (self.value.vector.items) |*expr| {
                    expr.deinit(allocator);
                }
                self.value.vector.deinit(allocator);
            },
            .Map => {
                var iter = self.value.map.iterator();

                while (iter.next()) |item| {
                    item.key_ptr.deinit(allocator);
                    item.value_ptr.deinit(allocator);
                }

                self.value.map.deinit();
            },
            .Set => {
                for (self.value.set.items) |*expr| {
                    expr.deinit(allocator);
                }
                self.value.set.deinit(allocator);
            },
            else => {}, // Other types don't own memory
        }
    }
};

pub const ParseError = error{
    NoTokens,
    UnexpectedEndOfList,
    UnexpectedEndOfVector,
    UnexpectedToken,
    UnexpectedTokenAfterPound,
    UnexpectedEOF,
    UnbalancedParentheses,
    UnbalancedBraces,
    OutOfMemory,
    UnclosedMap,
    UneventMapItems,
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

    fn isDefn(expression: Expression) bool {
        if (expression.kind == .List) {
            return std.mem.eql(u8, "defn", expression.value.list.items[0].value.symbol);
        }

        return false;
    }

    // This is what we're aiming at initially
    // (ns my-namespace
    //   "Optional docstring"
    //   {:author "Someone"}  ; Optional metadata
    //   (:require [clojure.string :as str]
    //             [other.lib :as other]
    //             simple.require))

    fn parseRequiredLib(self: Parser, expression: Expression) ?RequiredLib{
        if (expression.kind == .Vector) {
            switch (expression.value.vector.items.len) {
                1 => {
                    return RequiredLib {
                        .name = expression.value.vector.items[0].value.symbol,
                        .as = null,
                        .refer = null,
                    };
                },
                3 => {
                    const option = expression.value.vector.items[1].value.keyword;
                    if (std.mem.eql(u8, option, ":as")) {
                        return RequiredLib {
                            .name = expression.value.vector.items[0].value.symbol,
                            .as = expression.value.vector.items[2].value.symbol,
                            .refer = null,
                        };

                    }
                    if (std.mem.eql(u8, option, ":refer")) {
                        const refer_expr = expression.value.vector.items[2];

                        var req_lib = RequiredLib {
                            .name = expression.value.vector.items[0].value.symbol,
                            .as = null,
                            .refer = null,
                        };

                        switch (refer_expr.kind) {
                            .Keyword => {
                                if (std.mem.eql(u8, refer_expr.value.keyword, ":all")) {
                                    req_lib.refer = .{ .all = {} };
                                }
                            },
                            .Vector => {
                                var refer_list:ArrayList([]const u8) = .empty;
                                for (refer_expr.value.vector.items) |refer_item| {
                                    refer_list.append(self.allocator, refer_item.value.symbol) catch {
                                        refer_list.deinit(self.allocator);
                                        return null;
                                    };
                                }
                                req_lib.refer = .{ .symbols = refer_list };
                            },
                            else => {},
                        }
                        return req_lib;
                    }
                },
                else => {
                    return null;
                }
            }
        }

        if (expression.kind == .Symbol) {
            return RequiredLib {
                .name = expression.value.symbol,
                .as = null,
                .refer = null,
            };
        }

        return null;
    }

    fn parseNs(self: Parser, module: *Module, expression: Expression) !void {
        module.name = expression.value.list.items[1].value.symbol;

        // (ns something.core ... )
        // 0 = ns
        // 1 = namespace name
        if (expression.value.list.items.len > 2) {
            for (expression.value.list.items) |item| {
                switch (item.kind) {
                    .String => {
                        //TODO(evgheni): add docstring to the module
                    },
                    .List => {
                        const require = item.value.list;
                        for (require.items) |req_item| {
                            if (self.parseRequiredLib(req_item)) |lib| {
                                try module.addRequiredLib(lib);
                            }
                        }
                    },
                    else => {}
                }
            }
        }
    }

    fn parseDefn(module: *Module, expression: Expression) !void {
        const defn = Function{
            .name = expression.value.list.items[1].value.symbol,
            .position = expression.position,
        };

        try module.functions.append(module.allocator, defn);
    }

    pub fn parse(self: *Parser, file_path: []const u8) !Module {
        if (self.tokens.len == 0) {
            return ParseError.NoTokens;
        }

        var module = try Module.init(self.allocator, file_path);
        errdefer module.deinit();

        while (self.peek()) |current_token | {
            switch (current_token.token) {
                .EOF => break,
                else => {
                    const expression = try self.parseExpression();

                    if (std.mem.eql(u8, module.name, "") and isNs(expression)) {
                        try self.parseNs(&module, expression);
                    } else if (isDefn(expression)) {
                        try parseDefn(&module, expression);
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
            .Tilde => {
                _ = self.advance();
                var expr = try self.parseExpression();
                expr.unquoted = true;
                return expr;
            },
            .At => {
                _ = self.advance();
                var expr = try self.parseExpression();
                expr.deref = true;
                return expr;
            },
            .LeftParen => self.parseList(),
            .LeftBracket => self.parseVector(),
            .LeftBrace => self.parseMap(),
            .String => {
                _ = self.advance();
                return try Expression.create(self.allocator, .String, current_token);
            },
            .Symbol => {
                _ = self.advance();
                return try Expression.create(self.allocator, .Symbol, current_token);
            },
            .Keyword => {
                _ = self.advance();
                return try Expression.create(self.allocator, .Keyword, current_token);
            },
            .Int =>  {
                _ = self.advance();
                return try Expression.create(self.allocator, .Int, current_token);
            },
            .Quote => {
                _ = self.advance();
                var expr = try self.parseExpression();
                expr.quoted = true;
                return expr;
            },
            .Pound => {
                _ = self.advance();
                const after_pound = self.peek() orelse return ParseError.UnexpectedEOF;
                return switch (after_pound.token) {
                    .LeftBrace => self.parseSet(),
                    .LeftParen => self.parseList(),
                    .Symbol => {
                        if (std.mem.eql(u8, after_pound.token.Symbol, "js")) {
                            _ = self.advance();
                            return Expression {
                                .kind = .Symbol,
                                .value = .{ .symbol = "#js" },
                                .position = .{
                                    .line = current_token.line,
                                    .column = current_token.column,
                                },
                            };
                        }else {
                            std.log.err("Unhandle error parsing token after pound '{s}' at column {d} line {d}",
                            .{after_pound.token.Symbol, after_pound.column, after_pound.line});
                            return ParseError.UnexpectedTokenAfterPound;
                        }
                    },
                    else => {
                        const skipped = self.advance();
                        return Expression {
                            .kind = .Unparsed,
                            .value = .{
                                .unparsed = .{
                                    .reason = "Unsupported # form",
                                    .start_token = after_pound,
                                    .skipped_token = skipped
                                }
                            },
                            .position = .{
                                .line = after_pound.line,
                                .column = after_pound.column,
                            },
                        };
                    }
                };
            },

            else => {
                const start_token = current_token;
                _ = self.advance();
                const skipped_token = self.peek();

                return Expression {
                    .kind = .Unparsed,
                    .value = .{
                        .unparsed = .{
                            .reason = "Unsupported # form",
                            .start_token = start_token,
                            .skipped_token = skipped_token
                        }
                    },
                    .position = .{
                        .line = start_token.line,
                        .column = start_token.column,
                    },
                };
            },
        };
    }

    fn parseList(self: *Parser) ParseError!Expression {
        const left_paren = self.advance() orelse return ParseError.UnexpectedEOF;
        var list_expression = try Expression.create(self.allocator, .List, left_paren);
        errdefer list_expression.deinit(self.allocator);

        while (self.peek()) |current_token| {
            switch (current_token.token) {
                .RightParen => {
                    _ = self.advance();
                    return list_expression;
                },
                .EOF => return ParseError.UnbalancedParentheses,
                else => {
                    const expression = try self.parseExpression();
                    try list_expression.value.list.append(self.allocator, expression);
                },
            }
        }

        return ParseError.UnexpectedEndOfList;
    }

    fn parseVector(self: *Parser) ParseError!Expression {
        const left_bracket = self.advance() orelse return ParseError.UnexpectedEOF;
        var vector_expression = try Expression.create(self.allocator, .Vector, left_bracket);
        errdefer vector_expression.deinit(self.allocator);

        const start_token = self.peek();
        while (self.peek()) |current_token| {
            switch (current_token.token) {
                .RightBracket => {
                    _ = self.advance();
                    return vector_expression;
                },
                .EOF => return ParseError.UnbalancedParentheses,
                else => {
                    const expression = try self.parseExpression();
                    try vector_expression.value.vector.append(self.allocator, expression);
                },
            }
        }

        std.log.debug("start token = {any} last token {any}", .{start_token, self.peek()});
        return ParseError.UnexpectedEndOfVector;
    }

    fn isPoundJS(exp: ?Expression) bool {
        if (exp) |the_exp| {
            if (the_exp.kind == .Symbol) {
                return (std.mem.eql(u8, the_exp.value.symbol, "#js"));
            }
        }
        return false;
    }

    fn parseMap(self: *Parser) ParseError!Expression {
        const left_brace = self.advance() orelse return ParseError.UnexpectedEOF;
        var map_expression = try Expression.create(self.allocator, .Map, left_brace);
        errdefer map_expression.deinit(self.allocator);


        var is_key = true;
        var key: ?Expression = null;
        var value: ?Expression = null;

        while (self.peek()) |current_token| {
            switch (current_token.token) {
                .RightBrace => {
                    if (key != null and value == null) {

                        std.log.err("Uneven map items at line {} col {}",
                        .{current_token.line, current_token.column});


                        if (key.?.kind == .Symbol) {
                            std.log.warn("last key = {s} last val = {any}", .{key.?.value.symbol, value});
                        }

                        return ParseError.UneventMapItems;
                    }

                    _ = self.advance();
                    return map_expression;
                },
                .EOF => return ParseError.UnclosedMap,
                else => {
                    if (is_key) {
                        key = try self.parseExpression();
                        if (isPoundJS(key)) {
                            // Skipping #js
                            key = null;
                            continue;
                        }
                    } else {
                        value = try self.parseExpression();
                        if (isPoundJS(value)) {
                            // Skipping #js
                            value = null;
                            continue;
                        }
                    }

                    if (key != null and value != null) {
                        try map_expression.value.map.put(key.?, value.?);
                        key = null;
                        value = null;
                    }

                    is_key = !is_key;
                },
            }
        }

        return ParseError.UnexpectedEOF;
    }

    fn parseSet(self: *Parser) ParseError!Expression {
        const set_start = self.advance() orelse return ParseError.UnexpectedEOF;
        var set_expression = try Expression.create(self.allocator, .Set, set_start);
        errdefer set_expression.deinit(self.allocator);

        while (self.peek()) |current_token| {
            switch (current_token.token) {
                .RightBrace => {
                    _ = self.advance();
                    return set_expression;
                },
                .EOF => return ParseError.UnbalancedBraces,
                else => {
                    const expression = try self.parseExpression();
                    try set_expression.value.set.append(self.allocator, expression);
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

test "parse a ns form" {
    const tokens = [_]TokenWithPosition{
        // (ns my-namespace
        //   (:require [clojure.string :as str]
        //             [other.lib :as other]
        //             simple.require))

        .{ .token = .LeftParen, .line = 1, .column = 1 },
        .{ .token = .{ .Symbol = "ns" }, .line = 1, .column = 2 },
        .{ .token = .{ .Symbol = "my-namespace" }, .line = 1, .column = 5 },
        .{ .token = .LeftParen, .line = 2, .column = 22 },
        .{ .token = .{ .Keyword = ":require" }, .line = 2, .column = 3 },

        .{ .token = .LeftBracket, .line = 2, .column = 12 },
        .{ .token = .{ .Symbol = "clojure.string" }, .line = 2, .column = 13 },
        .{ .token = .{ .Keyword = ":as" }, .line = 2, .column = 28 },
        .{ .token = .{ .Symbol = "str" }, .line = 2, .column = 32 },
        .{ .token = .RightBracket, .line = 2, .column = 35},

        .{ .token = .LeftBracket, .line = 3, .column = 12 },
        .{ .token = .{ .Symbol = "other.lib" }, .line = 3, .column = 13 },
        .{ .token = .{ .Keyword = ":as" }, .line = 3, .column = 23 },
        .{ .token = .{ .Symbol = "other" }, .line = 3, .column = 27 },
        .{ .token = .RightBracket, .line = 3, .column = 33},


        .{ .token = .{ .Symbol = "simple.require" }, .line = 3, .column = 28 },
        .{ .token = .RightParen, .line = 3, .column = 44 },
        .{ .token = .RightParen, .line = 3, .column = 45 },
        .{ .token = .EOF, .line = 4, .column = 1 },
    };

    var parser = Parser.init(testing.allocator, &tokens);
    var module = try parser.parse("test_file.clj");
    defer module.deinit();

    try testing.expectEqualStrings("my-namespace", module.name);
    try testing.expectEqual(3, module.required_modules.items.len);

    try testing.expectEqualStrings("clojure.string", module.required_modules.items[0].name);
    try testing.expectEqualStrings("str", module.required_modules.items[0].as.?);

    try testing.expectEqualStrings("other.lib", module.required_modules.items[1].name);
    try testing.expectEqualStrings("other", module.required_modules.items[1].as.?);

    try testing.expectEqualStrings("simple.require", module.required_modules.items[2].name);
    try testing.expectEqual(null, module.required_modules.items[2].as);
}

test "parse a simple map" {
    // {:human/name "Abobo"
    //  :human/age 124
    //  :human/size :extra-large}
    const tokens = [_]TokenWithPosition{
        .{ .token = .LeftBrace, .column = 1, .line = 1 },
        .{ .token = .{ .Keyword = ":human/name" }, .column = 2, .line = 1 },
        .{ .token = .{ .String = "Abobo" }, .column = 14, .line = 1 },
        .{ .token = .{ .Keyword = ":human/age" }, .column = 22, .line = 1 },
        .{ .token = .{ .Int = 124 }, .column = 33, .line = 1 },
        .{ .token = .{ .Keyword = ":human/size" }, .column = 37, .line = 1 },
        .{ .token = .{ .Keyword = ":extra_large" }, .column = 49, .line = 1 },
        .{ .token = .RightBrace, .column = 61, .line = 1 },
        .{ .token = .EOF, .column = 62, .line = 1 },
    };

    var parser = Parser.init(testing.allocator, &tokens);
    var module = try parser.parse("test_file.clj");
    defer module.deinit();

    const map = module.expressions.items[0];
    try expectEqual(map.kind, .Map);
    try expectEqual(3, map.value.map.count());
    const human_age = Expression {
        .kind = .Keyword,
        .value = .{
            .keyword = ":human/age",
        },
        // TODO(evgheni): I need to write my own hash/eql functions to make sure
        // I am not using position data for hashing.
        .position = .{
            .column = 22,
            .line = 1
        },
    };

    const human_name = Expression {
        .kind = .Keyword,
        .value = .{
            .keyword = ":human/name",
        },
        .position = .{
            .column = 2,
            .line = 1
        },
    };

    const human_size = Expression {
        .kind = .Keyword,
        .value = .{
            .keyword = ":human/size",
        },
        .position = .{
            .column = 37,
            .line = 1
        },
    };

    try expectEqual(map.value.map.get(human_age).?.value.int, 124);
    try expectEqual(map.value.map.get(human_name).?.value.string, "Abobo");
    try expectEqual(map.value.map.get(human_size).?.value.keyword, ":extra_large");
}

test "parse quoted symbol" {
    // 'foo
    const tokens = [_]TokenWithPosition{
        .{ .token = .Quote, .line = 1, .column = 1 },
        .{ .token = .{ .Symbol = "foo" }, .line = 1, .column = 2 },
        .{ .token = .EOF, .line = 1, .column = 5 },
    };

    var parser = Parser.init(testing.allocator, &tokens);
    var result = try parser.parse("test.clj");
    defer result.deinit();

    const expr = result.expressions.items[0];
    try testing.expectEqual(expr.kind, .Symbol);
    try testing.expectEqualStrings(expr.value.symbol, "foo");
    try testing.expectEqual(expr.quoted, true);
}

test "parse quoted list" {
    // '(a 1)
    const tokens = [_]TokenWithPosition{
        .{ .token = .Quote, .line = 1, .column = 1 },
        .{ .token = .LeftParen, .line = 1, .column = 2 },
        .{ .token = .{ .Symbol = "a" }, .line = 1, .column = 3 },
        .{ .token = .{ .Int = 1 }, .line = 1, .column = 5 },
        .{ .token = .RightParen, .line = 1, .column = 6 },
        .{ .token = .EOF, .line = 1, .column = 7 },
    };

    var parser = Parser.init(testing.allocator, &tokens);
    var result = try parser.parse("test.clj");
    defer result.deinit();

    const expr = result.expressions.items[0];
    try testing.expectEqual(expr.kind, .List);
    try testing.expectEqual(expr.quoted, true);
    try testing.expectEqual(expr.value.list.items.len, 2);
}

test "parse a simple set" {
    const tokens = [_]TokenWithPosition{
        // #{:a :b :c}
        .{ .token = .Pound, .line = 1, .column = 1 },
        .{ .token = .LeftBrace, .line = 1, .column = 2 },
        .{ .token = .{ .Keyword = ":a" }, .line = 1, .column = 3 },
        .{ .token = .{ .Keyword = ":b" }, .line = 1, .column = 6 },
        .{ .token = .{ .Keyword = ":c" }, .line = 1, .column = 9 },
        .{ .token = .RightBrace, .line = 1, .column = 11 },
        .{ .token = .EOF, .line = 1, .column = 12 },
    };

    var parser = Parser.init(testing.allocator, &tokens);
    var module = try parser.parse("test_file.clj");
    defer module.deinit();

    const set_expr = module.expressions.items[0];
    try testing.expectEqual(.Set, set_expr.kind);
    try testing.expectEqual(3, set_expr.value.set.items.len);

    // Check that all keywords are in the set
    const key_a = Expression {
        .kind = .Keyword,
        .value = .{ .keyword = ":a" },
        .position = .{ .line = 1, .column = 3 },
    };

    const key_b = Expression {
        .kind = .Keyword,
        .value = .{ .keyword = ":b" },
        .position = .{ .line = 1, .column = 6 },
    };

    const key_c = Expression {
        .kind = .Keyword,
        .value = .{ .keyword = ":c" },
        .position = .{ .line = 1, .column = 9 },
    };

    try testing.expectEqual(key_a, set_expr.value.set.items[0]);
    try testing.expectEqual(key_b, set_expr.value.set.items[1]);
    try testing.expectEqual(key_c, set_expr.value.set.items[2]);
}

test "parse ns with :refer :all" {
    const tokens = [_]TokenWithPosition{
        // (ns my-namespace
        //   (:require [clojure.string :refer :all]))

        .{ .token = .LeftParen, .line = 1, .column = 1 },
        .{ .token = .{ .Symbol = "ns" }, .line = 1, .column = 2 },
        .{ .token = .{ .Symbol = "my-namespace" }, .line = 1, .column = 5 },
        .{ .token = .LeftParen, .line = 2, .column = 3 },
        .{ .token = .{ .Keyword = ":require" }, .line = 2, .column = 4 },

        .{ .token = .LeftBracket, .line = 2, .column = 13 },
        .{ .token = .{ .Symbol = "clojure.string" }, .line = 2, .column = 14 },
        .{ .token = .{ .Keyword = ":refer" }, .line = 2, .column = 29 },
        .{ .token = .{ .Keyword = ":all" }, .line = 2, .column = 36 },
        .{ .token = .RightBracket, .line = 2, .column = 40 },

        .{ .token = .RightParen, .line = 2, .column = 41 },
        .{ .token = .RightParen, .line = 2, .column = 42 },
        .{ .token = .EOF, .line = 3, .column = 1 },
    };

    var parser = Parser.init(testing.allocator, &tokens);
    var module = try parser.parse("test_file.clj");
    defer module.deinit();

    try testing.expectEqualStrings("my-namespace", module.name);
    try testing.expectEqual(1, module.required_modules.items.len);

    const req = module.required_modules.items[0];
    try testing.expectEqualStrings("clojure.string", req.name);
    try testing.expectEqual(null, req.as);
    try testing.expect(req.refer != null);

    switch (req.refer.?) {
        .all => {}, // expected
        .symbols => |_| try testing.expect(false), // should not be symbols
    }
}

test "parse ns with :refer [symbols]" {
    const tokens = [_]TokenWithPosition{
        // (ns my-namespace
        //   (:require [clojure.string :refer [join split trim]]))

        .{ .token = .LeftParen, .line = 1, .column = 1 },
        .{ .token = .{ .Symbol = "ns" }, .line = 1, .column = 2 },
        .{ .token = .{ .Symbol = "my-namespace" }, .line = 1, .column = 5 },
        .{ .token = .LeftParen, .line = 2, .column = 3 },
        .{ .token = .{ .Keyword = ":require" }, .line = 2, .column = 4 },

        .{ .token = .LeftBracket, .line = 2, .column = 13 },
        .{ .token = .{ .Symbol = "clojure.string" }, .line = 2, .column = 14 },
        .{ .token = .{ .Keyword = ":refer" }, .line = 2, .column = 29 },

        .{ .token = .LeftBracket, .line = 2, .column = 36 },
        .{ .token = .{ .Symbol = "join" }, .line = 2, .column = 37 },
        .{ .token = .{ .Symbol = "split" }, .line = 2, .column = 42 },
        .{ .token = .{ .Symbol = "trim" }, .line = 2, .column = 48 },
        .{ .token = .RightBracket, .line = 2, .column = 52 },

        .{ .token = .RightBracket, .line = 2, .column = 53 },
        .{ .token = .RightParen, .line = 2, .column = 54 },
        .{ .token = .RightParen, .line = 2, .column = 55 },
        .{ .token = .EOF, .line = 3, .column = 1 },
    };

    var parser = Parser.init(testing.allocator, &tokens);
    var module = try parser.parse("test_file.clj");
    defer module.deinit();

    try testing.expectEqualStrings("my-namespace", module.name);
    try testing.expectEqual(@as(usize, 1), module.required_modules.items.len);

    const req = module.required_modules.items[0];
    try testing.expectEqualStrings("clojure.string", req.name);
    try testing.expectEqual(null, req.as);
    try testing.expect(req.refer != null);

    switch (req.refer.?) {
        .all => try testing.expect(false), // should not be :all
        .symbols => |syms| {
            try testing.expectEqual(@as(usize, 3), syms.items.len);
            try testing.expectEqualStrings("join", syms.items[0]);
            try testing.expectEqualStrings("split", syms.items[1]);
            try testing.expectEqualStrings("trim", syms.items[2]);
        },
    }
}

 test "parse #js reader macro" {
    const tokens = [_]TokenWithPosition{
        .{ .token = .Pound, .line = 1, .column = 1 },
        .{ .token = .{ .Symbol = "js" }, .line = 1, .column = 2 },
        .{ .token = .EOF, .line = 1, .column = 4 },
    };

    var parser = Parser.init(testing.allocator, &tokens);
    var module = try parser.parse("test.clj");
    defer module.deinit();

    try testing.expectEqual(1, module.expressions.items.len);

    const expr = module.expressions.items[0];
    try testing.expectEqual(ExpressionKind.Symbol, expr.kind);
    try testing.expectEqualStrings("#js", expr.value.symbol);
}

test "parse #js with nested map containing #js vector" {
    // #js {:removeRuleIds #js [1]}
    const tokens = [_]TokenWithPosition{
        .{ .token = .Pound, .line = 1, .column = 1 },
        .{ .token = .{ .Symbol = "js" }, .line = 1, .column = 2 },
        .{ .token = .LeftBrace, .line = 1, .column = 5 },
        .{ .token = .{ .Keyword = ":removeRuleIds" }, .line = 1, .column = 6 },
        .{ .token = .Pound, .line = 1, .column = 21 },
        .{ .token = .{ .Symbol = "js" }, .line = 1, .column = 22 },
        .{ .token = .LeftBracket, .line = 1, .column = 25 },
        .{ .token = .{ .Int = 1 }, .line = 1, .column = 26 },
        .{ .token = .RightBracket, .line = 1, .column = 27 },
        .{ .token = .RightBrace, .line = 1, .column = 28 },
        .{ .token = .EOF, .line = 1, .column = 29 },
    };

    var parser = Parser.init(testing.allocator, &tokens);
    var module = try parser.parse("test.clj");
    defer module.deinit();

    // Should have parsed the #js-tagged map
    try testing.expectEqual(2, module.expressions.items.len);

    const expr = module.expressions.items[0];
    try testing.expectEqual(ExpressionKind.Symbol, expr.kind);
    try testing.expectEqualStrings("#js", expr.value.symbol);

    const map = module.expressions.items[1];
    try testing.expectEqual(1, map.value.map.count());
}

test "parse map with anonymous function in :on-click" {
    // {:class "continue-btn"
    //  :on-click #(continue-with-existing-connection!
    //              {:!conn !conn
    //               :validating? validating?
    //               :error? error?
    //               :next-step! next-step!
    //               :!status !status})
    //  :disabled @validating?}
    const tokens = [_]TokenWithPosition{
        .{ .token = .LeftBrace, .line = 1, .column = 1 },
        .{ .token = .{ .Keyword = ":class" }, .line = 1, .column = 2 },
        .{ .token = .{ .String = "continue-btn" }, .line = 1, .column = 9 },

        .{ .token = .{ .Keyword = ":on-click" }, .line = 2, .column = 11 },
        .{ .token = .Pound, .line = 2, .column = 21 },
        .{ .token = .LeftParen, .line = 2, .column = 22 },
        .{ .token = .{ .Symbol = "continue-with-existing-connection!" }, .line = 2, .column = 23 },

        .{ .token = .LeftBrace, .line = 3, .column = 23 },
        .{ .token = .{ .Keyword = ":!conn" }, .line = 3, .column = 24 },
        .{ .token = .{ .Symbol = "!conn" }, .line = 3, .column = 31 },
        .{ .token = .{ .Keyword = ":validating?" }, .line = 4, .column = 24 },
        .{ .token = .{ .Symbol = "validating?" }, .line = 4, .column = 37 },
        .{ .token = .{ .Keyword = ":error?" }, .line = 5, .column = 24 },
        .{ .token = .{ .Symbol = "error?" }, .line = 5, .column = 32 },
        .{ .token = .{ .Keyword = ":next-step!" }, .line = 6, .column = 24 },
        .{ .token = .{ .Symbol = "next-step!" }, .line = 6, .column = 36 },
        .{ .token = .{ .Keyword = ":!status" }, .line = 7, .column = 24 },
        .{ .token = .{ .Symbol = "!status" }, .line = 7, .column = 33 },
        .{ .token = .RightBrace, .line = 7, .column = 41 },

        .{ .token = .RightParen, .line = 7, .column = 42 },

        .{ .token = .{ .Keyword = ":disabled" }, .line = 8, .column = 11 },
        .{ .token = .At, .line = 8, .column = 21 },
        .{ .token = .{ .Symbol = "validating??" }, .line = 8, .column = 22 },

        .{ .token = .RightBrace, .line = 8, .column = 34 },
        .{ .token = .EOF, .line = 8, .column = 35 },
    };

    var parser = Parser.init(testing.allocator, &tokens);
    var module = try parser.parse("test.clj");
    defer module.deinit();

    try testing.expectEqual(1, module.expressions.items.len);

    const outer_map = module.expressions.items[0];
    try testing.expectEqual(ExpressionKind.Map, outer_map.kind);
    try testing.expectEqual(3, outer_map.value.map.count()); // :class, :on-click, :disabled
}

test "parse deref symbol with @" {
    const tokens = [_]TokenWithPosition{
        .{ .token = .At, .line = 1, .column = 1 },
        .{ .token = .{ .Symbol = "validating?" }, .line = 1, .column = 2 },
        .{ .token = .EOF, .line = 1, .column = 14 },
    };

    var parser = Parser.init(testing.allocator, &tokens);
    var module = try parser.parse("test.clj");
    defer module.deinit();

    const expr = module.expressions.items[0];
    try testing.expectEqual(ExpressionKind.Symbol, expr.kind);
    try testing.expectEqualStrings("validating?", expr.value.symbol);
    try testing.expectEqual(true, expr.deref);
}
