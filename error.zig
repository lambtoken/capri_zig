const std =  @import("std");
const token = @import("token.zig");

pub fn printError(source: []const u8, tk: token.Token, err: anyerror, ahead: bool) !void {
    var lines = std.mem.splitAny(u8, source, "\n");

    std.debug.print("Error at line {d}, column {d}: {any}\n", .{
        tk.line,
        tk.column,
        err,
    });

    var i: usize = 0;
    while (lines.next()) |line| {
        if (i == tk.line) {
            std.debug.print(" {d} | {s}\n", .{i, line});
            break;
        }
        i += 1;
    }

    // get the length of the line number
    var x = i + 1;
    var ln_len: u32 = 1;
    while (x >= 10) : (x /= 10) {
        ln_len += 1;
    }

    const ln_margin = try std.heap.page_allocator.alloc(u8, ln_len + 4);
    @memset(ln_margin, ' ');
    errdefer std.heap.page_allocator.free(ln_margin);
    defer std.heap.page_allocator.free(ln_margin);

    const highlight_pos = if (ahead) tk.column + tk.value.len else tk.column;
    const highlight_len = if (ahead) 1 else tk.value.len;

    var buf: [256]u8 = undefined;
    @memset(buf[0..highlight_pos], ' ');
    @memset(buf[highlight_pos..highlight_pos + highlight_len], '^');
    std.debug.print("{s}{s}\n", .{ln_margin, buf[0..highlight_pos + highlight_len]});
}

test "unexpected token error" {
    const source = "mut x = 5\ny = 10\nreturn x + y";
    const tk = token.Token{
        .ttype = token.TokenType.int,
        .value = "x",
        .line = 0,
        .column = 4,
    };
    const err: anyerror = error.UnexpectedToken;
    
    try printError(source, tk, err, false);
}

test "unexpected long token error" {
    const source = "mut x = 5\ny  = 10\nreturn x + y\nbanana @print(1 + 1)\n";
    const tk = token.Token{
        .ttype = token.TokenType.word,
        .value = "banana",
        .line =  3,
        .column =   0,
    };
    const err: anyerror = error.UnexpectedToken;

    try printError(source, tk, err, false);
}

test "expected token error" {
    const source = "if (x > 5\nand y < 10\n";
    const tk = token.Token{
        .ttype = token.TokenType.if_,
        .value = "10",
        .line = 1,
        .column =  8,
    };
    const err: anyerror = error.ExpectedToken;

    try printError(source, tk, err, true);
}