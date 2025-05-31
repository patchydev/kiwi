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
            (self.pos + 6 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 6]) or self.source[self.pos + 6] == 'c'))
        {
            self.pos += 6;
            return ast.Token{ .type = .RETURN, .value = self.source[start..self.pos] };
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

        self.pos += 1;
        return ast.Token{ .type = .INVALID, .value = self.source[start..self.pos] };
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.pos < self.source.len and std.ascii.isWhitespace(self.source[self.pos])) {
            self.pos += 1;
        }
    }
};
