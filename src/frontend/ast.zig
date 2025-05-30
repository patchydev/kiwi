const std = @import("std");

const TokenType = enum {
    RETURN,
    NUMBER,
    SEMICOLON,
    PLUS,
    MINUS,
    MULTIPLY,
    EOF,
    INVALID,
};

pub const Token = struct {
    type: TokenType,
    value: []const u8,
};

const ExprType = enum {
    number,
    op,
};

pub const Expr = union(ExprType) {
    number: i32,
    op: struct {
        left: *Expr,
        op: TokenType,
        right: *Expr,
    },
};

pub fn freeExpr(expr: *Expr, allocator: std.mem.Allocator) void {
    switch (expr.*) {
        .number => {},
        .op => |op_data| {
            freeExpr(op_data.left, allocator);
            freeExpr(op_data.right, allocator);
        },
    }

    allocator.destroy(expr);
}
