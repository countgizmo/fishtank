const token = @import("token.zig");
const Token = token.Token;

const Position = struct {
    line: usize,
    column: usize
};


const Kind = enum {
    Token,
    List
};

const ASTNode = struct {
    kind: Kind,
    token: ?Token,
    children: ?[]ASTNode,
    position: ?Position,
};
