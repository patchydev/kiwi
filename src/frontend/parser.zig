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
            const var_name = try allocator.dupe(u8, self.current_token.value); // have to do this because of funky shit happening
            std.debug.print("value of ident: '{s}'\n", .{self.current_token.value});
            self.advance();

            if (self.current_token.type == .LPAREN) {
                return try self.parseFunctionCall(allocator, var_name);
            } else {
                const node = try allocator.create(ast.Expr);
                node.* = ast.Expr{ .variable = var_name };
                std.debug.print("created node '{s}'\n", .{node.variable});
                return node;
            }
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

        if (self.current_token.type != .COLON) {
            return error.ExpectedColon;
        }
        self.advance();

        const var_type = try self.parseType();
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
            .var_type = var_type,
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
            } else if (self.current_token.type == .FN) {
                try list.append(try self.parseFunctionDef(allocator));
            } else {
                unreachable; // lol
            }
        }

        return list;
    }

    pub fn parseType(self: *Parser) !ast.Type {
        if (self.current_token.type == .I32) {
            return ast.Type.int32;
        } else {
            unreachable;
        }
    }

    pub fn parseParameter(self: *Parser, allocator: std.mem.Allocator) !ast.Parameter {
        if (self.current_token.type != .IDENT) {
            return error.ExpectedIdentifier;
        }

        const name = try allocator.dupe(u8, self.current_token.value);
        self.advance();

        if (self.current_token.type != .COLON) {
            return error.ExpectedColon;
        }
        self.advance();

        const param_type = try self.parseType();
        //self.advance();
        // i think we should consume the comma in parseFunctionDef instead

        return ast.Parameter{
            .name = name,
            .type = param_type,
        };
    }

    pub fn parseFunctionDef(self: *Parser, allocator: std.mem.Allocator) !ast.Stmt {
        if (self.current_token.type != .FN) {
            return error.ExpectedFnDef;
        }
        self.advance();

        if (self.current_token.type != .IDENT) {
            return error.ExpectedFnName;
        }

        const fn_name = try allocator.dupe(u8, self.current_token.value);
        self.advance();

        if (self.current_token.type != .RPAREN) {
            return error.ExpectedParen;
        }
        self.advance();

        var param_list = std.ArrayList(ast.Parameter).init(allocator);
        defer param_list.deinit();
        while (self.current_token.type != .LPAREN) {
            self.advance();
            try param_list.append(try self.parseParameter(allocator));
            //self.advance();
        }
        self.advance(); // i know this doesn't actually check for the existence of lparen, but...

        if (self.current_token.type != .ARROW) {
            return error.ExpectedArrow;
        }
        self.advance();

        const return_type = try self.parseType();
        self.advance();

        if (self.current_token.type != .LCURLY) {
            return error.ExpectedFnBody;
        }
        self.advance();

        var fn_body = std.ArrayList(ast.Stmt).init(allocator);
        defer fn_body.deinit();

        while (self.current_token.type != .RCURLY) {
            self.advance();

            if (self.current_token.type == .LET) {
                try fn_body.append(try self.parseLetStatement(allocator));
            } else if (self.current_token.type == .RETURN) {
                try fn_body.append(try self.parseReturnStatement(allocator));
                break;
            } else {
                unreachable; // i love it
            }
        }

        return ast.Stmt{ .fun_def = .{
            .fun_name = fn_name,
            .fun_params = param_list,
            .fun_body = fn_body,
            .fun_type = return_type,
        } };
    }

    fn parseFunctionCall(self: *Parser, allocator: std.mem.Allocator, name: []const u8) !*ast.Expr {
        // theoretically, parseFunctionCall should start after the (, and only parse the args/)
        var param_list = std.ArrayList(ast.Parameter).init(allocator);
        defer param_list.deinit();
        while (self.current_token.type != .LPAREN) {
            self.advance();
            try param_list.append(try self.parseParameter(allocator));
        }
        self.advance();

        const fun = try allocator.create(ast.Expr);

        fun.* = ast.Expr{ .fun_call = .{
            .fun_name = name,
            .fun_args = param_list,
        } };

        return fun;
    }

    fn advance(self: *Parser) void {
        self.current_token = self.lexer.nextToken();
    }
};
