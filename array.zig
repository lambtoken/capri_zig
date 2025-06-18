const std =  @import("std");
const gc = @import("gc.zig");

const Array = struct {
    values: std.ArrayList(gc.Value),

    pub fn init(allocator: std.mem.Allocator) !Array {
        return Array{
            .values = try std.ArrayList(gc.Value).initCapacity(allocator, 16),
        };
    }

    pub fn deinit(self: *Array) void {
        self.values.deinit();
    }

    pub fn append(self: *Array, value: gc.Value) !void {
        try self.values.append(value);
    }

    pub fn len(self: *Array) usize {
        return self.values.items.len;
    }

    pub fn at(self: *Array, index: usize) gc.Value {
        return self.values.items[index];
    }
};

test "Array" {
    const allocator = std.testing.allocator;
    var array: Array = undefined;

    array = try Array.init(allocator);
    try std.testing.expectEqual(0, array.len());
    defer array.deinit();

    try array.append(gc.Value{ .data = .{ .number = 42 }, .is_mutable = false });
    try std.testing.expectEqual(1, array.len());
    try std.testing.expect(std.meta.eql(gc.Value{ .data = .{ .number = 42 }, .is_mutable = false }, array.at(0)));

    try array.append(gc.Value{ .data = .{ .number = 100 }, .is_mutable = false });
    try std.testing.expectEqual(2, array.len());
    try std.testing.expect(std.meta.eql(gc.Value{ .data = .{ .number = 100 }, .is_mutable = false }, array.at(1)));
}