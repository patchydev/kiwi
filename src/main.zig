const std = @import("std");
const codegen = @import("backend/codegen.zig");
const ast = @import("frontend/ast.zig");
const lexer = @import("frontend/lexer.zig");
const parser = @import("frontend/parser.zig");

fn compileAndGenerate(source: []const u8, output_path: []const u8, allocator: std.mem.Allocator) !void {
    var lex = lexer.Lexer.init(source);
    var parse = parser.Parser.init(&lex);

    //const expr = try parse.parseReturnStatement(allocator);
    //defer ast.freeExpr(expr, allocator);

    const list = try parse.parseProgram(allocator);
    defer {
        for (list.items) |item| {
            ast.freeStmt(item, allocator);
        }

        list.deinit();
    }

    var code = codegen.CodeGen.init("main_module", allocator);
    defer code.deinit();

    //code.generateMain(expr);
    try code.generateMain(list, allocator);
    try code.generateObjectFile(output_path, allocator);
}

fn compileFile(file_path: []const u8, output_path: []const u8, allocator: std.mem.Allocator) !void {
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
        std.debug.print("you're a FAILURE: {}\n", .{err});
        std.process.exit(1);
    };
}
