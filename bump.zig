const std = @import("std");

pub const Bump = struct {
    allocator: std.mem.Allocator,
    chunks: std.ArrayList([]u8),
    init_chunk_size: usize,
    current_chunk_size: usize,
    current_chunk: usize,
    used: usize,
};

pub fn newBump(allocator: std.mem.Allocator, chunk_size: usize) !*Bump {
    var chunks = std.ArrayList([]u8).init(allocator);
    const first_chunk = try allocator.alloc(u8, chunk_size);
    try chunks.append(first_chunk);

    const b = try allocator.create(Bump);
    b.* = .{
        .allocator = allocator,
        .chunks = chunks,
        .init_chunk_size = chunk_size,
        .current_chunk_size = chunk_size,
        .current_chunk = 0,
        .used = 0,
    };
    return b;
}

pub fn freeBump(b: *Bump) void {
    for (b.chunks.items) |chunk| {
        b.allocator.free(chunk);
    }
    b.chunks.deinit();
    b.allocator.destroy(b);
}

pub fn alloc(b: *Bump, comptime T: type, count: usize) ![]T {
    const alignment = @alignOf(T);
    const size = count * @sizeOf(T);

    const alignment_start = std.mem.alignForward(usize, b.used, alignment);
    const alignment_end = alignment_start + size;

    if (alignment_end > b.current_chunk_size) {
        const chunk_size = if (size > b.init_chunk_size) size else b.init_chunk_size;
        const new_chunk = try b.allocator.alloc(u8, chunk_size);
        try b.chunks.append(new_chunk);
        b.current_chunk = b.chunks.items.len - 1;
        b.current_chunk_size = chunk_size;
        b.used = 0;
        return alloc(b, T, count);
    }

    if (alignment_end > b.current_chunk_size - b.used) {
        const new_chunk = try b.allocator.alloc(u8, b.init_chunk_size);
        try b.chunks.append(new_chunk);
        b.current_chunk = b.chunks.items.len - 1;
        b.used = 0;
        return alloc(b, T, count);
    }

    const current_chunk = b.chunks.items[b.current_chunk];
    const memory_slice = current_chunk[alignment_start..alignment_end];
    b.used = alignment_end;

    const ptr: [*]T = @ptrCast(@alignCast(memory_slice));

    if (@intFromPtr(ptr) % alignment != 0) unreachable;
    return ptr[0..count];
}

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

// test example
test "bump allocator" {
    const allocator = std.testing.allocator;
    var b = try newBump(allocator, 48);
    defer freeBump(b);

    const data1 = try alloc(b, u8, 32);
    @memset(data1, 0xAA);

    const data2 = try alloc(b, u8, 16);
    @memset(data2, 0xBB);

    try std.testing.expectEqualSlices(u8, b.chunks.items[0][0..32], data1);
    try std.testing.expectEqualSlices(u8, b.chunks.items[1][0..16], data2);
}

// The bump allocator can grow, so we can allocate more than the initial capacity
test "bump allocator grows" {
    const allocator = std.testing.allocator;
    var b = try newBump(allocator, 64);
    defer freeBump(b);

    const data1 = try alloc(b, u8, 64);
    @memset(data1, 0xCC);
    try std.testing.expectEqualSlices(u8, b.chunks.items[0][0..64], data1);

    const data2 = try alloc(b, u8, 64);
    @memset(data2, 0xDD);
    try std.testing.expectEqualSlices(u8, b.chunks.items[1][0..64], data2);
}

test "struct creation" {
    const allocator = std.testing.allocator;
    const b = try newBump(allocator, 32);
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
    const b = try newBump(allocator, 32);
    defer freeBump(b);

    const slice = "HEYO!";
    const copied = try copy_slice(b, slice);

    try std.testing.expectEqualSlices(u8, slice, copied);
}

test "large allocation" {
    const allocator = std.testing.allocator;
    var b = try newBump(allocator, 64);
    defer freeBump(b);

    const large_data = try alloc(b, u8, 100); // 10MB
    @memset(large_data, 0xEE);
    try std.testing.expectEqual(b.chunks.items.len, 2);
    try std.testing.expectEqual(b.used, 100);
    try std.testing.expectEqualSlices(u8, b.chunks.items[1][0..100], large_data);
}
