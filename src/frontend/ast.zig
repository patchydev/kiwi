const std = @import("std");

const TokenType = enum {
    RETURN,
    NUMBER,
    SEMICOLON,
    PLUS,
    MINUS,
    MULTIPLY,
    DIVIDE,
    LET,
    IDENT,
    ASSIGN,
    FN,
    LPAREN,
    RPAREN,
    LCURLY,
    RCURLY,
    COMMA,
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
    variable,
    fun_call,
};

pub const Expr = union(ExprType) {
    number: i32,
    op: struct {
        left: *Expr,
        op: TokenType,
        right: *Expr,
    },
    variable: struct {
        fun_name: []const u8,
        fun_args: std.ArrayList(*Expr),
    },
};

const StmtType = enum {
    bind,
    fun_def,
    _return,
};

pub const Stmt = union(StmtType) {
    bind: struct {
        var_name: []const u8,
        var_value: *Expr,
    },
    fun_def: struct {
        fun_name: []const u8,
        fun_args: std.ArrayList([]const u8),
        fun_body: std.ArrayList(Stmt),
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
        .variable => |name| {
            allocator.free(name);
        },
    }

    allocator.destroy(expr);
}

pub fn freeStmt(stmt: Stmt, allocator: std.mem.Allocator) void {
    switch (stmt) {
        ._return => |expr| freeExpr(expr, allocator),
        .bind => |data| freeExpr(data.var_value, allocator),
    }
}
