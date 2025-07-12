const std = @import("std");
const parse = @import("parse.zig");

pub fn print(value: *parse.ASTNode) void {
    switch (value.*) {
        .string => std.debug.print("{s}\n", .{ value.string }),
        .number => std.debug.print("{d}\n", .{ value.number }),
        else => std.debug.print("Not implemented!\n", .{})
    }
}

test "print string" {
    var hello: parse.ASTNode = .{ .string = "ASDASDD" };
    print(&hello);

    // need to learn how to verify stdout
}

test "print number" {
    var _123: parse.ASTNode = .{ .number = 123 };
    print(&_123);

    // need to learn how to verify stdout
}