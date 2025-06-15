const std = @import("std");
const ast = @import("ast.zig");

pub const Lexer = struct {
    source: []const u8,
    pos: usize,

    pub fn init(source: []const u8) Lexer {
        return Lexer{ .source = source, .pos = 0 };
    }

    pub fn nextToken1(self: *Lexer) ast.Token {
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

        if (self.pos + 4 <= self.source and std.mem.eql(u8, self.source[self.pos .. self.pos + 4], "true") and (self.pos + 4 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 4]))) {
            self.pos += 4;
            return ast.Token{ .type = .TRUE, .value = self.source[start..start.pos] };
        }
        if (self.pos + 5 <= self.source and std.mem.eql(u8, self.source[self.pos .. self.pos + 5], "false") and (self.pos + 5 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 5]))) {
            self.pos += 5;
            return ast.Token{ .type = .FALSE, .value = self.source[start..start.pos] };
        }
        if (self.pos + 4 <= self.source and std.mem.eql(u8, self.source[self.pos .. self.pos + 4], "bool") and (self.pos + 4 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 4]))) {
            self.pos += 4;
            return ast.Token{ .type = .BOOL, .value = self.source[start..start.pos] };
        }

        if (self.pos + 3 <= self.source.len and std.mem.eql(u8, self.source[self.pos .. self.pos + 3], "let") and (self.pos + 3 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 3]))) {
            self.pos += 3;
            return ast.Token{ .type = .LET, .value = self.source[start..self.pos] };
        }
        if (self.pos + 2 <= self.source.len and std.mem.eql(u8, self.source[self.pos .. self.pos + 2], "fn") and (self.pos + 2 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 2]))) {
            self.pos += 2;
            return ast.Token{ .type = .FN, .value = self.source[start..self.pos] };
        }
        if (self.pos + 3 <= self.source.len and std.mem.eql(u8, self.source[self.pos .. self.pos + 3], "i32") and (self.pos + 3 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 3]))) {
            self.pos += 3;
            return ast.Token{ .type = .I32, .value = self.source[start..self.pos] };
        }
        if (self.pos + 2 <= self.source.len and std.mem.eql(u8, self.source[self.pos .. self.pos + 2], "->") and (self.pos + 2 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 2]))) {
            self.pos += 2;
            return ast.Token{ .type = .ARROW, .value = self.source[start..self.pos] };
        }

        if (std.ascii.isAlphabetic(self.source[self.pos])) {
            while (self.pos < self.source.len and std.ascii.isAlphabetic(self.source[self.pos])) {
                self.pos += 1;
            }

            return ast.Token{ .type = .IDENT, .value = self.source[start..self.pos] };
        }

        if (self.pos + 2 <= self.source.len and std.mem.eql(u8, self.source[self.pos .. self.pos + 2], "==") and (self.pos + 2 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 2]))) {
            self.pos += 2;
            return ast.Token{ .type = .ISEQUAL, .value = self.source[start..self.pos] };
        }

        if (self.pos + 2 <= self.source.len and std.mem.eql(u8, self.source[self.pos .. self.pos + 2], "!=") and (self.pos + 2 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 2]))) {
            self.pos += 2;
            return ast.Token{ .type = .NOTEQUAL, .value = self.source[start..self.pos] };
        }
        if (self.pos + 2 <= self.source.len and std.mem.eql(u8, self.source[self.pos .. self.pos + 2], "<=") and (self.pos + 2 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 2]))) {
            self.pos += 2;
            return ast.Token{ .type = .ELESS, .value = self.source[start..self.pos] };
        }
        if (self.pos + 2 <= self.source.len and std.mem.eql(u8, self.source[self.pos .. self.pos + 2], ">=") and (self.pos + 2 >= self.source.len or !std.ascii.isAlphanumeric(self.source[self.pos + 2]))) {
            self.pos += 2;
            return ast.Token{ .type = .EGREATER, .value = self.source[start..self.pos] };
        }

        if (self.source[self.pos] == '<') {
            self.pos += 1;
            return ast.Token{ .type = .LESS, .value = self.source[start..self.pos] };
        }

        if (self.source[self.pos] == '>') {
            self.pos += 1;
            return ast.Token{ .type = .GREATER, .value = self.source[start..self.pos] };
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
            return ast.Token{ .type = .LPAREN, .value = self.source[start..self.pos] };
        }
        if (self.source[self.pos] == ')') {
            self.pos += 1;
            return ast.Token{ .type = .RPAREN, .value = self.source[start..self.pos] };
        }
        if (self.source[self.pos] == '{') {
            self.pos += 1;
            return ast.Token{ .type = .LCURLY, .value = self.source[start..self.pos] };
        }
        if (self.source[self.pos] == '}') {
            self.pos += 1;
            return ast.Token{ .type = .RCURLY, .value = self.source[start..self.pos] };
        }
        if (self.source[self.pos] == ',') {
            self.pos += 1;
            return ast.Token{ .type = .COMMA, .value = self.source[start..self.pos] };
        }
        if (self.source[self.pos] == ':') {
            self.pos += 1;
            return ast.Token{ .type = .COLON, .value = self.source[start..self.pos] };
        }

        self.pos += 1;
        return ast.Token{ .type = .INVALID, .value = self.source[start..self.pos] };
    }

    pub fn nextToken(self: *Lexer) ast.Token {
        self.skipWhitespace();

        if (self.pos >= self.source.len) {
            return ast.Token{ .type = .EOF, .value = "" };
        }

        const start = self.pos;

        switch (self.source[self.pos]) {
            'r' => {
                if (self.matchKw("return")) {
                    return ast.Token{ .type = .RETURN, .value = self.source[start..self.pos] };
                }
                return self.parseIdent(start);
            },
            'l' => {
                if (self.matchKw("let")) {
                    return ast.Token{ .type = .LET, .value = self.source[start..self.pos] };
                }
                return self.parseIdent(start);
            },
            'f' => {
                if (self.matchKw("fn")) {
                    return ast.Token{ .type = .FN, .value = self.source[start..self.pos] };
                }
                if (self.matchKw("false")) {
                    return ast.Token{ .type = .FALSE, .value = self.source[start..self.pos] };
                }
                return self.parseIdent(start);
            },
            'i' => {
                if (self.matchKw("i32")) {
                    return ast.Token{ .type = .I32, .value = self.source[start..self.pos] };
                }
                return self.parseIdent(start);
            },
            'b' => {
                if (self.matchKw("bool")) {
                    return ast.Token{ .type = .BOOL, .value = self.source[start..self.pos] };
                }
                return self.parseIdent(start);
            },
            't' => {
                if (self.matchKw("true")) {
                    return ast.Token{ .type = .TRUE, .value = self.source[start..self.pos] };
                }
                return self.parseIdent(start);
            },
            '-' => {
                if (self.pos + 1 < self.source.len and self.source[self.pos + 1] == '>') {
                    self.pos += 2;
                    return ast.Token{ .type = .ARROW, .value = self.source[start..self.pos] };
                }
                self.pos += 1;
                return ast.Token{ .type = .MINUS, .value = self.source[start..self.pos] };
            },
            'a'...'z', 'A'...'Z' => {
                return self.parseIdent(start);
            },
            '0'...'9' => {
                while (self.pos < self.source.len and std.ascii.isDigit(self.source[self.pos])) {
                    self.pos += 1;
                }
                return ast.Token{ .type = .NUMBER, .value = self.source[start..self.pos] };
            },
            '=' => {
                if (self.pos + 1 < self.source.len and self.source[self.pos + 1] == '=') {
                    self.pos += 2;
                    return ast.Token{ .type = .ISEQUAL, .value = self.source[start..self.pos] };
                }
                self.pos += 1;
                return ast.Token{ .type = .ASSIGN, .value = self.source[start..self.pos] };
            },
            '!' => {
                if (self.pos + 1 < self.source.len and self.source[self.pos + 1] == '=') {
                    self.pos += 2;
                    return ast.Token{ .type = .NOTEQUAL, .value = self.source[start..self.pos] };
                }
                self.pos += 1;
                return ast.Token{ .type = .NOT, .value = self.source[start..self.pos] };
            },
            '>' => {
                if (self.pos + 1 < self.source.len and self.source[self.pos + 1] == '=') {
                    self.pos += 2;
                    return ast.Token{ .type = .EGREATER, .value = self.source[start..self.pos] };
                }
                self.pos += 1;
                return ast.Token{ .type = .GREATER, .value = self.source[start..self.pos] };
            },
            '<' => {
                if (self.pos + 1 < self.source.len and self.source[self.pos + 1] == '=') {
                    self.pos += 2;
                    return ast.Token{ .type = .ELESS, .value = self.source[start..self.pos] };
                }
                self.pos += 1;
                return ast.Token{ .type = .LESS, .value = self.source[start..self.pos] };
            },
            ';' => {
                self.pos += 1;
                return ast.Token{ .type = .SEMICOLON, .value = self.source[start..self.pos] };
            },
            '+' => {
                self.pos += 1;
                return ast.Token{ .type = .PLUS, .value = self.source[start..self.pos] };
            },
            '*' => {
                self.pos += 1;
                return ast.Token{ .type = .MULTIPLY, .value = self.source[start..self.pos] };
            },
            '/' => {
                self.pos += 1;
                return ast.Token{ .type = .DIVIDE, .value = self.source[start..self.pos] };
            },
            '(' => {
                self.pos += 1;
                return ast.Token{ .type = .LPAREN, .value = self.source[start..self.pos] };
            },
            ')' => {
                self.pos += 1;
                return ast.Token{ .type = .RPAREN, .value = self.source[start..self.pos] };
            },
            '{' => {
                self.pos += 1;
                return ast.Token{ .type = .LCURLY, .value = self.source[start..self.pos] };
            },
            '}' => {
                self.pos += 1;
                return ast.Token{ .type = .RCURLY, .value = self.source[start..self.pos] };
            },
            ',' => {
                self.pos += 1;
                return ast.Token{ .type = .COMMA, .value = self.source[start..self.pos] };
            },
            ':' => {
                self.pos += 1;
                return ast.Token{ .type = .COLON, .value = self.source[start..self.pos] };
            },
            else => {
                self.pos += 1;
                return ast.Token{ .type = .INVALID, .value = self.source[start..self.pos] };
            },
        }
    }

    fn matchKw(self: *Lexer, kw: []const u8) bool {
        if (self.pos + kw.len > self.source.len) {
            return false;
        }

        if (!std.mem.eql(u8, self.source[self.pos .. self.pos + kw.len], kw)) {
            return false;
        }

        if (self.pos + kw.len < self.source.len and std.ascii.isAlphanumeric(self.source[self.pos + kw.len])) {
            return false;
        }

        self.pos += kw.len;
        return true;
    }

    fn parseIdent(self: *Lexer, start: usize) ast.Token {
        while (self.pos < self.source.len and std.ascii.isAlphabetic(self.source[self.pos])) {
            self.pos += 1;
        }
        return ast.Token{ .type = .IDENT, .value = self.source[start..self.pos] };
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.pos < self.source.len and std.ascii.isWhitespace(self.source[self.pos])) {
            self.pos += 1;
        }
    }
};
