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
    Int: i64,

    // Built-ins
    Nil,
    True,
    False,

    EOF,
};

pub const TokenWithPosition = struct {
    token: Token,
    line: usize,
    column: usize,
};
