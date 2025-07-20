const std = @import("std");
const parse = @import("parse.zig");
const bump = @import("bump.zig");
const env = @import("env.zig");
const Array = @import("array.zig").Array;
const Builtin = @import("builtin.zig");

pub const Value = union(enum) {
    number: f64,
    boolean: bool,
    string: []const u8,
    array: *Array,
    nothing: void,
    builtin: Builtin.BuiltinType,
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
                    .eq => {
                        if (left == .number and right == .number) {
                            return Value{ .boolean = left.number == right.number };
                        } else {
                            std.debug.print("Error: cannot compare non-numbers\n", .{});
                            return error.TypeError;
                        }
                    },
                    .lt => {
                        if (left == .number and right == .number) {
                            return Value{ .boolean = left.number < right.number };
                        } else {
                            std.debug.print("Error: cannot compare non-numbers\n", .{});
                            return error.TypeError;
                        }
                    },
                    .gt => {
                        if (left == .number and right == .number) {
                            return Value{ .boolean = left.number > right.number };
                        } else {
                            std.debug.print("Error: cannot compare non-numbers\n", .{});
                            return error.TypeError;
                        }
                    },
                    .le => {
                        if (left == .number and right == .number) {
                            return Value{ .boolean = left.number <= right.number };
                        } else {
                            std.debug.print("Error: cannot compare non-numbers\n", .{});
                            return error.TypeError;
                        }
                    },
                    .ge => {
                        if (left == .number and right == .number) {
                            return Value{ .boolean = left.number >= right.number };
                        } else {
                            std.debug.print("Error: cannot compare non-numbers\n", .{});
                            return error.TypeError;
                        }
                    },
                    .ne => {
                        if (left == .number and right == .number) {
                            return Value{ .boolean = left.number != right.number };
                        } else {
                            std.debug.print("Error: cannot compare non-numbers\n", .{});
                            return error.TypeError;
                        }
                    },
                    .and_ => {
                        const l = self.isTruthy(left);
                        const r = self.isTruthy(right);
                        if (l and r) {
                            return Value{ .boolean = true };
                        } else {
                            return Value{ .boolean = false };
                        }
                    },
                    .or_ => {
                        const l = self.isTruthy(left);
                        const r = self.isTruthy(right);
                        if (l or r) {
                            return Value{ .boolean = true };
                        } else {
                            return Value{ .boolean = false };
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
                    // TODO: Do else branching
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
            .while_loop => {
                return try self.evaluateWhileLoop(node);
            },
            .break_ => {
                return error.LoopBreak; // Custom error to indicate loop break
            },
            else => {
                std.debug.print("Error: unsupported node type: {}\n", .{node.*});
                return error.UnsupportedNode;
            },
        };
    }

    fn evaluateBuiltinCall(self: *Interpreter, name: []const u8, args_node: *parse.ASTNode) anyerror!Value {
        const builtin = Builtin.getBuiltin(name) orelse {
            std.debug.print("Error: builtin function not found: {s}\n", .{name});
            return error.BuiltinNotFound;
        };

        if (builtin.variadic) {
            if (args_node.args.len < builtin.args) {
                std.debug.print("Error: builtin function {s} expects at least {d} arguments, got {d}\n", .{ name, builtin.args, args_node.args.len });
                return error.ArgumentCountMismatch;
            }
        } else {
            if (builtin.args != args_node.args.len) {
                std.debug.print("Error: builtin function {s} expects exactly {d} arguments, got {d}\n", .{ name, builtin.args, args_node.args.len });
                return error.ArgumentCountMismatch;
            }
        }

        if (builtin.callback) |callback| {
            return try callback(self, args_node);
        } else {
            std.debug.print("Error: builtin function not found: {s}\n", .{name});
            return error.BuiltinNotFound;
        }
    }

    pub fn evaluatePrint(self: *Interpreter, args_node: *parse.ASTNode, newline: bool) anyerror!Value {
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
        if (newline) {
            std.debug.print("\n", .{});
        }
        return Value{ .nothing = {} }; // This should just be a void function
    }

    pub fn evaluateForLoop(self: *Interpreter, loop_node: *parse.ASTNode) anyerror!Value {
        const range_op = loop_node.*.for_loop.range.op;
        const start_val = try self.evaluate(range_op.left);
        const end_val = try self.evaluate(range_op.right);

        if (start_val != .number or end_val != .number) {
            std.debug.print("Error: loop range must be numbers\n", .{});
            return error.TypeError;
        }

        const start: i64 = @intFromFloat(start_val.number);
        const end: i64 = @intFromFloat(end_val.number);
        const iter_name = loop_node.*.for_loop.iter_name;

        if (start == end) return Value{ .nothing = {} };

        const step: i64 = if (start < end) 1 else -1;

        const new_env = try self.allocator.create(env.Environment);
        new_env.* = env.Environment.init(self.allocator);
        new_env.parent = self.environment;
        defer {
            new_env.deinit();
            self.allocator.destroy(new_env);
        }

        try new_env.set(iter_name, Value{ .number = @floatFromInt(start) });
        const iter_entry = new_env.get(iter_name).?;

        const old_env = self.environment;
        self.environment = new_env;
        defer self.environment = old_env;

        var current = start;
        while (current != end) : (current += step) {
            iter_entry.value.*.number = @floatFromInt(current);

            _ = try self.evaluate(loop_node.for_loop.body);
        }

        return Value{ .nothing = {} };
    }

    pub fn evaluateWhileLoop(self: *Interpreter, loop_node: *parse.ASTNode) anyerror!Value {
        const new_env = try self.allocator.create(env.Environment);
        new_env.* = env.Environment.init(self.allocator);
        new_env.parent = self.environment;
        defer {
            new_env.deinit();
            self.allocator.destroy(new_env);
        }

        const old_env = self.environment;
        self.environment = new_env;
        defer self.environment = old_env;

        while (true) {
            _ = self.evaluate(loop_node.while_loop.body) catch |err| {
                switch (err) {
                    error.LoopBreak => return Value{ .nothing = {} }, // Break out of the loop
                    else => return err, // propagate
                }
            };
        }

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

    inline fn isTruthy(self: *Interpreter, value: Value) bool {
        _ = self;
        switch (value) {
            .boolean => |b| return b,
            .number, .string, .array, .builtin => return true,
            .nothing => return false,
        }
    }
};
