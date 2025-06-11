const std = @import("std");

pub const Type = union(enum) {
    int32,
    boolean,

    pub fn equals(self: Type, other: Type) bool {
        return std.meta.eql(self, other);
    }
};

const TokenType = enum {
    RETURN, // return

    NUMBER, // any num

    SEMICOLON, // ;

    PLUS, // +

    MINUS, // -

    MULTIPLY, // *

    DIVIDE, // /

    LET, // let

    IDENT, // a name (for function, var, etc)

    ASSIGN, // =

    FN, // fn

    LPAREN, // (

    RPAREN, // )

    LCURLY, // {

    RCURLY, // }

    COMMA, // ,

    COLON, // :

    ARROW, // ->

    I32, // i32

    BOOL, // bool

    TRUE, // true

    FALSE, // false

    ISEQUAL, // ==

    NOTEQUAL, // !=

    GREATER, // >

    LESS, // <

    EGREATER, // >=

    ELESS, // <=

    EOF, // end of file

    INVALID, // invalid token
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
    boolean: bool,
    fun_call: struct {
        fun_name: []const u8,
        fun_args: std.ArrayList(*Expr),
    },
};

pub const FnDef = struct {
    fun_name: []const u8,
    fun_params: std.ArrayList(Parameter),
    fun_type: Type,
    fun_body: std.ArrayList(Stmt),
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
    fun_def: FnDef,
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
        .fun_call => |data| {
            allocator.free(data.fun_name);

            for (data.fun_args.items) |arg| {
                freeExpr(arg, allocator);
            }

            data.fun_args.deinit();
        },
    }

    allocator.destroy(expr);
}

pub fn freeStmt(stmt: Stmt, allocator: std.mem.Allocator) void {
    switch (stmt) {
        ._return => |expr| freeExpr(expr, allocator),
        .bind => |data| {
            allocator.free(data.var_name);
            freeExpr(data.var_value, allocator);
        },
        .fun_def => |def| {
            allocator.free(def.fun_name);

            for (def.fun_params.items) |param| {
                allocator.free(param.name);
            }
            def.fun_params.deinit();

            for (def.fun_body.items) |stmt_b| {
                freeStmt(stmt_b, allocator);
            }
            def.fun_body.deinit();
        },
    }
}
