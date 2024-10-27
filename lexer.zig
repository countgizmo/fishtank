const std = @import("std");
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;
const token = @import("token.zig");
const Token = token.Token;
const TokenWithPosition  = token.TokenWithPosition;

const LexerError = error {
    UnexpectedCharacter,
};

const Lexer = struct {
    source: []const u8,
    cursor: usize,
    line: usize,
    column: usize,

    pub fn init(source: []const u8) Lexer {
        return Lexer{
            .source = source,
            .cursor = 0,
            .line = 1,
            .column = 0,
        };
    }

    pub fn nextToken(self: *Lexer) !TokenWithPosition {
        while (self.cursor < self.source.len) {
            const c = self.advance();
            switch (c) {
                ' ' => continue,
                '(' => return self.makeToken(.LeftParen),
                ')' => return self.makeToken(.RightParen),
                else => {
                    if (std.ascii.isAlphabetic(c)) {
                        return self.lexIdentifierOrBuiltIn();
                    } else {
                        return LexerError.UnexpectedCharacter;
                    }
                }
            }
        }
        return self.makeToken(.EOF);
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

    fn lexIdentifierOrBuiltIn(self: *Lexer) TokenWithPosition {
        const start = self.cursor - 1;

        while (self.cursor < self.source.len and std.ascii.isAlphabetic(self.source[self.cursor])) {
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
            tokenType = Token{ .Identifier = text };
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
    const lexer = Lexer.init(source);
    try expectEqualStrings(lexer.source, source);
}

test "tokenize simple form" {
    var tokens = std.ArrayList(TokenWithPosition).init(std.testing.allocator);
    defer tokens.deinit();

    const source = "(def s nil)";
    var lexer = Lexer.init(source);
    while (true) {
        const cur_token = try lexer.nextToken();
        try tokens.append(cur_token);

        if (cur_token.token == .EOF) {
            break;
        }
    }

    const expected_tokens = [_]TokenWithPosition {
        TokenWithPosition{ .token = .LeftParen, .column = 1, .line = 1 },
        TokenWithPosition{ .token = .{ .Identifier = "def"}, .column = 3, .line = 1 },
        TokenWithPosition{ .token = .{ .Identifier = "s"}, .column = 6, .line = 1 },
        TokenWithPosition{ .token = .Nil, .column = 8, .line = 1 },
        TokenWithPosition{ .token = .RightParen, .column = 11, .line = 1 },
        TokenWithPosition{ .token = .EOF, .column = 11, .line = 1 }
    };

    for (tokens.items, 0..) |actual_token, idx| {
        switch (actual_token.token) {
            Token.Identifier => |value|  try expectEqualStrings(expected_tokens[idx].token.Identifier, value),
            else  => {
                try std.testing.expectEqual(expected_tokens[idx], actual_token);
            }
        }
    }
}
