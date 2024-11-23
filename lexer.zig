const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;
const token = @import("token.zig");
const Token = token.Token;
const TokenWithPosition  = token.TokenWithPosition;

const LexerError = error {
    UnexpectedCharacter,
};

const Lexer = struct {
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

        while (true) {
            if (self.nextToken()) |current_token| {
                try tokens.append(current_token);

                if (current_token.token == .EOF) {
                    break;
                }
            } else |err| switch (err) {
                error.UnexpectedCharacter => {
                    std.log.err("Unexpected token {}", .{token});
                }
            }
        }

        return tokens;
    }

    fn isValidSymbolCharacter(ch: u8) bool {
        switch(ch) {
            '.', '*', '+', '!', '-', '_', '?', '$', '%', '&', '=', '>', '<' => return true,
            ':', '#' => return true,
            '/' => return true,
            else => {
                return std.ascii.isAlphanumeric(ch);
            }
        }


        return false;
    }


    fn isSymbolBegins(self: Lexer, ch: u8) bool {
        if (std.ascii.isAlphabetic(ch) or isValidSymbolCharacter(ch)) {
            return true;
        }

        // If -, + or . are the first character, the second character (if any) must be non-numeric.
        if ((ch == '-' or ch == '+' or ch == '.') and
            std.ascii.isAlphabetic(self.peek())) {
            return true;
        }

        return false;
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
                        return self.lexSymbolOrBuiltIn();
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

test "tokenize valid symbols" {
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
