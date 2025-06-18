const std =  @import("std");
const token = @import("./token.zig");

// const ValueType = enum {
//     ENV,
//     VAR,
//     FUN,
// };

const Array = struct {
    values: std.ArrayList(Value),

    pub fn init(allocator: std.mem.Allocator) !Array {
        return Array{
            .values = try std.ArrayList(Value).initCapacity(allocator, 16),
        };
    }

    pub fn deinit(self: *Array) void {
        self.values.deinit();
    }

    pub fn append(self: *Array, value: Value) !void {
        try self.values.append(value);
    }

    pub fn len(self: *Array) usize {
        return self.values.items.len;
    }

    pub fn at(self: *Array, index: usize) Value {
        return self.values.items[index];
    }
};

pub const Env = struct {
    parent: ?*Env,
    variables: std.StringHashMap(Value) = undefined,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, parent: ?*Env) !Env {
        const map = std.StringHashMap(Value).init(allocator);
        return Env{
            .parent = parent,
            .variables = map,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Env) void {
        var it = self.variables.iterator();
        while (it.next()) |entry| {
            switch (entry.value_ptr.data) {
                .string => |s| self.allocator.free(s),
                else => {},
            }
            self.allocator.free(entry.key_ptr.*);
        }
        self.variables.deinit();
    }

    pub fn get(self: *Env, key: []const u8) ?Value {
        if (self.variables.get(key)) |value| {
            return value;
        } else if (self.parent) |parent| {
            return parent.get(key);
        }
        return null;
    }

    pub fn set(self: *Env, key: []const u8, value: Value) !void {
        // First check if the variable exists in current scope
        if (self.variables.get(key)) |existing| {
            if (!existing.is_mutable) {
                return error.CannotAssignToImmutable;
            }
        }

        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);

        var owned_value = value;
        switch (value.data) {
            .string => {
                owned_value.data.string = try self.allocator.dupe(u8, value.data.string);
                errdefer self.allocator.free(owned_value.data.string);
            },
            else => {},
        }

        try self.variables.put(owned_key, owned_value);
    }
};

pub const Value = struct {
    data: union(enum) {
        number: f64,
        boolean: bool,
        string: []const u8,
        // ... other types
    },
    is_mutable: bool,

    pub fn init(data: anytype, is_mutable: bool) Value {
        return .{
            .data = data,
            .is_mutable = is_mutable,
        };
    }
};

const Binding = struct {
    identifier: []const u8,
    value: Value,
};

const GC = struct {
    allocator: std.mem.Allocator,

    children: std.ArrayList(*GC) = undefined,

    pub fn deinit(self: *GC) void {
        self.bump.deinit();
    }
};

// test "env test" {
//     const allocator = std.testing.allocator;
//     var env = try Env.init(allocator, null);
//     defer env.deinit();

//     try env.set("x", Value{ .number = 42 });
//     try env.set("y", Value{ .boolean = true });

//     const x_value = env.get("x");
//     const y_value = env.get("y");
//     const z_value = env.get("z");

//     try std.testing.expect(x_value.?.number == 42);
//     try std.testing.expect(y_value.?.boolean == true);
//     try std.testing.expect(z_value == null);
// }

// test "nested env test" {
//     const allocator = std.testing.allocator;
//     var parent_env = try Env.init(allocator, null);
//     defer parent_env.deinit();

//     try parent_env.set("x", Value{ .number = 42 });

//     var child_env = try Env.init(allocator, &parent_env);
//     defer child_env.deinit();

//     const x_value = child_env.get("x");
//     const y_value = child_env.get("y");

//     try std.testing.expect(x_value.?.number == 42);
//     try std.testing.expect(y_value == null);
// }

// test "env strings test" {
//     const allocator = std.testing.allocator;
//     var env = try Env.init(allocator, null);
//     defer env.deinit();

//     try env.set("greeting", Value{ .string = "Hello, World!" });

//     const greeting_value = env.get("greeting");
//     const missing_value = env.get("missing");

//     try std.testing.expect(std.mem.eql(u8, greeting_value.?.string, "Hello, World!"));
//     try std.testing.expect(missing_value == null);
// }

// test "env extremely long string test" {
//     const allocator = std.testing.allocator;
//     var env = try Env.init(allocator, null);
//     defer env.deinit();

//     const long_string = "a" ** 1000; // 1000 'a' characters
//     try env.set("long_string", Value{ .string = long_string });

//     const long_string_value = env.get("long_string");
//     try std.testing.expect(std.mem.eql(u8, long_string_value.?.string, long_string));
// }

test "mutability test" {
    const allocator = std.testing.allocator;
    var env = try Env.init(allocator, null);
    defer env.deinit();

    // Create immutable variable
    try env.set("x", Value{ .data = .{ .number = 42 }, .is_mutable = false });
    
    // Attempt to modify immutable - should fail
    const new_value = Value{ .data = .{ .number = 100 }, .is_mutable = false };
    try std.testing.expectError(
        error.CannotAssignToImmutable,
        env.set("x", new_value)
    );

    // Test that original value remains unchanged
    const x_value = env.get("x").?;
    try std.testing.expectEqual(@as(f64, 42), x_value.data.number);
}