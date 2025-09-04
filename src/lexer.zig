const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const testing = std.testing;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const token = @import("token.zig");
const Token = token.Token;
const TokenWithPosition  = token.TokenWithPosition;

const LexerError = error {
    UnexpectedCharacter,
    UnexpectedFirstCharacter,
    UnexpectedNumberCharacter,
    UnexpectedEndOfString,
};

pub const Lexer = struct {
    allocator: Allocator,
    source: []const u8,
    cursor: usize = 0,
    line: usize = 1,
    column: usize = 0,
    quiet: bool = false,

    pub fn init(allocator: Allocator, source: []const u8) Lexer {
        return .{
            .allocator = allocator,
            .source = source,
        };
    }

    pub fn initQuiet(allocator: Allocator, source: []const u8) Lexer {
        return .{
            .allocator = allocator,
            .source = source,
            .quiet = true,
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
                if (!self.quiet) {
                    std.log.err("Unexpected character '{c}' at column {d} line {d}", .{self.source[self.cursor-1], self.column, self.line});
                }
                return err;
            },
            else => {
                tokens.deinit();
                if (!self.quiet) {
                    std.log.err("Unhandle error parsing token '{c}' at column {d} line {d}", .{self.source[self.cursor-1], self.column, self.line});
                }
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
            if (std.ascii.isAlphabetic(self.peek()) or self.peek() == '>' or self.peek() == ' ') {
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

    fn isKeywordBegins(ch: u8) bool {
        return ch == ':';
    }

    fn isDelimiter(ch: u8) bool {
        switch (ch) {
            ' ', ',', ';', '\n', '\r', '\t' => {return true;},
            else => {return false;},
        }
    }

    pub fn nextToken(self: *Lexer) !TokenWithPosition {
        while (self.cursor < self.source.len) {
            const c = self.advance();

            if (isDelimiter(c)) {
                if (c == '\n') {
                    self.line += 1;
                    self.column = 0;
                }
                continue;
            }

            switch (c) {
                '(' => return self.makeToken(.LeftParen),
                ')' => return self.makeToken(.RightParen),
                '[' => return self.makeToken(.LeftBracket),
                ']' => return self.makeToken(.RightBracket),
                '{' => return self.makeToken(.LeftBrace),
                '}' => return self.makeToken(.RightBrace),
                '\'' => return self.makeToken(.Quote),
                '#' => return self.makeToken(.Pound),
                '@' => return self.makeToken(.At),
                else => {
                    if (self.isSymbolBegins(c)) {
                        const maybe_symbol = self.lexSymbolOrBuiltIn();
                        if (isValidNamespacedSymbol(maybe_symbol)) {
                            return maybe_symbol;
                        }
                        return LexerError.UnexpectedFirstCharacter;
                    } else if (isKeywordBegins(c)) {
                        const maybe_keyword = self.lexKeyword();
                        return maybe_keyword;
                    } else if (std.ascii.isDigit(c)) {
                        const mayber_number = self.lexNumber();
                        return mayber_number;
                    } else if (c == '"') {
                        const maybe_string = self.lexString();
                        return maybe_string;
                    }else {
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
        const start_cursor = self.cursor - 1;
        const start_column = self.column;

        while (self.cursor < self.source.len and isValidSymbolCharacter(self.source[self.cursor])) {
            _ = self.advance();
        }

        const text = self.source[start_cursor..self.cursor];

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
            .column = start_column,
        };
    }

    fn lexKeyword(self: *Lexer) TokenWithPosition {
        const start = self.cursor - 1;
        const start_column = self.column;

        while (self.cursor < self.source.len and isValidSymbolCharacter(self.source[self.cursor])) {
            _ = self.advance();
        }

        const text = self.source[start..self.cursor];

        return TokenWithPosition{
            .token = Token{ .Keyword = text },
            .line = self.line,
            .column = start_column,
        };
    }

    // TODO(evheni): parse floats.
    fn lexNumber(self: *Lexer) !TokenWithPosition {
        const start = self.cursor - 1;
        const start_column = self.column;

        while (self.cursor < self.source.len and std.ascii.isDigit(self.source[self.cursor])) {
            _ = self.advance();
        }

        const next = self.peek();
        if (!isDelimiter(next) and
            next != '}' and
            next != ']' and
            next != ')') {
            return LexerError.UnexpectedNumberCharacter;
        }

        const text = self.source[start..self.cursor];
        const int = try std.fmt.parseInt(i64, text, 10);
        return TokenWithPosition {
            .token = Token{ .Int = int },
            .line = self.line,
            .column = start_column,
        };
    }

    fn isValidEscape(ch: u8) bool {
        switch(ch) {
            't', 'r', 'n', '\\', '"' => return true,
            else => {
                return false;
            }
        }
    }


    fn isValidStringCharacter(ch: u8) bool {
        return isValidSymbolCharacter(ch) or isDelimiter(ch);
    }

    fn isEscapeSequence(self: Lexer, ch: u8) bool {
       if (self.cursor < self.source.len) {
           return ch == '\\' and isValidEscape(self.source[self.cursor]);
       }
       return false;
    }

    fn lexString(self: *Lexer) !TokenWithPosition {
        // No -1 cause we exclude openning quote from the value
        const start = self.cursor;
        const start_column = self.column;

        while (self.cursor < self.source.len-1 and
               (isValidStringCharacter(self.peek()) or self.isEscapeSequence(self.peek()))) {
            _ = self.advance();
        }

        // String must end with "
        if (self.peek() != '"') {
            return LexerError.UnexpectedEndOfString;
        }

        // We don't include the quotes (beginning or ending) in the text.
        const text = self.source[start..self.cursor];

        // Skipping the end quote
        _ = self.advance();

        return TokenWithPosition{
            .token = Token{ .String = text },
            .line = self.line,
            .column = start_column,
        };
    }
};

test "init lexer" {
    const source = "(def a 1)";
    const lexer = Lexer.init(std.testing.allocator, source);
    try expectEqualStrings(lexer.source, source);
}

test "tokenize simple form" {
    const source = "(def s [nil])";

    var lexer = Lexer.init(std.testing.allocator, source);
    var tokens = try lexer.getTokens();
    defer tokens.deinit();

    const expected_tokens = [_]TokenWithPosition {
        TokenWithPosition{ .token = .LeftParen, .column = 1, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "def"}, .column = 3, .line = 1 },
        TokenWithPosition{ .token = .{ .Symbol = "s"}, .column = 6, .line = 1 },
        TokenWithPosition{ .token = .LeftBracket, .column = 8, .line = 1 },
        TokenWithPosition{ .token = .Nil, .column = 9, .line = 1 },
        TokenWithPosition{ .token = .RightBracket, .column = 12, .line = 1 },
        TokenWithPosition{ .token = .RightParen, .column = 13, .line = 1 },
        TokenWithPosition{ .token = .EOF, .column = 14, .line = 1 }
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

const InvalidSymbolWithReason = struct {
    symbol: []const u8,
    expected_error: LexerError,
};


test "tokenize invalid symbols" {
    const invalid_symbols = [_]InvalidSymbolWithReason{
        .{ .symbol = "123abc", .expected_error = LexerError.UnexpectedNumberCharacter },
        .{ .symbol = "1name", .expected_error = LexerError.UnexpectedNumberCharacter },
        .{ .symbol = "+1thing", .expected_error = LexerError.UnexpectedCharacter},
        .{ .symbol = "-3value", .expected_error = LexerError.UnexpectedCharacter},
        .{ .symbol = ".4symbol", .expected_error = LexerError.UnexpectedCharacter},
        .{ .symbol = "/foo", .expected_error = LexerError.UnexpectedCharacter},
        .{ .symbol = "foo/", .expected_error = LexerError.UnexpectedFirstCharacter},
        .{ .symbol = "ns/foo/bar", .expected_error = LexerError.UnexpectedFirstCharacter},
        .{ .symbol = "foo@bar", .expected_error = LexerError.UnexpectedCharacter},
        .{ .symbol = "foo~bar", .expected_error = LexerError.UnexpectedCharacter},
    };

    for (invalid_symbols) |invalid_symbol| {
        var lexer = Lexer.initQuiet(std.testing.allocator, invalid_symbol.symbol);
        try std.testing.expectError(
            invalid_symbol.expected_error,
            lexer.getTokens()
        );
    }
}

test "lexer - basic keywords" {
    const source = ":foo :bar";
    var l = Lexer.init(testing.allocator, source);

    const expected_tokens = [_]TokenWithPosition{
        .{ .token = .{ .Keyword = ":foo" }, .column = 1, .line = 1 },
        .{ .token = .{ .Keyword = ":bar" }, .column = 6, .line = 1 },
        .{ .token = .EOF, .column = 9, .line = 1 },
    };

    const tokens = try l.getTokens();
    defer tokens.deinit();

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            .Keyword => |value| {
                try expectEqualStrings(expected_tokens[idx].token.Keyword, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
            },
            else => try expectEqual(expected_tokens[idx], actual_token),
        }
    }
}

test "lexer - namespaced keywords" {
    const source = ":my/foo :other.ns/bar";
    var l = Lexer.init(testing.allocator, source);

    const expected_tokens = [_]TokenWithPosition{
        .{ .token = .{ .Keyword = ":my/foo" }, .column = 1, .line = 1 },
        .{ .token = .{ .Keyword = ":other.ns/bar" }, .column = 9, .line = 1 },
        .{ .token = .EOF, .column = 21, .line = 1 },
    };

    const tokens = try l.getTokens();
    defer tokens.deinit();

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            .Keyword => |value| {
                try expectEqualStrings(expected_tokens[idx].token.Keyword, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
            },
            else => try expectEqual(expected_tokens[idx], actual_token),
        }
    }
}

test "lexer - empty map" {
    const source = "{}";
    var l = Lexer.init(testing.allocator, source);

    const expected_tokens = [_]TokenWithPosition{
        .{ .token = .LeftBrace, .column = 1, .line = 1 },
        .{ .token = .RightBrace, .column = 2, .line = 1 },
        .{ .token = .EOF, .column = 3, .line = 1 },
    };

    const tokens = try l.getTokens();
    defer tokens.deinit();

    for (tokens.items, 0..) |actual_token, idx| {
        try expectEqual(expected_tokens[idx], actual_token);
    }
}

test "lexer - simple map" {
    const source = "{:a 1, :b 2}";
    var l = Lexer.init(testing.allocator, source);

    const expected_tokens = [_]TokenWithPosition{
        .{ .token = .LeftBrace, .column = 1, .line = 1 },
        .{ .token = .{ .Keyword = ":a" }, .column = 2, .line = 1 },
        .{ .token = .{ .Int = 1 }, .column = 5, .line = 1 },
        .{ .token = .{ .Keyword = ":b" }, .column = 8, .line = 1 },
        .{ .token = .{ .Int = 2 }, .column = 11, .line = 1 },
        .{ .token = .RightBrace, .column = 12, .line = 1 },
        .{ .token = .EOF, .column = 13, .line = 1 },
    };

    const tokens = try l.getTokens();
    defer tokens.deinit();

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            .Keyword => |value| {
                try expectEqualStrings(expected_tokens[idx].token.Keyword, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
            },
            .Int => |value| {
                try expectEqual(expected_tokens[idx].token.Int, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
            },
            else => try expectEqual(expected_tokens[idx], actual_token),
        }
    }
}

test "lexer - nested map" {
    const source = "{:a {:nested 42}, :b [1 2]}";
    var l = Lexer.init(testing.allocator, source);

    const expected_tokens = [_]TokenWithPosition{
        .{ .token = .LeftBrace, .column = 1, .line = 1 },
        .{ .token = .{ .Keyword = ":a" }, .column = 2, .line = 1 },
        .{ .token = .LeftBrace, .column = 5, .line = 1 },
        .{ .token = .{ .Keyword = ":nested" }, .column = 6, .line = 1 },
        .{ .token = .{ .Int = 42 }, .column = 14, .line = 1 },
        .{ .token = .RightBrace, .column = 16, .line = 1 },
        .{ .token = .{ .Keyword = ":b" }, .column = 19, .line = 1 },
        .{ .token = .LeftBracket, .column = 22, .line = 1 },
        .{ .token = .{ .Int = 1 }, .column = 23, .line = 1 },
        .{ .token = .{ .Int = 2 }, .column = 25, .line = 1 },
        .{ .token = .RightBracket, .column = 26, .line = 1 },
        .{ .token = .RightBrace, .column = 27, .line = 1 },
        .{ .token = .EOF, .column = 28, .line = 1 },
    };

    const tokens = try l.getTokens();
    defer tokens.deinit();

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            .Keyword => |value| {
                try expectEqualStrings(expected_tokens[idx].token.Keyword, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
            },
            .Int => |value| {
                try expectEqual(expected_tokens[idx].token.Int, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
            },
            else => try expectEqual(expected_tokens[idx], actual_token),
        }
    }
}

test "lexer - map with namespaced keys" {
    const source = "{:my/key 1, :other.ns/value 2}";
    var l = Lexer.init(testing.allocator, source);

    const expected_tokens = [_]TokenWithPosition{
        .{ .token = .LeftBrace, .column = 1, .line = 1 },
        .{ .token = .{ .Keyword = ":my/key" }, .column = 2, .line = 1 },
        .{ .token = .{ .Int = 1 }, .column = 10, .line = 1 },
        .{ .token = .{ .Keyword = ":other.ns/value" }, .column = 13, .line = 1 },
        .{ .token = .{ .Int = 2 }, .column = 29, .line = 1 },
        .{ .token = .RightBrace, .column = 30, .line = 1 },
        .{ .token = .EOF, .column = 31, .line = 1 },
    };

    const tokens = try l.getTokens();
    defer tokens.deinit();

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            .Keyword => |value| {
                try expectEqualStrings(expected_tokens[idx].token.Keyword, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
            },
            .Int => |value| {
                try expectEqual(expected_tokens[idx].token.Int, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
            },
            else => try expectEqual(expected_tokens[idx], actual_token),
        }
    }
}

test "lexer - map with symbol keys" {
    const source = "{test 1, other/symbol 2}";
    var l = Lexer.init(testing.allocator, source);

    const expected_tokens = [_]TokenWithPosition{
        .{ .token = .LeftBrace, .column = 1, .line = 1 },
        .{ .token = .{ .Symbol = "test" }, .column = 2, .line = 1 },
        .{ .token = .{ .Int = 1 }, .column = 7, .line = 1 },
        .{ .token = .{ .Symbol = "other/symbol" }, .column = 10, .line = 1 },
        .{ .token = .{ .Int = 2 }, .column = 23, .line = 1 },
        .{ .token = .RightBrace, .column = 24, .line = 1 },
        .{ .token = .EOF, .column = 25, .line = 1 },
    };

    const tokens = try l.getTokens();
    defer tokens.deinit();

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            .Symbol => |value| {
                try expectEqualStrings(expected_tokens[idx].token.Symbol, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
            },
            .Int => |value| {
                try expectEqual(expected_tokens[idx].token.Int, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
            },
            else => try expectEqual(expected_tokens[idx], actual_token),
        }
    }
}

// test "lexer - simple string" {
//     const source = "\"maybe I am a potato\"";
//     var l = Lexer.init(testing.allocator, source);
//
//     const expected_tokens = [_]TokenWithPosition{
//         .{ .token = .{ .String = "maybe I am a potato" }, .column = 1, .line = 1},
//         .{ .token = .EOF, .column = 22, .line = 1 },
//     };
//
//     const tokens = try l.getTokens();
//     defer tokens.deinit();
//
//     for (tokens.items, 0..) |actual_token, idx| {
//         switch (actual_token.token) {
//             .String => |value| {
//                 try expectEqualStrings(expected_tokens[idx].token.String, value);
//                 try expectEqual(expected_tokens[idx].column, actual_token.column);
//                 try expectEqual(expected_tokens[idx].line, actual_token.line);
//             },
//             else => try expectEqual(expected_tokens[idx], actual_token),
//         }
//     }
// }
//
// test "lexer - empty string" {
//     const source = "\"\"";
//     var l = Lexer.init(testing.allocator, source);
//
//     const expected_tokens = [_]TokenWithPosition{
//         .{ .token = .{ .String = "" }, .column = 1, .line = 1},
//         .{ .token = .EOF, .column = 3, .line = 1 },
//     };
//
//     const tokens = try l.getTokens();
//     defer tokens.deinit();
//
//     for (tokens.items, 0..) |actual_token, idx| {
//         switch (actual_token.token) {
//             .String => |value| {
//                 try expectEqualStrings(expected_tokens[idx].token.String, value);
//                 try expectEqual(expected_tokens[idx].column, actual_token.column);
//                 try expectEqual(expected_tokens[idx].line, actual_token.line);
//             },
//             else => try expectEqual(expected_tokens[idx], actual_token),
//         }
//     }
// }

test "lexer - string with escape sequences" {
    const source = "\"hello\nworld\t\\slashed\"";
    var l = Lexer.init(testing.allocator, source);

    const expected_tokens = [_]TokenWithPosition{
        .{ .token = .{ .String = "hello\nworld\t\\slashed" }, .column = 1, .line = 1},
        .{ .token = .EOF, .column = 26, .line = 1 },
    };

    const tokens = try l.getTokens();
    defer tokens.deinit();

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            .String => |value| {
                try expectEqualStrings(expected_tokens[idx].token.String, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
                try expectEqual(expected_tokens[idx].line, actual_token.line);
            },
            else => try expectEqual(expected_tokens[idx], actual_token),
        }
    }
}

test "lexer - unterminated string" {
    const source = "\"unterminated";
    var l = Lexer.initQuiet(testing.allocator, source);

    try testing.expectError(LexerError.UnexpectedEndOfString, l.getTokens());
}

test "lexer - def with string" {
    const source = "(def version \"2\")";
    var l = Lexer.init(testing.allocator, source);

    const expected_tokens = [_]TokenWithPosition{
        .{ .token = .LeftParen, .column = 1, .line = 1 },
        .{ .token = .{ .Symbol = "def"}, .column = 2, .line = 1 },
        .{ .token = .{ .Symbol = "version"}, .column = 6, .line = 1 },
        .{ .token = .{ .String = "2" }, .column = 14, .line = 1},
        .{ .token = .RightParen, .column = 17, .line = 1 },
        .{ .token = .EOF, .column = 18, .line = 1 },
    };

    const tokens = try l.getTokens();
    defer tokens.deinit();

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            .Symbol => |value| {
                try expectEqualStrings(expected_tokens[idx].token.Symbol, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
                try expectEqual(expected_tokens[idx].line, actual_token.line);
            },
            .String => |value| {
                try expectEqualStrings(expected_tokens[idx].token.String, value);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
                try expectEqual(expected_tokens[idx].line, actual_token.line);
            },
            else => try expectEqual(expected_tokens[idx], actual_token),
        }
    }
}

test "lexer - line and column counting with different newlines" {
    const source = "foo\nbar\r\nbaz\rqux";

    var lexer = Lexer.init(testing.allocator, source);
    var tokens = try lexer.getTokens();
    defer tokens.deinit();

    const expected_tokens = [_]TokenWithPosition{
        .{ .token = .{ .Symbol = "foo" }, .line = 1, .column = 1 },
        .{ .token = .{ .Symbol = "bar" }, .line = 2, .column = 1 },
        .{ .token = .{ .Symbol = "baz" }, .line = 3, .column = 1 },
        .{ .token = .{ .Symbol = "qux" }, .line = 3, .column = 5 }, // \r doesn't increment line
        .{ .token = .EOF, .line = 3, .column = 8 },
    };

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            .Symbol => |value| {
                try expectEqualStrings(expected_tokens[idx].token.Symbol, value);
                try expectEqual(expected_tokens[idx].line, actual_token.line);
                try expectEqual(expected_tokens[idx].column, actual_token.column);
            },
            else => try expectEqual(expected_tokens[idx], actual_token),
        }
    }
}
