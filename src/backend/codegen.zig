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
                    else => unreachable,
                }
            },
        }
    }

    pub fn generateMain(self: *CodeGen, expr: *ast.Expr) void {
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
            std.debug.print("error: {s}\n", .{error_msg});
            return error.ObjectFileGenerationFailed;
        }
    }
};
