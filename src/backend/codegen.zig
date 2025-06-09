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
    local = ?std.StringHashMap(c.LLVMValueRef),

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

    pub fn genType(self: *CodeGen, _type: ast.Type) c.LLVMValueRef {
        switch (_type) {
            .int32 => {
                return c.LLVMInt32TypeInContext(self.context);
            },
        }
    }

    pub fn genFnDef(self: *CodeGen, fun: ast.Stmt.fun_def, allocator: std.mem.Allocator) !void {
        var params = try allocator.alloc(c.LLVMTypeREf, fun.fun_params.items.len);
        defer params.deinit();

        for (fun.fun_params.items, 0..) |p, i| {
            params[i] = self.genType(p.type);
        }

        const ret_type = self.genType(fun.fun_type);
        const func_type = c.LLVMFunctionType(ret_type, params.ptr, @intCast(params.len), 0);

        const func_nameZ = try allocator.dupeZ(u8, fun.fun_name);
        defer allocator.free(func_nameZ);

        const func_val = c.LLVMAddFunction(self.module, func_nameZ.ptr, func_type);
        try self.functions.put(fun.fun_name, func_val);

        const entry_block = c.LLVMAppendBasicBlockInContext(self.context, func_val, "entry");
        c.LLVMPositionBuilderAtEnd(self.builder, entry_block);

        self.locals = std.StringHashMap(c.LLVMValueRef).init(allocator);

        var ret_value: ?c.LLVMValueRef = null;

        for (fun.fun_body.items) |stmt| {
            switch (stmt) {
                ._return => |expr| {
                    ret_value = self.generateExpr(expr);
                },
                .bind => |bind_d| {
                    const value = self.generateExpr(bind_d.var_value);
                    try self.locals.?.put(bind_d.var_name, value);
                },
                .fun_def => return error.NoNestedFunctions,
            }
        }

        _ = c.LLVMBuildRet(self.builder, ret_value);

        self.locals.?.deinit();
        self.locals = null;
    }

    pub fn generateExpr(self: *CodeGen, expr: *ast.Expr) c.LLVMValueRef {
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
                    .MULTIPLY => return c.LLVMBuildMul(self.builder, left_val, right_val, "multmp"),
                    .DIVIDE => return c.LLVMBuildSDiv(self.builder, left_val, right_val, "divtmp"),
                    else => unreachable,
                }
            },
            .variable => |variable| {
                // this doesn't handle if variables aren't defined
                // so will need to fix that at some point :3
                std.debug.print("looking for variable '{s}'\n", .{variable});
                return self.symbols.get(variable) orelse unreachable;
            },
            else => {
                std.debug.print("function call", .{});
            },
        }
    }

    pub fn generateMain(self: *CodeGen, list: std.ArrayList(ast.Stmt)) !void {
        const int_type = c.LLVMInt32TypeInContext(self.context);
        const main_type = c.LLVMFunctionType(int_type, null, 0, 0);
        const main_func = c.LLVMAddFunction(self.module, "main", main_type);

        const entry_block = c.LLVMAppendBasicBlockInContext(self.context, main_func, "entry");
        c.LLVMPositionBuilderAtEnd(self.builder, entry_block);

        var result: ?c.LLVMValueRef = null;
        //const result = self.generateExpr(expr);
        for (list.items) |item| {
            switch (item) {
                ._return => {
                    result = self.generateExpr(item._return);
                },
                .bind => {
                    const value = self.generateExpr(item.bind.var_value);
                    std.debug.print("storing variable '{s}'\n", .{item.bind.var_name});
                    try self.symbols.put(item.bind.var_name, value);
                },
                else => {
                    std.debug.print("function def", .{});
                },
            }
        }
        _ = c.LLVMBuildRet(self.builder, result.?);
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
