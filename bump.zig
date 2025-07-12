const std = @import("std");

pub const Bump = struct {
    allocator: std.mem.Allocator,
    memory: []u8,
    capacity: usize,
    canGrow: bool,
    used: usize,
};

// caller must free the memory
pub fn newBump(allocator: std.mem.Allocator, initialCapacity: usize, canGrow: bool) !*Bump {
    const mem = try allocator.alloc(u8, initialCapacity);
    
    const b = try allocator.create(Bump);

    b.* = .{
        .allocator = allocator,
        .memory = mem,
        .capacity = initialCapacity,
        .canGrow = canGrow,
        .used = 0
    };

    return b;
}

pub fn freeBump(b: *Bump) void {
    if (b.memory.len != 0) {
        b.allocator.free(b.memory);
    }
    b.allocator.destroy(b);
}

pub fn alloc(b: *Bump, comptime T: type, count: usize) ![]T {
    const alignment: usize = @as(usize, @alignOf(T));
    const size: usize = count * @sizeOf(T);

    const alignment_start = std.mem.alignForward(usize, b.used, alignment);
    const alignment_end = alignment_start + size;

    if (alignment_end > b.capacity) {
        if (!b.canGrow) return error.OutOfMemory;
        try growBump(b, b.capacity * 2);
    }

    b.used = alignment_end;
    const memory_slice = b.memory[alignment_start..alignment_end];

    const ptr: [*]T =  @ptrCast(@alignCast(memory_slice));
    return ptr[0..count];
}

// fn allocAligned(b: *Bump, comptime T: type, size: usize) ![]T {
//     const bytes = size * @sizeOf(T);
//     const raw = try alloc(b, T, bytes);
//     return @ptrCast(raw.ptr);
// }

fn growBump(b: *Bump, newCapacity: usize) !void {
    if (!b.canGrow) return error.OutOfMemory;
    if (newCapacity <= b.capacity) return;

    const newMemory = try b.allocator.alloc(u8, newCapacity);
    @memcpy(newMemory[0..b.used], b.memory[0..b.used]);
    b.allocator.free(b.memory);
    b.memory = newMemory;
    b.capacity = newCapacity;
}

pub inline fn create(b: *Bump, comptime T: type) !*T {
    const slice = try alloc(b, T, 1);
    return &slice[0];
}

pub fn copy_slice(b: *Bump, slice: []const u8) ![]u8 {
    const mem = try alloc(b, u8, slice.len);
    @memcpy(mem, slice);
    return mem;
}

//test example
test "bump allocator" {
    const allocator = std.testing.allocator;
    var b = try newBump(allocator, 48, true);
    defer freeBump(b);

    const data1 = try alloc(b, u8, 32);
    @memset(data1, 0xAA);
    try std.testing.expectEqualSlices(u8, b.memory[0..32], data1);
    
    const data2 = try alloc(b, u8, 16);
    @memset(data2, 0xBB);
    try std.testing.expectEqualSlices(u8, b.memory[32..48], data2);
}

// // The bump allocator can grow, so we can allocate more than the initial capacity
test "bump allocator grows" {
    const allocator = std.testing.allocator;
    var b = try newBump(allocator, 64, true);
    defer freeBump(b);

    const data1 = try alloc(b, u8, 64);
    @memset(data1, 0xCC);
    try std.testing.expectEqualSlices(
        u8, b.memory[0..64], data1
    );
    
    const data2 = try alloc(b, u8, 64);
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

test "slice copy" {
    const allocator = std.testing.allocator;
    const b = try newBump(allocator, 32, true);
    defer freeBump(b);

    const slice = "HEYO!";
    const copied = try copy_slice(b, slice);

    try std.testing.expectEqualSlices(u8, slice, copied);
}