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
        var left = try self.parsePrimary(allocator);

        while (self.current_token.type == .PLUS or self.current_token.type == .MINUS) {
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

    pub fn parseReturnStatement(self: *Parser, allocator: std.mem.Allocator) !*ast.Expr {
        if (self.current_token.type != .RETURN) {
            return error.ExpectedReturn;
        }
        self.advance();

        const value = try self.parseExpression(allocator);

        if (self.current_token.type != .SEMICOLON) {
            return error.ExpectedSemicolon;
        }
        self.advance();

        return value;
    }

    fn advance(self: *Parser) void {
        self.current_token = self.lexer.nextToken();
    }
};
