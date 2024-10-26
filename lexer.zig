const std = @import("std");
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;
const token = @import("token.zig");
const Token = token.Token;
const TokenWithPosition  = token.TokenWithPosition;

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
                '(' => return self.makeToken(.LeftParen),
                ')' => return self.makeToken(.RightParen),
                else => return error.UnexpectedCharacter,
            }
        }
        return self.makeToken(.EOF);
    }


    pub fn advance(self: *Lexer) u8 {
        const c = self.source[self.cursor];
        self.cursor += 1;
        self.column += 1;
        return c;
    }

    pub fn makeToken(self: *Lexer, tokenType: Token) TokenWithPosition {
        return TokenWithPosition {
            .token = tokenType,
            .line = self.line,
            .column = self.column,
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

    const source = "()";
    var lexer = Lexer.init(source);
    while (true) {
        const cur_token = try lexer.nextToken();
        try tokens.append(cur_token);

        if (cur_token.token == .EOF) {
            break;
        }
    }

    const expected_tokens = [_]TokenWithPosition {
        TokenWithPosition{ .token = .LeftParen, .column = 1 },
        TokenWithPosition{ .token = .RightParen, .column = 2 },
        TokenWithPosition{ .token = .EOF, .column = 2 }
    };

    for (tokens.items, 0..) |actual_token, idx| {
        try std.testing.expectEqual(expected_tokens[idx], actual_token);
    }
}
