const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const token = @import("token.zig");
const Token = token.Token;
const TokenWithPosition  = token.TokenWithPosition;

const LexerError = error {
    UnexpectedCharacter,
};

pub const Lexer = struct {
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
    line: usize,
    column: usize,

    pub fn init(allocator: Allocator, source: []const u8) Lexer {
        return Lexer{
            .allocator = allocator,
            .source = source,
            .cursor = 0,
            .line = 1,
            .column = 0,
        };
    }

    pub fn getTokens(self: *Lexer) !ArrayList(TokenWithPosition)  {
        var tokens = ArrayList(TokenWithPosition).init(self.allocator);

        while (self.nextToken()) |current_token| {
            if (current_token.token == .EOF) {
                break;
            }

            try tokens.append(current_token);
        } else |err| switch (err) {
            error.UnexpectedCharacter => {
                tokens.deinit();
                std.log.err("Unexpected token {c} at column {d} line {d}", .{self.source[self.cursor-1], self.column, self.line});
                return err;
            }
        }

        return tokens;
    }

    fn isSpecialSymbolCharacter(ch: u8) bool {
        switch(ch) {
            '.', '*', '+', '!', '-', '_', '?', '$', '%', '&', '=', '>', '<' => return true,
            else => {
                return false;
            }
        }

        return false;
    }


    fn isValidSymbolCharacter(ch: u8) bool {
        return isSpecialSymbolCharacter(ch)
               or std.ascii.isAlphanumeric(ch)
               or ch == ':'
               or ch == '#'
               or ch == '/';
    }

    fn isSymbolBegins(self: Lexer, ch: u8) bool {
        // If -, + or . are the first character, the second character (if any) must be non-numeric.
        if ((ch == '-' or ch == '+' or ch == '.') ) {
            if (std.ascii.isAlphabetic(self.peek()) or self.peek() == '>') {
                return true;
            } else {
                return false;
            }
        }

        if (std.ascii.isAlphabetic(ch) or isSpecialSymbolCharacter(ch)) {
            return true;
        }

        return false;
    }

    fn isValidNamespacedSymbol(maybe_symbol: TokenWithPosition) bool {
        var slash_count: usize = 0;

        switch (maybe_symbol.token) {
            Token.Symbol => |value| {
                if (value[value.len-1] == '/') {
                    return false; // Cannot end with / (aka, suffix is missing)
                }
                for(value) |ch| {
                    if (ch == '/') {
                        slash_count += 1;
                    }
                }

                if (slash_count > 1) {
                    return false; //Cannot have more than 1 /
                }

                return true;
            },
            else => {
                return true;
            }
        }
    }

    pub fn nextToken(self: *Lexer) !TokenWithPosition {
        while (self.cursor < self.source.len) {
            const c = self.advance();
            switch (c) {
                ' ', ',', ';' => continue,
                '(' => return self.makeToken(.LeftParen),
                ')' => return self.makeToken(.RightParen),
                else => {
                    if (self.isSymbolBegins(c)) {
                        const maybe_symbol = self.lexSymbolOrBuiltIn();
                        if (isValidNamespacedSymbol(maybe_symbol)) {
                            return maybe_symbol;
                        }
                        return LexerError.UnexpectedCharacter;
                    } else {
                        return LexerError.UnexpectedCharacter;
                    }
                }
            }
        }
        return self.makeToken(.EOF);
    }

    fn peek(self: Lexer) u8 {
        return self.source[self.cursor];
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.cursor];
        self.cursor += 1;
        self.column += 1;
        return c;
    }

    fn makeToken(self: *Lexer, tokenType: Token) TokenWithPosition {
        return TokenWithPosition {
            .token = tokenType,
            .line = self.line,
            .column = self.column,
        };
    }


    fn lexSymbolOrBuiltIn(self: *Lexer) TokenWithPosition {
        const start = self.cursor - 1;

        while (self.cursor < self.source.len and isValidSymbolCharacter(self.source[self.cursor])) {
            _ = self.advance();
        }

        const text = self.source[start..self.cursor];

        var tokenType: Token = undefined;
        if (std.mem.eql(u8, text, "nil")) {
            tokenType = Token.Nil;
        }
        else if (std.mem.eql(u8, text, "true")) {
            tokenType = Token.True;
        }
        else if (std.mem.eql(u8, text, "false")) {
            tokenType = Token.False;
        } else {
            tokenType = Token{ .Symbol = text };
        }

        return TokenWithPosition{
            .token = tokenType,
            .line = self.line,
            .column = start+1,
        };
    }
};



test "init lexer" {
    const source = "(def a 1)";
    const lexer = Lexer.init(std.testing.allocator, source);
    try expectEqualStrings(lexer.source, source);
}

test "tokenize simple form" {
    const source = "(def s nil)";

    var lexer = Lexer.init(std.testing.allocator, source);
    var tokens = try lexer.getTokens();
    defer tokens.deinit();

    const expected_tokens = [_]TokenWithPosition {
        TokenWithPosition{ .token = .LeftParen, .column = 1, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "def"}, .column = 3, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "s"}, .column = 6, .line = 1 },
        TokenWithPosition{ .token = .Nil, .column = 8, .line = 1 },
        TokenWithPosition{ .token = .RightParen, .column = 11, .line = 1 },
        TokenWithPosition{ .token = .EOF, .column = 11, .line = 1 }
    };

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            Token.Symbol => |value|  try expectEqualStrings(expected_tokens[idx].token.Symbol, value),
            else  => {
                try std.testing.expectEqual(expected_tokens[idx], actual_token);
            }
        }
    }
}

test "tokenize basic valid symbols" {
    const basic_symbols = "foo my-symbol *special* +positive !important ends-with? ->fn $price %complete foo$bar% <symbol>";

    var lexer = Lexer.init(std.testing.allocator, basic_symbols);
    var tokens = try lexer.getTokens();
    defer tokens.deinit();

    const expected_tokens = [_]TokenWithPosition{
        TokenWithPosition{ .token = .{ .Symbol = "foo" }, .column = 1, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "my-symbol" }, .column = 5, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "*special*" }, .column = 15, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "+positive" }, .column = 25, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "!important" }, .column = 35, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "ends-with?" }, .column = 46, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "->fn" }, .column = 57, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "$price" }, .column = 62, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "%complete" }, .column = 69, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "foo$bar%" }, .column = 79, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "<symbol>" }, .column = 88, .line = 1 },
        TokenWithPosition{ .token = .EOF, .column = 95, .line = 1 },
    };

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            Token.Symbol => |value| {
                try expectEqualStrings(expected_tokens[idx].token.Symbol, value);
                try expect(expected_tokens[idx].column == actual_token.column);
            },
            else  => {
                try std.testing.expectEqual(expected_tokens[idx], actual_token);
            }
        }
    }
}

test "tokenize valid symbols with special chars" {
    const valid_symbols = "foo.bar,foo+bar,foo-bar,foo_baz,equals=to,greater<than>,hash#key";

    var lexer = Lexer.init(std.testing.allocator, valid_symbols);
    var tokens = try lexer.getTokens();
    defer tokens.deinit();

    const expected_tokens = [_]TokenWithPosition{
        TokenWithPosition{ .token = .{ .Symbol = "foo.bar" }, .column = 1, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "foo+bar" }, .column = 9, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "foo-bar" }, .column = 17, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "foo_baz" }, .column = 25, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "equals=to" }, .column = 33, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "greater<than>" }, .column = 43, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "hash#key" }, .column = 57, .line = 1 },
        TokenWithPosition{ .token = .EOF, .column = 65, .line = 1 },
    };

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            Token.Symbol => |value| {
                try expectEqualStrings(expected_tokens[idx].token.Symbol, value);
                try expect(expected_tokens[idx].column == actual_token.column);
            },
            else  => {
                try std.testing.expectEqual(expected_tokens[idx], actual_token);
            }
        }
    }
}

test "tokenize valid namespaced symbols" {
    const valid_symbols = "my-namespace/foo,core.logic/fact,user/!,valid/namespace-name,math/+";

    var lexer = Lexer.init(std.testing.allocator, valid_symbols);
    var tokens = try lexer.getTokens();
    defer tokens.deinit();

    const expected_tokens = [_]TokenWithPosition{
        TokenWithPosition{ .token = .{ .Symbol = "my-namespace/foo" }, .column = 1, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "core.logic/fact" }, .column = 18, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "user/!" }, .column = 34, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "valid/namespace-name" }, .column = 41, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "math/+" }, .column = 62, .line = 1 },
        TokenWithPosition{ .token = .EOF, .column = 67, .line = 1 },
    };

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            Token.Symbol => |value| {
                try expectEqualStrings(expected_tokens[idx].token.Symbol, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
            },
            else  => {
                try expectEqual(expected_tokens[idx], actual_token);
            }
        }
    }
}

test "tokenize invalid symbols" {
    const invalid_symbols = [_][]const u8{
        "123abc",
        "1name",
        "+1thing",
        "-3value",
        ".4symbol",
        "/foo",
        "foo/",
        "ns/foo/bar",
        "foo@bar",
        "foo~bar",
        ":keyword",
        "#something",
    };

    var errors_count: usize = 0;

    for (invalid_symbols) |invalid_symbol| {
        var lexer = Lexer.init(std.testing.allocator, invalid_symbol);

        var tokens = lexer.getTokens() catch |err| {
            try std.testing.expect(err == LexerError.UnexpectedCharacter);
            errors_count += 1;
            return;
        };

        tokens.deinit();
    }

    try expectEqual(invalid_symbols.len, errors_count);
}
