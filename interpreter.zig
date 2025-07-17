const std = @import("std");
const parse = @import("parse.zig");
const bump = @import("bump.zig");
const env = @import("env.zig");
const Array = @import("array.zig").Array;

pub const Value = union(enum) {
    number: f64,
    boolean: bool,
    string: []const u8,
    array: *Array,
    nothing: void,
    builtin: BuiltinFunction,
};

pub const BuiltinFunction = enum {
    print,
};

pub const Interpreter = struct {
    environment: *env.Environment,
    allocator: std.mem.Allocator,
    stack: std.ArrayList(env.Environment),

    pub fn init(allocator: std.mem.Allocator) !*Interpreter {
        const environment = try allocator.create(env.Environment);
        environment.* = env.Environment.init(allocator);

        const interpreter = try allocator.create(Interpreter);
        interpreter.* = Interpreter{
            .environment = environment,
            .allocator = allocator,
            .stack = std.ArrayList(env.Environment).init(allocator),
        };
        return interpreter;
    }

    pub fn deinit(self: *Interpreter) void {
        self.environment.deinit();
        self.allocator.destroy(self.environment);
        self.stack.deinit();
        self.allocator.destroy(self);
    }

    // split the following into separate functions
    // one for primitives
    // one for binary operations
    // one for variable declarations
    // one for function calls

    pub fn evaluate(self: *Interpreter, node: *parse.ASTNode) anyerror!Value {
        return switch (node.*) {
            .number => |n| Value{ .number = n },
            .boolean => |b| Value{ .boolean = b },
            .string => |s| Value{ .string = s },
            .nothing => Value{ .nothing = {} },
            .identifier => |name| {
                const entry = self.environment.get(name) orelse return Value{ .nothing = {} };
                return entry.value.*;
            },
            .op => |op| {
                const left = try self.evaluate(op.left);
                const right = try self.evaluate(op.right);

                return switch (op.operation) {
                    .add => {
                        if (left == .number and right == .number) {
                            return Value{ .number = left.number + right.number };
                        } else if (left == .string and right == .string) {
                            const combined = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ left.string, right.string });
                            return Value{ .string = combined };
                        } else {
                            std.debug.print("Error: cannot add types\n", .{});
                            return error.TypeError;
                        }
                    },
                    .sub => {
                        if (left == .number and right == .number) {
                            return Value{ .number = left.number - right.number };
                        } else {
                            std.debug.print("Error: cannot subtract non-numbers\n", .{});
                            return error.TypeError;
                        }
                    },
                    .mul => {
                        if (left == .number and right == .number) {
                            return Value{ .number = left.number * right.number };
                        } else {
                            std.debug.print("Error: cannot multiply non-numbers\n", .{});
                            return error.TypeError;
                        }
                    },
                    .div => {
                        if (left == .number and right == .number) {
                            if (right.number == 0) {
                                std.debug.print("Error: division by zero\n", .{});
                                return error.DivisionByZero;
                            }
                            return Value{ .number = left.number / right.number };
                        } else {
                            std.debug.print("Error: cannot divide non-numbers\n", .{});
                            return error.TypeError;
                        }
                    },
                    .range => {
                        if (left == .number and right == .number) {
                            // For now, just return the left number
                            // Range implementation would need more complex logic
                            return Value{ .number = left.number };
                        } else {
                            std.debug.print("Error: range operator requires numbers\n", .{});
                            return error.TypeError;
                        }
                    },
                };
            },
            .var_decl => |decl| {
                const value = try self.evaluate(decl.right);
                try self.environment.set(decl.identifier, value);
                return value;
            },
            .block => |block| {
                var result: ?Value = null;
                for (block) |stmt| {
                    result = try self.evaluate(stmt);
                }
                return result orelse Value{ .nothing = {} };
            },
            .if_stmt => |if_stmt| {
                const condition = try self.evaluate(if_stmt.condition);
                if (self.isTruthy(condition)) {
                    return try self.evaluate(if_stmt.then_stmt);
                } else {
                    return Value{ .nothing = {} };
                    // return try self.evaluate(if_stmt.else_stmt);
                }
            },
            .bcall => |bcall| {
                return try self.evaluateBuiltinCall(bcall.name, bcall.args);
            },
            .args => |_| {
                std.debug.print("Error: args node should not be evaluated directly\n", .{});
                return error.TypeError;
            },
            .for_loop => {
                return try self.evaluateForLoop(node);
            },
            else => {
                std.debug.print("Error: unsupported node type: {}\n", .{node.*});
                return error.UnsupportedNode;
            },
        };
    }

    fn evaluateBuiltinCall(self: *Interpreter, name: []const u8, args: *parse.ASTNode) anyerror!Value {
        if (std.mem.eql(u8, name, "print")) {
            return try self.evaluatePrint(args);
        } else {
            std.debug.print("Error: unknown builtin function '{s}'\n", .{name});
            return error.UnknownBuiltin;
        }
    }

    fn evaluatePrint(self: *Interpreter, args_node: *parse.ASTNode) anyerror!Value {
        if (args_node.* != .args) {
            std.debug.print("Error: print expects arguments\n", .{});
            return error.TypeError;
        }

        const args = args_node.args;
        for (args, 0..) |arg, i| {
            const value = try self.evaluate(arg);
            try self.printValue(value);
            if (i < args.len - 1) {
                std.debug.print(" ", .{});
            }
        }
        std.debug.print("\n", .{});
        return Value{ .nothing = {} }; // I should just return void
    }

    fn evaluateForLoop(self: *Interpreter, loop_node: *parse.ASTNode) anyerror!Value {
        var a = loop_node.*.for_loop.range.op.left.*.number;
        const b = loop_node.*.for_loop.range.op.right.*.number;

        const iter_name = loop_node.*.for_loop.iter_name;

        var iter: i32 = 1;
        const iter_value: f64 = a;

        if (a > b) {
            iter = -1;
        } else if (a < b) {
            iter = 1;
        } else {
            return Value{ .nothing = {} };
        }

        const new_env = try self.allocator.create(env.Environment);
        new_env.* = env.Environment.init(self.allocator);
        new_env.parent = self.environment;
        defer {
            new_env.deinit();
            self.allocator.destroy(new_env);
        }

        try new_env.set(iter_name, Value{ .number = iter_value });

        const old_env = self.environment;
        self.environment = new_env;

        while (a != b) : (a += @as(f64, @as(f64, @floatFromInt(iter)))) {
            _ = try self.evaluate(loop_node.for_loop.body);

            const iter_val = new_env.*.get(iter_name).?.value.*.number;
            try new_env.*.set(iter_name, Value{ .number = iter_val + @as(f64, @as(f64, @floatFromInt(iter))) });
        }

        self.environment = old_env;

        return Value{ .nothing = {} };
    }

    fn printValue(self: *Interpreter, value: Value) anyerror!void {
        switch (value) {
            .number => |n| std.debug.print("{d}", .{n}),
            .boolean => |b| std.debug.print("{}", .{b}),
            .string => |s| std.debug.print("{s}", .{s}),
            .array => |a| {
                std.debug.print("[", .{});
                for (a.values.items, 0..) |item, i| {
                    try self.printValue(item.value.*);
                    if (i < a.values.items.len - 1) {
                        std.debug.print(", ", .{});
                    }
                }
                std.debug.print("]", .{});
            },
            .nothing => std.debug.print("nothing", .{}),
            .builtin => |b| std.debug.print("builtin({})", .{b}),
        }
    }

    fn isTruthy(self: *Interpreter, value: Value) bool {
        _ = self;
        switch (value) {
            .boolean => |b| return b,
            .number, .string, .array, .builtin => return true,
            .nothing => return false,
        }
    }
};
