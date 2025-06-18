const std = @import("std");

const bump = struct {
    allocator: std.mem.Allocator,
    memory: []u8,
    capacity: usize,
    canGrow: bool,
    used: usize,
};

// caller must free the memory
pub fn newBump(allocator: std.mem.Allocator, initialCapacity: usize, canGrow: bool) !*bump {
    const mem = try allocator.alloc(u8, initialCapacity);
    
    const b = try allocator.create(bump);

    b.* = .{
        .allocator = allocator,
        .memory = mem,
        .capacity = initialCapacity,
        .canGrow = canGrow,
        .used = 0
    };

    return b;
}

pub fn freeBump(b: *bump) void {
    if (b.memory.len != 0) {
        b.allocator.free(b.memory);
    }
    b.allocator.destroy(b);
}

pub fn alloc(b: *bump, size: usize) ![]u8 {
    if (b.used + size > b.capacity) {
        if (!b.canGrow) return error.OutOfMemory;
        try growBump(b, b.capacity * 2);
    }
    b.used += size;
    return b.memory[b.used - size..b.used];
}

pub fn growBump(b: *bump, newCapacity: usize) !void {
    if (!b.canGrow) return error.OutOfMemory;
    if (newCapacity <= b.capacity) return;

    const newMemory = try b.allocator.alloc(u8, newCapacity);
    @memcpy(newMemory[0..b.used], b.memory[0..b.used]);
    b.allocator.free(b.memory);
    b.memory = newMemory;
    b.capacity = newCapacity;
}

pub fn create(b: *bump, comptime T: type) !*T {
    const mem = try alloc(b, @sizeOf(T));
    const ptr: *T = @alignCast(@ptrCast(mem.ptr));
    return ptr;
}

//test example
test "bump allocator" {
    const allocator = std.testing.allocator;
    var b = try newBump(allocator, 48, true);
    defer freeBump(b);

    const data1 = try alloc(b, 32);
    @memset(data1, 0xAA);
    try std.testing.expectEqualSlices(u8, b.memory[0..32], data1);
    
    const data2 = try alloc(b, 16);
    @memset(data2, 0xBB);
    try std.testing.expectEqualSlices(u8, b.memory[32..48], data2);
}

// // The bump allocator can grow, so we can allocate more than the initial capacity
test "bump allocator grows" {
    const allocator = std.testing.allocator;
    var b = try newBump(allocator, 64, true);
    defer freeBump(b);

    const data1 = try alloc(b, 64);
    @memset(data1, 0xCC);
    try std.testing.expectEqualSlices(
        u8, b.memory[0..64], data1
    );
    
    const data2 = try alloc(b, 64);
    @memset(data2, 0xDD);
    try std.testing.expectEqualSlices(u8, b.memory[64..128], data2);
}

test "struct creation" {
    const allocator = std.testing.allocator;
    const b = try newBump(allocator, 32, true);
    defer freeBump(b);

    const MyStruct = struct {
        a: u32,
        b: u8,
    };

    var s = try create(b, MyStruct);
    s.a = 1234;
    s.b = 42;

    try std.testing.expectEqual(1234, s.a);
    try std.testing.expectEqual(42, s.b);
}