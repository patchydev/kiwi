const std = @import("std");

pub const Type = union(enum) {
    int32,

    pub fn equals(self: Type, other: Type) bool {
        return std.meta.eql(self, other);
    }
};

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
    COLON,
    ARROW,
    I32,
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
    variable: []const u8,
    fun_call: struct {
        fun_name: []const u8,
        fun_args: std.ArrayList(Parameter),
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
        var_type: Type,
        var_value: *Expr,
    },
    fun_def: struct {
        fun_name: []const u8,
        fun_params: std.ArrayList(Parameter),
        fun_type: Type,
        fun_body: std.ArrayList(Stmt),
    },
    _return: *Expr,
};

pub const Parameter = struct {
    name: []const u8,
    type: Type,
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
        else => std.debug.print("free function call", .{}),
        // need to add things here for function call
    }

    allocator.destroy(expr);
}

pub fn freeStmt(stmt: Stmt, allocator: std.mem.Allocator) void {
    switch (stmt) {
        ._return => |expr| freeExpr(expr, allocator),
        .bind => |data| freeExpr(data.var_value, allocator),
        else => std.debug.print("free function def", .{}),
        // need to add smth here for function definition
    }
}
