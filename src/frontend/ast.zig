const std = @import("std");

const TokenType = enum {
    RETURN,
    NUMBER,
    SEMICOLON,
    PLUS,
    MINUS,
    MULTIPLY,
    DIVIDE,
    ASSIGN,
    EQUALS,
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

const StmtType = enum {
    bind,
    _return,
};

pub const Stmt = union(StmtType) {
    bind: struct {
        var_name: []const u8,
        var_value: *Expr,
    },
    _return: *Expr,
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
