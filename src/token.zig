pub const Token = union(enum) {
    // Delimiters
    LeftParen,
    RightParen,
    LeftBracket,
    RightBracket,
    LeftBrace,
    RightBrace,

    // Literals
    Symbol: []const u8,
    Keyword: []const u8,
    String: []const u8,
    Int: i64,

    // Built-ins
    Nil,
    True,
    False,
    Quote,
    Pound,

    EOF,
};

pub const TokenWithPosition = struct {
    token: Token,
    line: usize,
    column: usize,
};
