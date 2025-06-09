const std = @import("std");
const ast = @import("../frontend/ast.zig");

const c = @cImport({
    @cInclude("llvm-c/Core.h");
    @cInclude("llvm-c/Target.h");
    @cInclude("llvm-c/TargetMachine.h");
});

pub const CodeGen = struct {
    context: c.LLVMContextRef,
    module: c.LLVMModuleRef,
    builder: c.LLVMBuilderRef,
    symbols: std.StringHashMap(c.LLVMValueRef),
    functions: std.StringHashMap(c.LLVMValueRef),
    local: ?std.StringHashMap(c.LLVMValueRef),

    pub fn init(module_name: []const u8, allocator: std.mem.Allocator) CodeGen {
        const context = c.LLVMContextCreate();
        const module = c.LLVMModuleCreateWithNameInContext(module_name.ptr, context);
        const builder = c.LLVMCreateBuilderInContext(context);
        const symbols = std.StringHashMap(c.LLVMValueRef).init(allocator);
        const functions = std.StringHashMap(c.LLVMValueRef).init(allocator);
        const local = null;

        return CodeGen{
            .context = context,
            .module = module,
            .builder = builder,
            .symbols = symbols,
            .functions = functions,
            .local = local,
        };
    }

    pub fn deinit(self: *CodeGen) void {
        c.LLVMDisposeBuilder(self.builder);
        c.LLVMDisposeModule(self.module);
        c.LLVMContextDispose(self.context);
        self.symbols.deinit();
        self.functions.deinit();
        if (self.local) |*locals| {
            locals.deinit();
        }
    }

    pub fn genType(self: *CodeGen, _type: ast.Type) c.LLVMTypeRef {
        switch (_type) {
            .int32 => {
                return c.LLVMInt32TypeInContext(self.context);
            },
        }
    }

    pub fn genFnDef(self: *CodeGen, fun: ast.FnDef, allocator: std.mem.Allocator) !void {
        std.debug.print("Starting genFnDef for function: {s}\n", .{fun.fun_name});
        std.debug.print("Function has {} parameters\n", .{fun.fun_params.items.len});

        var params = try allocator.alloc(c.LLVMTypeRef, fun.fun_params.items.len);
        defer allocator.free(params);

        for (fun.fun_params.items, 0..) |p, i| {
            std.debug.print("Processing parameter {}: {s}\n", .{ i, p.name });
            params[i] = self.genType(p.type);
        }

        std.debug.print("Generating return type\n", .{});
        const ret_type = self.genType(fun.fun_type);
        std.debug.print("Creating function type\n", .{});
        const func_type = c.LLVMFunctionType(ret_type, params.ptr, @intCast(params.len), 0);

        std.debug.print("Creating function name string\n", .{});
        const func_nameZ = try allocator.dupeZ(u8, fun.fun_name);
        defer allocator.free(func_nameZ);

        std.debug.print("Adding function to module\n", .{});
        const func_val = c.LLVMAddFunction(self.module, func_nameZ.ptr, func_type);
        std.debug.print("Storing function in functions map\n", .{});
        try self.functions.put(fun.fun_name, func_val);

        std.debug.print("Creating entry block\n", .{});
        const entry_block = c.LLVMAppendBasicBlockInContext(self.context, func_val, "entry");
        c.LLVMPositionBuilderAtEnd(self.builder, entry_block);

        std.debug.print("Initializing local variables map\n", .{});
        self.local = std.StringHashMap(c.LLVMValueRef).init(allocator);

        var ret_value: ?c.LLVMValueRef = null;

        std.debug.print("Processing function body with {} statements\n", .{fun.fun_body.items.len});
        for (fun.fun_body.items, 0..) |stmt, i| {
            std.debug.print("Processing function body statement {}: {}\n", .{ i, stmt });
            switch (stmt) {
                ._return => |expr| {
                    std.debug.print("Generating return expression in function\n", .{});
                    ret_value = try self.generateExpr(expr);
                    std.debug.print("Return expression generated\n", .{});
                },
                .bind => |bind_d| {
                    std.debug.print("Generating bind in function: {s}\n", .{bind_d.var_name});
                    const value = try self.generateExpr(bind_d.var_value);
                    try self.local.?.put(bind_d.var_name, value);
                    std.debug.print("Bind generated\n", .{});
                },
                .fun_def => return error.NoNestedFunctions,
            }
        }

        std.debug.print("Building function return\n", .{});
        _ = c.LLVMBuildRet(self.builder, ret_value.?);

        std.debug.print("Cleaning up local variables\n", .{});
        self.local.?.deinit();
        self.local = null;
        std.debug.print("genFnDef completed successfully\n", .{});
    }

    pub fn generateExpr(self: *CodeGen, expr: *ast.Expr) !c.LLVMValueRef {
        std.debug.print("generateExpr called with expression type: {}\n", .{expr.*});

        const int_type = c.LLVMInt32TypeInContext(self.context);

        switch (expr.*) {
            .number => |n| {
                std.debug.print("Generating number: {}\n", .{n});
                return c.LLVMConstInt(int_type, @intCast(n), 0);
            },
            .op => |op_data| {
                std.debug.print("Generating binary operation\n", .{});
                const left_val = try self.generateExpr(op_data.left);
                const right_val = try self.generateExpr(op_data.right);

                switch (op_data.op) {
                    .PLUS => return c.LLVMBuildAdd(self.builder, left_val, right_val, "addtmp"),
                    .MINUS => return c.LLVMBuildSub(self.builder, left_val, right_val, "subtmp"),
                    .MULTIPLY => return c.LLVMBuildMul(self.builder, left_val, right_val, "multmp"),
                    .DIVIDE => return c.LLVMBuildSDiv(self.builder, left_val, right_val, "divtmp"),
                    else => unreachable,
                }
            },
            .variable => |variable| {
                std.debug.print("Generating variable access: '{s}'\n", .{variable});
                if (self.local) |l| {
                    if (l.get(variable)) |val| {
                        std.debug.print("Found variable in local scope\n", .{});
                        return val;
                    }
                }
                std.debug.print("Looking for variable in global scope\n", .{});
                return self.symbols.get(variable) orelse {
                    std.debug.print("Variable not found: '{s}'\n", .{variable});
                    unreachable;
                };
            },
            .fun_call => |fun| {
                std.debug.print("Generating function call: '{s}'\n", .{fun.fun_name});
                std.debug.print("Function has {} arguments\n", .{fun.fun_args.items.len});

                std.debug.print("Looking up function in functions map\n", .{});
                const func = self.functions.get(fun.fun_name) orelse {
                    std.debug.print("Function not found: '{s}'\n", .{fun.fun_name});
                    unreachable;
                };
                std.debug.print("Function found successfully\n", .{});

                std.debug.print("Creating arguments list\n", .{});
                var args = std.ArrayList(c.LLVMValueRef).init(std.heap.page_allocator);
                defer args.deinit();

                for (fun.fun_args.items, 0..) |arg, i| {
                    std.debug.print("Processing argument {}\n", .{i});
                    try args.append(try self.generateExpr(arg));
                }
                std.debug.print("All arguments processed\n", .{});

                std.debug.print("Getting function type\n", .{});
                const func_type = c.LLVMGlobalGetValueType(func);
                std.debug.print("Building call instruction\n", .{});

                return c.LLVMBuildCall2(self.builder, func_type, func, args.items.ptr, @intCast(args.items.len), "calltmp");
            },
        }
    }

    pub fn generateMain(self: *CodeGen, list: std.ArrayList(ast.Stmt), allocator: std.mem.Allocator) !void {
        std.debug.print("Starting generateMain with {} statements\n", .{list.items.len});

        for (list.items, 0..) |item, i| {
            std.debug.print("Processing statement {}: {}\n", .{ i, item });
            switch (item) {
                .fun_def => |func_def| {
                    std.debug.print("Generating function definition for: {s}\n", .{func_def.fun_name});
                    try self.genFnDef(func_def, allocator);
                    std.debug.print("Function definition generated successfully\n", .{});
                },
                else => {
                    std.debug.print("Skipping non-function statement\n", .{});
                },
            }
        }

        std.debug.print("Creating main function\n", .{});
        const int_type = c.LLVMInt32TypeInContext(self.context);
        const main_type = c.LLVMFunctionType(int_type, null, 0, 0);
        const main_func = c.LLVMAddFunction(self.module, "main", main_type);
        std.debug.print("Main function created\n", .{});

        const entry_block = c.LLVMAppendBasicBlockInContext(self.context, main_func, "entry");
        c.LLVMPositionBuilderAtEnd(self.builder, entry_block);
        std.debug.print("Entry block created\n", .{});

        var result: ?c.LLVMValueRef = null;

        for (list.items, 0..) |item, i| {
            std.debug.print("Processing main body statement {}: {}\n", .{ i, item });
            switch (item) {
                ._return => {
                    std.debug.print("Generating return expression\n", .{});
                    result = try self.generateExpr(item._return);
                    std.debug.print("Return expression generated\n", .{});
                },
                .bind => {
                    std.debug.print("Generating bind statement for: {s}\n", .{item.bind.var_name});
                    const value = try self.generateExpr(item.bind.var_value);
                    std.debug.print("storing variable '{s}'\n", .{item.bind.var_name});
                    try self.symbols.put(item.bind.var_name, value);
                    std.debug.print("Bind statement generated\n", .{});
                },
                .fun_def => {
                    std.debug.print("Skipping function definition in main body\n", .{});
                },
            }
        }

        std.debug.print("Building return instruction\n", .{});
        _ = c.LLVMBuildRet(self.builder, result.?);
        std.debug.print("generateMain completed successfully\n", .{});
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
            std.debug.print("error: {s}\n", .{error_msg});
            return error.ObjectFileGenerationFailed;
        }
    }
};
