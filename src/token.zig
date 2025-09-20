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
    Float: f64,
    Comment: []const u8,
    Character: []const u8,

    // Built-ins
    Nil,
    True,
    False,
    Quote,
    Pound,
    At,
    Minus,
    Plus,
    Slash,
    Carret,
    Dot,
    Backquote,
    Tilde,
    Discard,

    EOF,
};

pub const TokenWithPosition = struct {
    token: Token,
    line: usize,
    column: usize,
};
