const std = @import("std");
const token = @import("token.zig");
const parse = @import("parse.zig");
const interpreter = @import("interpreter.zig");
const bump = @import("bump.zig");

pub fn main() !void {
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

    // Tokenize
    const tokens = try token.tokenize(allocator, text);
    defer allocator.free(tokens);

    // for (tokens) |tok| {
    //     std.debug.print("{s}: {s}\n", .{ @tagName(tok.ttype), tok.value });
    // }

    // Create bump allocator for AST nodes
    const _bump = try bump.newBump(
        allocator,
        1024,
    );
    defer bump.freeBump(_bump);

    // Parse
    var parser = parse.Parser.init(_bump, tokens);
    const ast = try parser.parseProgram();

    // Interpret
    const interp = try interpreter.Interpreter.init(allocator);
    defer interp.deinit();

    _ = try interp.evaluate(ast);
}
