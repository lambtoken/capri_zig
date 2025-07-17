const std = @import("std");
const Value = @import("interpreter.zig").Value;
const env = @import("env.zig");

pub const Array = struct {
    values: std.ArrayList(*env.EnvEntry),

    pub fn init(allocator: std.mem.Allocator) !Array {
        return Array{
            .values = try std.ArrayList(*env.EnvEntry).initCapacity(allocator, 16),
        };
    }

    pub fn deinit(self: *Array) void {
        self.values.deinit();
    }

    pub fn append(self: *Array, value: *env.EnvEntry) !void {
        try self.values.append(value);
    }

    pub fn len(self: *Array) usize {
        return self.values.items.len;
    }

    pub fn at(self: *Array, index: usize) *env.EnvEntry {
        return self.values.items[index];
    }
};

test "Array" {
    const allocator = std.testing.allocator;
    var array: Array = undefined;

    array = try Array.init(allocator);
    try std.testing.expectEqual(0, array.len());
    defer array.deinit();

    try array.append(@constCast(&env.EnvEntry{
        .value = @constCast(&Value{ .number = 42 }),
        .is_mutable = false,
        .reachable = true,
    }));
    try std.testing.expectEqual(1, array.len());

    const entryAt0 = array.at(0);
    try std.testing.expectEqual(42, entryAt0.value.*.number);

    try array.append(@constCast(&env.EnvEntry{
        .value = @constCast(&Value{ .number = 100 }),
        .is_mutable = false,
        .reachable = true,
    }));
    try std.testing.expectEqual(2, array.len());

    const entryAt1 = array.at(1);
    try std.testing.expectEqual(100, entryAt1.value.*.number);
}
