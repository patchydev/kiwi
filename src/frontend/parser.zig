const std = @import("std");
const ast = @import("ast.zig");
const lexer = @import("lexer.zig");

pub const Parser = struct {
    lexer: *lexer.Lexer,
    current_token: ast.Token,

    pub fn init(lex: *lexer.Lexer) Parser {
        var parser = Parser{
            .lexer = lex,
            .current_token = undefined,
        };
        parser.current_token = lex.nextToken();
        return parser;
    }

    pub fn parsePrimary(self: *Parser, allocator: std.mem.Allocator) !*ast.Expr {
        if (self.current_token.type != .NUMBER and self.current_token.type != .IDENT) {
            return error.ExpectedNumber;
        }
        if (self.current_token.type == .NUMBER) {
            const value = try std.fmt.parseInt(i32, self.current_token.value, 10);
            self.advance();

            const node = try allocator.create(ast.Expr);
            node.* = ast.Expr{ .number = value };
            return node;
        } else if (self.current_token.type == .IDENT) {
            self.advance();

            const node = try allocator.create(ast.Expr);
            node.* = ast.Expr{ .variable = self.current_token.value };
            return node;
        } else {
            unreachable; // error handling? i hardly know her
        }
    }

    pub fn parseExpression(self: *Parser, allocator: std.mem.Allocator) !*ast.Expr {
        var left = try self.parseTerm(allocator);

        while (self.current_token.type == .PLUS or self.current_token.type == .MINUS) {
            const op_type = self.current_token.type;
            self.advance();
            const right = try self.parseTerm(allocator);

            const op_node = try allocator.create(ast.Expr);
            op_node.* = ast.Expr{ .op = .{
                .left = left,
                .op = op_type,
                .right = right,
            } };
            left = op_node;
        }

        return left;
    }

    pub fn parseTerm(self: *Parser, allocator: std.mem.Allocator) !*ast.Expr {
        var left = try self.parsePrimary(allocator);

        while (self.current_token.type == .MULTIPLY or self.current_token.type == .DIVIDE) {
            const op_type = self.current_token.type;
            self.advance();
            const right = try self.parsePrimary(allocator);

            const op_node = try allocator.create(ast.Expr);
            op_node.* = ast.Expr{ .op = .{
                .left = left,
                .op = op_type,
                .right = right,
            } };
            left = op_node;
        }

        return left;
    }

    pub fn parseLetStatement(self: *Parser, allocator: std.mem.Allocator) !ast.Stmt {
        if (self.current_token.type != .LET) {
            return error.ExpectedLet;
        }
        self.advance();

        if (self.current_token.type != .IDENT) {
            return error.ExpectedIdentifier;
        }
        const name = self.current_token.value;
        self.advance();

        if (self.current_token.type != .ASSIGN) {
            return error.ExpectedAssignmentOperator;
        }
        self.advance();

        const value = try self.parseExpression(allocator);

        if (self.current_token.type != .SEMICOLON) {
            return error.ExpectedSemicolon;
        }
        self.advance();

        return ast.Stmt{ .bind = .{
            .var_name = name,
            .var_value = value,
        } };
    }

    pub fn parseReturnStatement(self: *Parser, allocator: std.mem.Allocator) !ast.Stmt {
        if (self.current_token.type != .RETURN) {
            return error.ExpectedReturn;
        }
        self.advance();

        const value = try self.parseExpression(allocator);

        if (self.current_token.type != .SEMICOLON) {
            return error.ExpectedSemicolon;
        }
        self.advance();

        //return value;

        return ast.Stmt{
            ._return = value,
        };

        //const stmt = try allocator.create(ast.Stmt);
        //stmt.* = ast.Stmt{ // pointer fuckery
        //    ._return = value,
        //};
        //return stmt;
    }

    pub fn parseProgram(self: *Parser, allocator: std.mem.Allocator) !std.ArrayList(ast.Stmt) {
        var list = std.ArrayList(ast.Stmt).init(allocator);
        //defer list.deinit();

        while (self.current_token.type != .EOF) {
            if (self.current_token.type == .RETURN) {
                try list.append(try self.parseReturnStatement(allocator));
            } else if (self.current_token.type == .LET) {
                try list.append(try self.parseLetStatement(allocator));
            } else {
                unreachable; // lol
            }
        }

        return list;
    }

    fn advance(self: *Parser) void {
        self.current_token = self.lexer.nextToken();
    }
};
