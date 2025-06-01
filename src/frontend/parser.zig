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
        if (self.current_token.type != .NUMBER) {
            return error.ExpectedNumber;
        }

        const value = try std.fmt.parseInt(i32, self.current_token.value, 10);
        self.advance();

        const node = try allocator.create(ast.Expr);
        node.* = ast.Expr{ .number = value };
        return node;
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
            }
        }

        return list;
    }

    fn advance(self: *Parser) void {
        self.current_token = self.lexer.nextToken();
    }
};
