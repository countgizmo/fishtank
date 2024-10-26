pub const Token = union(enum) {
    LeftParen,
    RightParen,

    // Literals
    Identifier: []const u8,
    Int: i64,

    EOF,
};

pub const TokenWithPosition = struct {
    token: Token,
    line: usize = 1,
    column: usize = 1,
};
