const std = @import("std");
const Value = @import("interpreter.zig").Value;
const Array = @import("array.zig").Array;

pub const EnvEntry = struct {
    value: *Value,
    is_mutable: bool,
    reachable: bool,
};

const SetResult = enum {
    NotFound,
    Inserted,
    Updated,
};

pub const Environment = struct {
    locals: std.StringHashMap(*EnvEntry),
    references: std.ArrayList(*EnvEntry),
    parent: ?*Environment,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Environment {
        return Environment{
            .locals = std.StringHashMap(*EnvEntry).init(allocator),
            .references = std.ArrayList(*EnvEntry).init(allocator),
            .parent = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Environment) void {
        for (self.references.items) |entry| {
            self.freeEntry(entry);
        }

        self.locals.deinit();
        self.references.deinit();
    }

    pub fn get(self: *Environment, name: []const u8) ?*EnvEntry {
        if (self.locals.get(name)) |entry| {
            return entry;
        }
        if (self.parent) |parent| {
            return parent.get(name);
        }
        return null;
    }

    pub fn set(self: *Environment, name: []const u8, value: Value) !SetResult {
        if (self.locals.get(name)) |existing_entry| {
            existing_entry.value.* = value;
            return .Updated;
        }

        if (self.parent) |parent| {
            const result = try parent.set(name, value);

            switch (result) {
                .NotFound => {},
                .Inserted => return .Inserted,
                .Updated => return .Updated,
            }
        }

        const entry = try self.allocateValue(value);
        try self.locals.put(name, entry);
        try self.references.append(entry);
        return .Inserted;
    }

    fn markEntry(self: *Environment, entry: *EnvEntry, mark_bool: bool) void {
        entry.reachable = mark_bool;

        switch (entry.value.*) {
            .array => |array| {
                for (array.values.items) |array_entry| {
                    self.markEntry(array_entry, mark_bool);
                }
            },
            else => {},
        }
    }

    pub fn mark(self: *Environment) void {
        for (self.references.items) |entry| {
            self.markEntry(entry, false);
        }

        var iterator = self.locals.iterator();

        while (iterator.next()) |entry| {
            self.markEntry(entry.value_ptr.*, true);
        }
    }

    pub fn sweep(self: *Environment) void {
        var i: usize = 0;
        while (i < self.references.items.len) {
            const entry = self.references.items[i];
            if (!entry.reachable) {
                self.freeEntry(entry);
                _ = self.references.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    fn allocateValue(self: *Environment, value: Value) !*EnvEntry {
        const val = self.allocator.create(Value) catch return error.OutOfMemory;
        val.* = value;

        // make sure strings are allocated correctly
        switch (value) {
            .string => |str| {
                val.string = try self.allocator.dupe(u8, str);
            },
            else => {},
        }

        const entry = self.allocator.create(EnvEntry) catch return error.OutOfMemory;
        entry.* = EnvEntry{
            .value = val,
            .is_mutable = true,
            .reachable = true,
        };
        return entry;
    }

    fn freeEntry(self: *Environment, entry: *EnvEntry) void {
        switch (entry.value.*) {
            .string => |str| {
                self.allocator.free(str);
            },
            else => {},
        }

        self.allocator.destroy(entry.value);
        self.allocator.destroy(entry);
    }
};

test "environment" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator);
    defer env.deinit();

    try env.set("x", Value{ .number = 42 });
    try std.testing.expectEqual(Value{ .number = 42 }, env.get("x").?.value.*);
}

test "environment strings" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator);
    defer env.deinit();

    try env.set("x", Value{ .string = "hello" });
    try std.testing.expectEqualStrings("hello", env.get("x").?.value.*.string);
}

test "environment mark and sweep" {
    const allocator = std.testing.allocator;
    var env = Environment.init(allocator);
    defer env.deinit();

    try env.set("x", Value{ .number = 42 });
    try std.testing.expectEqual(Value{ .number = 42 }, env.get("x").?.value.*);

    try env.set("x", Value{ .number = 43 });

    env.mark();
    env.sweep();

    // refs length should be 1
    try std.testing.expectEqual(1, env.references.items.len);

    // locals length should be 1
    try std.testing.expectEqual(1, env.locals.count());

    try std.testing.expectEqual(Value{ .number = 43 }, env.get("x").?.value.*);
}

// test "environment mark and sweep with array" {
//     const allocator = std.testing.allocator;
//     var env = Environment.init(allocator);
//     defer env.deinit();

//     var array = try Array.init(allocator);
//     defer array.deinit();

//     try array.append(try env.allocateValue(Value{ .number = 42 }));
//     try array.append(try env.allocateValue(Value{ .number = 69 }));

//     try env.set("x", Value{ .array = &array });

//     env.mark();
//     env.sweep();

//     try std.testing.expectEqual(1, env.references.items.len);
//     try std.testing.expectEqual(1, env.locals.count());
// }
