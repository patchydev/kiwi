const std = @import("std");
const print = std.debug.print;

const c = @cImport({
    @cInclude("llvm-c/Core.h");
    @cInclude("llvm-c/Target.h");
    @cInclude("llvm-c/TargetMachine.h");
});

const TokenType = enum {
    RETURN,
    NUMBER,
    SEMICOLON,
    PLUS,
    MINUS,
    EOF,
    INVALID,
};

const Token = struct {
    type: TokenType,
    value: []const u8,
};

const ExprType = enum {
    number,
    op,
};

const Expr = union(ExprType) {
    number: i32,
    op: struct {
        left: *Expr,
        op: TokenType,
        right: *Expr,
    },
};

const Lexer = struct {
    source: []const u8,
    pos: usize,

    pub fn init(source: []const u8) Lexer {
        return Lexer{ .source = source, .pos = 0 };
    }

    pub fn nextToken(self: *Lexer) Token {
        self.skipWhitespace();

        if (self.pos >= self.source.len) {
            return Token{ .type = .EOF, .value = "" };
        }

        const start = self.pos;

        if (self.pos + 6 <= self.source.len and
            std.mem.eql(u8, self.source[self.pos .. self.pos + 6], "return"))
        {
            self.pos += 6;
            return Token{ .type = .RETURN, .value = self.source[start..self.pos] };
        }

        if (std.ascii.isDigit(self.source[self.pos])) {
            while (self.pos < self.source.len and std.ascii.isDigit(self.source[self.pos])) {
                self.pos += 1;
            }
            return Token{ .type = .NUMBER, .value = self.source[start..self.pos] };
        }

        if (self.source[self.pos] == ';') {
            self.pos += 1;
            return Token{ .type = .SEMICOLON, .value = self.source[start..self.pos] };
        }

        if (self.source[self.pos] == '+') {
            self.pos += 1;
            return Token{ .type = .PLUS, .value = self.source[start..self.pos] };
        }

        if (self.source[self.pos] == '-') {
            self.pos += 1;
            return Token{ .type = .MINUS, .value = self.source[start..self.pos] };
        }

        self.pos += 1;
        return Token{ .type = .INVALID, .value = self.source[start..self.pos] };
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.pos < self.source.len and std.ascii.isWhitespace(self.source[self.pos])) {
            self.pos += 1;
        }
    }
};

const Parser = struct {
    lexer: *Lexer,
    current_token: Token,

    pub fn init(lexer: *Lexer) Parser {
        var parser = Parser{
            .lexer = lexer,
            .current_token = undefined,
        };
        parser.current_token = lexer.nextToken();
        return parser;
    }

    pub fn parsePrimary(self: *Parser, allocator: std.mem.Allocator) !*Expr {
        if (self.current_token.type != .NUMBER) {
            return error.ExpectedNumber;
        }

        const value = try std.fmt.parseInt(i32, self.current_token.value, 10);
        self.advance();

        const node = try allocator.create(Expr);
        node.* = Expr{ .number = value };
        return node;
    }

    pub fn parseExpression(self: *Parser, allocator: std.mem.Allocator) !*Expr {
        var left = try self.parsePrimary(allocator);

        while (self.current_token.type == .PLUS or self.current_token.type == .MINUS) {
            const op_type = self.current_token.type;
            self.advance();
            const right = try self.parsePrimary(allocator);

            const op_node = try allocator.create(Expr);
            op_node.* = Expr{ .op = .{
                .left = left,
                .op = op_type,
                .right = right,
            } };
            left = op_node;
        }

        return left;
    }

    pub fn parseReturnStatement(self: *Parser, allocator: std.mem.Allocator) !*Expr {
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

const CodeGen = struct {
    context: c.LLVMContextRef,
    module: c.LLVMModuleRef,
    builder: c.LLVMBuilderRef,

    pub fn init(module_name: []const u8) CodeGen {
        const context = c.LLVMContextCreate();
        const module = c.LLVMModuleCreateWithNameInContext(module_name.ptr, context);
        const builder = c.LLVMCreateBuilderInContext(context);

        return CodeGen{
            .context = context,
            .module = module,
            .builder = builder,
        };
    }

    pub fn deinit(self: *CodeGen) void {
        c.LLVMDisposeBuilder(self.builder);
        c.LLVMDisposeModule(self.module);
        c.LLVMContextDispose(self.context);
    }

    pub fn generateExpr(self: *CodeGen, expr: *Expr) c.LLVMValueRef {
        const int_type = c.LLVMInt32TypeInContext(self.context);

        switch (expr.*) {
            .number => |n| {
                return c.LLVMConstInt(int_type, @intCast(n), 0);
            },
            .op => |op_data| {
                const left_val = self.generateExpr(op_data.left);
                const right_val = self.generateExpr(op_data.right);

                switch (op_data.op) {
                    .PLUS => return c.LLVMBuildAdd(self.builder, left_val, right_val, "addtmp"),
                    .MINUS => return c.LLVMBuildSub(self.builder, left_val, right_val, "subtmp"),
                    else => unreachable,
                }
            },
        }
    }

    pub fn generateMain(self: *CodeGen, expr: *Expr) void {
        const int_type = c.LLVMInt32TypeInContext(self.context);
        const main_type = c.LLVMFunctionType(int_type, null, 0, 0);
        const main_func = c.LLVMAddFunction(self.module, "main", main_type);

        const entry_block = c.LLVMAppendBasicBlockInContext(self.context, main_func, "entry");
        c.LLVMPositionBuilderAtEnd(self.builder, entry_block);

        const result = self.generateExpr(expr);
        _ = c.LLVMBuildRet(self.builder, result);
    }

    pub fn generateObjectFile(self: *CodeGen, output_path: []const u8, allocator: std.mem.Allocator) !void {
        _ = c.LLVMInitializeAllTargetInfos();
        _ = c.LLVMInitializeAllTargets();
        _ = c.LLVMInitializeAllTargetMCs();
        _ = c.LLVMInitializeAllAsmParsers();
        _ = c.LLVMInitializeAllAsmPrinters();

        const target_triple = c.LLVMGetDefaultTargetTriple();
        defer c.LLVMDisposeMessage(target_triple);

        c.LLVMSetTarget(self.module, target_triple);

        var target: c.LLVMTargetRef = undefined;
        var error_msg: [*c]u8 = undefined;

        if (c.LLVMGetTargetFromTriple(target_triple, &target, &error_msg) != 0) {
            defer c.LLVMDisposeMessage(error_msg);
            return error.TargetNotFound;
        }

        const target_machine = c.LLVMCreateTargetMachine(
            target,
            target_triple,
            "generic",
            "",
            c.LLVMCodeGenLevelDefault,
            c.LLVMRelocDefault,
            c.LLVMCodeModelDefault,
        );
        defer c.LLVMDisposeTargetMachine(target_machine);

        if (target_machine == null) {
            return error.TargetMachineCreationFailed;
        }

        const data_layout = c.LLVMCreateTargetDataLayout(target_machine);
        const data_layout_str = c.LLVMCopyStringRepOfTargetData(data_layout);
        defer c.LLVMDisposeMessage(data_layout_str);
        c.LLVMSetDataLayout(self.module, data_layout_str);
        c.LLVMDisposeTargetData(data_layout);

        const obj_path = try std.fmt.allocPrint(allocator, "{s}.o", .{output_path});
        defer allocator.free(obj_path);

        const obj_path_z = try allocator.dupeZ(u8, obj_path);
        defer allocator.free(obj_path_z);

        if (c.LLVMTargetMachineEmitToFile(
            target_machine,
            self.module,
            obj_path_z.ptr,
            c.LLVMObjectFile,
            &error_msg,
        ) != 0) {
            defer c.LLVMDisposeMessage(error_msg);
            print("error: {s}\n", .{error_msg});
            return error.ObjectFileGenerationFailed;
        }
    }
};

pub fn freeExpr(expr: *Expr, allocator: std.mem.Allocator) void {
    switch (expr.*) {
        .number => {},
        .op => |op_data| {
            freeExpr(op_data.left, allocator);
            freeExpr(op_data.right, allocator);
        },
    }

    allocator.destroy(expr);
}

pub fn compileAndGenerate(source: []const u8, output_path: []const u8, allocator: std.mem.Allocator) !void {
    var lexer = Lexer.init(source);
    var parser = Parser.init(&lexer);

    const expr = try parser.parseReturnStatement(allocator);
    defer freeExpr(expr, allocator);

    var codegen = CodeGen.init("main_module");
    defer codegen.deinit();

    codegen.generateMain(expr);
    try codegen.generateObjectFile(output_path, allocator);
}

pub fn compileFile(file_path: []const u8, output_path: []const u8, allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const source = try allocator.alloc(u8, file_size);
    defer allocator.free(source);

    _ = try file.readAll(source);

    try compileAndGenerate(source, output_path, allocator);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const input_file = args[1];
    const output_file = if (args.len >= 3) args[2] else "output";

    compileFile(input_file, output_file, allocator) catch |err| {
        print("you're a FAILURE: {}\n", .{err});
        std.process.exit(1);
    };
}
