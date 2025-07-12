const std = @import("std");
const token = @import("token.zig");
const bump = @import("bump.zig");

pub fn main() !void {
    const bump_allocator = bump.init(std.heap.page_allocator);
    defer bump_allocator.freeBump(bump_allocator);

    const allocator = std.heap.page_allocator;
    var args = std.process.args();
    defer args.deinit();

    _ = args.next(); // skip program name
    const script = args.next() orelse {
        std.debug.print("Usage: capri <script>\n", .{});
        return error.InvalidArgs;
    };

    const text = try token.readFile(allocator, script);
    defer allocator.free(text);

    // TODO: Tokenize and interpret
    // let tokens = token.tokenize(text, allocator);
    // token.printTokens(tokens);
}
