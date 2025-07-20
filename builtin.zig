const std = @import("std");
const parse = @import("parse.zig");
const interpreter = @import("interpreter.zig");
const Interpreter = interpreter.Interpreter;
const Value = interpreter.Value;

const Builtin = struct {
    name: []const u8,
    args: usize, // minimum number of args (for variadic functions)
    variadic: bool = false, // true if function accepts any number of args >= args
    return_type: parse.ASTNodeType,
    callback: ?*const fn (*Interpreter, *parse.ASTNode) anyerror!Value = null,
};

pub const BuiltinType = enum {
    print,
    println,
    len,
    pi,
    e,
    sin,
    cos,
    tan,
    sqrt,
    pow,
};

pub const Builtins = [_]Builtin{
    .{ .name = "print", .args = 0, .variadic = true, .return_type = parse.ASTNodeType.string, .callback = &print },
    .{ .name = "println", .args = 0, .variadic = true, .return_type = parse.ASTNodeType.string, .callback = &println },
    .{ .name = "len", .args = 1, .variadic = false, .return_type = parse.ASTNodeType.number, .callback = &len },
    .{ .name = "pi", .args = 0, .variadic = false, .return_type = parse.ASTNodeType.number, .callback = &pi },
    .{ .name = "e", .args = 0, .variadic = false, .return_type = parse.ASTNodeType.number, .callback = &e },
    .{ .name = "sin", .args = 1, .variadic = false, .return_type = parse.ASTNodeType.number, .callback = &sin },
    .{ .name = "cos", .args = 1, .variadic = false, .return_type = parse.ASTNodeType.number, .callback = &cos },
    .{ .name = "tan", .args = 1, .variadic = false, .return_type = parse.ASTNodeType.number, .callback = &tan },
    .{ .name = "sqrt", .args = 1, .variadic = false, .return_type = parse.ASTNodeType.number, .callback = &sqrt },
    .{ .name = "pow", .args = 2, .variadic = false, .return_type = parse.ASTNodeType.number, .callback = &pow },
};

pub fn getBuiltin(name: []const u8) ?Builtin {
    const bltn = std.meta.stringToEnum(BuiltinType, name) orelse {
        std.debug.print("Error: builtin function not found: {s}\n", .{name});
        return null;
    };
    return Builtins[@intFromEnum(bltn)];
}

fn print(self: *Interpreter, args_node: *parse.ASTNode) anyerror!Value {
    return try self.evaluatePrint(args_node, false);
}

fn println(self: *Interpreter, args_node: *parse.ASTNode) anyerror!Value {
    return try self.evaluatePrint(args_node, true);
}

fn len(self: *Interpreter, args_node: *parse.ASTNode) anyerror!Value {
    if (args_node.args[0].* != .string) {
        const value = try self.evaluate(args_node.args[0]);
        if (value != .string) {
            std.debug.print("Error: len expects a string!\n", .{});
            return error.TypeError;
        }
        return Value{ .number = @floatFromInt(value.string.len) };
    } else {
        return Value{ .number = @floatFromInt(args_node.args[0].string.len) };
    }
}

fn pi(_: *Interpreter, _: *parse.ASTNode) anyerror!Value {
    return Value{ .number = std.math.pi };
}

fn e(_: *Interpreter, _: *parse.ASTNode) anyerror!Value {
    return Value{ .number = std.math.e };
}

fn sin(self: *Interpreter, args_node: *parse.ASTNode) anyerror!Value {
    const arg = try self.evaluate(args_node.args[0]);
    return Value{ .number = std.math.sin(arg.number) };
}

fn cos(self: *Interpreter, args_node: *parse.ASTNode) anyerror!Value {
    const arg = try self.evaluate(args_node.args[0]);
    return Value{ .number = std.math.cos(arg.number) };
}

fn tan(self: *Interpreter, args_node: *parse.ASTNode) anyerror!Value {
    const arg = try self.evaluate(args_node.args[0]);
    return Value{ .number = std.math.tan(arg.number) };
}

fn sqrt(self: *Interpreter, args_node: *parse.ASTNode) anyerror!Value {
    const arg = try self.evaluate(args_node.args[0]);
    return Value{ .number = std.math.sqrt(arg.number) };
}

fn pow(self: *Interpreter, args_node: *parse.ASTNode) anyerror!Value {
    const arg1 = try self.evaluate(args_node.args[0]);
    const arg2 = try self.evaluate(args_node.args[1]);
    return Value{ .number = std.math.pow(f64, arg1.number, arg2.number) };
}
