const std = @import("std");
const ast = @import("ast.zig");

pub const Lexer = struct {
    source: []const u8,
    pos: usize,

    pub fn init(source: []const u8) Lexer {
        return Lexer{ .source = source, .pos = 0 };
    }

    pub fn nextToken(self: *Lexer) ast.Token {
        self.skipWhitespace();

        if (self.pos >= self.source.len) {
            return ast.Token{ .type = .EOF, .value = "" };
        }

        const start = self.pos;

        if (self.pos + 6 <= self.source.len and
            std.mem.eql(u8, self.source[self.pos .. self.pos + 6], "return") and
            (self.pos + 6 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 6])))
        {
            self.pos += 6;

            return ast.Token{ .type = .RETURN, .value = self.source[start..self.pos] };
        }

        if (self.pos + 3 <= self.source.len and std.mem.eql(u8, self.source[self.pos .. self.pos + 3], "let") and (self.pos + 3 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 3]))) {
            self.pos += 3;
            return ast.Token{ .type = .LET, .value = self.source[start..self.pos] };
        }
        if (self.pos + 2 <= self.source.len and std.mem.eql(u8, self.source[self.pos .. self.pos + 2], "fn") and (self.pos + 2 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 2]))) {
            self.pos += 2;
            return ast.Token{ .type = .FN, .value = self.source[start..self.pos] };
        }

        if (std.ascii.isAlphabetic(self.source[self.pos])) {
            while (self.pos < self.source.len and std.ascii.isAlphabetic(self.source[self.pos])) {
                self.pos += 1;
            }

            return ast.Token{ .type = .IDENT, .value = self.source[start..self.pos] };
        }

        if (self.source[self.pos] == '=') {
            self.pos += 1;
            return ast.Token{ .type = .ASSIGN, .value = self.source[start..self.pos] };
        }

        if (std.ascii.isDigit(self.source[self.pos])) {
            while (self.pos < self.source.len and std.ascii.isDigit(self.source[self.pos])) {
                self.pos += 1;
            }
            return ast.Token{ .type = .NUMBER, .value = self.source[start..self.pos] };
        }

        if (self.source[self.pos] == ';') {
            self.pos += 1;
            return ast.Token{ .type = .SEMICOLON, .value = self.source[start..self.pos] };
        }

        if (self.source[self.pos] == '+') {
            self.pos += 1;
            return ast.Token{ .type = .PLUS, .value = self.source[start..self.pos] };
        }

        if (self.source[self.pos] == '-') {
            self.pos += 1;
            return ast.Token{ .type = .MINUS, .value = self.source[start..self.pos] };
        }

        if (self.source[self.pos] == '*') {
            self.pos += 1;
            return ast.Token{ .type = .MULTIPLY, .value = self.source[start..self.pos] };
        }
        if (self.source[self.pos] == '/') {
            self.pos += 1;
            return ast.Token{ .type = .DIVIDE, .value = self.source[start..self.pos] };
        }
        if (self.source[self.pos] == '(') {
            self.pos += 1;
            return ast.Token{ .type = .RPAREN, .value = self.source[start..self.pos] };
        }
        if (self.source[self.pos] == ')') {
            self.pos += 1;
            return ast.Token{ .type = .LPAREN, .value = self.source[start..self.pos] };
        }
        if (self.source[self.pos] == '{') {
            self.pos += 1;
            return ast.Token{ .type = .RCURLY, .value = self.source[start..self.pos] };
        }
        if (self.source[self.pos] == '}') {
            self.pos += 1;
            return ast.Token{ .type = .LCURLY, .value = self.source[start..self.pos] };
        }
        if (self.source[self.pos] == ',') {
            self.pos += 1;
            return ast.Token{ .type = .COMMA, .value = self.source[start..self.pos] };
        }

        self.pos += 1;
        return ast.Token{ .type = .INVALID, .value = self.source[start..self.pos] };
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.pos < self.source.len and std.ascii.isWhitespace(self.source[self.pos])) {
            self.pos += 1;
        }
    }
};
