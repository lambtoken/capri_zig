const std = @import("std");
const bump = @import("./bump.zig");

pub const TokenType = enum {
    nope,
    bool,
    int,
    float,
    word,
    string,
    mut,
    fun,
    assign,
    plus,
    minus,
    divide,
    multiply,
    left_paren,
    right_paren,
    left_curly,
    right_curly,
    comma,
    quotes,
    d_quotes,
    if_,
    for_,
    in_,
    range,
    builtin,
    pipe,
    return_,
    eof,
};

pub const Token = struct {
    ttype: TokenType,
    value: []const u8,
    line: usize = 0,
    column: usize = 0,
};

// pub fn readFile(path: []const u8, buffer: []u8) ![]u8 {
//     var file = try std.fs.cwd().openFile(path, .{});
//     defer file.close();
//     var size =  try file.getEndPos();
//     const buffer = try bump.alloc(allocator, size);
//     return try file.readAll(buffer);
//     return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
// }

pub fn printTokens(tokens: []Token) void {
    for (tokens) |token| {
        if (token.ttype == TokenType.eof) break;
        std.debug.print("{s} : {s}\n", .{ @tagName(token.ttype), token.value });
    }
}

pub inline fn handleKeyword(buffer: []const u8, i: *usize, tokens: *std.ArrayList(Token)) !void {
    const start = i.*;
    while (i.* < buffer.len and std.ascii.isAlphanumeric(buffer[i.*])) : (i.* += 1) {}
    const value = buffer[start..i.*];
    var ttype = TokenType.word;
    if (std.mem.eql(u8, value, "nope")) {
        ttype = TokenType.nope;
    } else if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "false")) {
        ttype = TokenType.bool;
    } else if (std.mem.eql(u8, value, "mut")) {
        ttype = TokenType.mut;
    } else if (std.mem.eql(u8, value, "fun")) {
        ttype = TokenType.fun;
    } else if (std.mem.eql(u8, value, "if")) {
        ttype = TokenType.if_;
    } else if (std.mem.eql(u8, value, "for")) {
        ttype = TokenType.for_;
    } else if (std.mem.eql(u8, value, "in")) {
        ttype = TokenType.in_;
    } else if (std.mem.eql(u8, value, "return")) {
        ttype = TokenType.return_;
    } else {
        ttype = TokenType.word;
    }

    try tokens.append(Token{ .ttype = ttype, .value = value });
    i.* -= 1;
}

pub fn tokenize(allocator: std.mem.Allocator, buffer: []const u8) ![]Token {
    var tokens = std.ArrayList(Token).init(allocator);
    var i: usize = 0;
    while (i < buffer.len) : (i += 1) {
        const c = buffer[i];
        // Handle range operator before float/int
        if (c == '.' and i + 1 < buffer.len and buffer[i + 1] == '.') {
            try tokens.append(Token{ .ttype = TokenType.range, .value = buffer[i..i+2] });
            i += 1;
            continue;
        } else if (std.ascii.isDigit(c) or (c == '.' and i + 1 < buffer.len and buffer[i + 1] != '.' and std.ascii.isDigit(buffer[i + 1]))) {
            const start = i;
            var has_dot = false;
            if (c == '.') {
                has_dot = true;
                i += 1;
            }
            while (i < buffer.len and (std.ascii.isDigit(buffer[i]) or (buffer[i] == '.' and !has_dot and (i + 1 >= buffer.len or buffer[i + 1] != '.')))) : (i += 1) {
                if (buffer[i] == '.') {
                    has_dot = true;
                }
            }
            const value = buffer[start..i];
            const kind = if (has_dot) TokenType.float else TokenType.int;
            try tokens.append(Token{ .ttype = kind, .value = value });
            i -= 1;
            continue;
        } else if (std.ascii.isAlphabetic(c)) {
            handleKeyword(buffer, &i, &tokens) catch |err| {
                return err;
            };
            continue;
        } else if (std.ascii.isWhitespace(c)) {
            continue;
        } else {
            switch (c) {
                '\'' => {
                    const start = i + 1;
                    var end = start;
                    while (end < buffer.len and buffer[end] != '\'') : (end += 1) {}
                    if (end >= buffer.len) return error.UnterminatedString;
                    try tokens.append(Token{ .ttype = TokenType.string, .value = buffer[start..end] });
                    i = end;
                },
                '@' => try tokens.append(Token{ .ttype = TokenType.builtin, .value = buffer[i..i+1] }),
                ',' => try tokens.append(Token{ .ttype = TokenType.comma, .value = buffer[i..i+1] }),
                '+' => try tokens.append(Token{ .ttype = TokenType.plus, .value = buffer[i..i+1] }),
                '-' => try tokens.append(Token{ .ttype = TokenType.minus, .value = buffer[i..i+1] }),
                '*' => try tokens.append(Token{ .ttype = TokenType.multiply, .value = buffer[i..i+1] }),
                '/' => {
                    if (i + 1 < buffer.len and buffer[i + 1] == '/') {
                        i += 2;
                        while (i < buffer.len and buffer[i] != '\n') : (i += 1) {}
                    } else {
                        try tokens.append(Token{ .ttype = TokenType.divide, .value = buffer[i..i+1] });
                    }
                },
                '(' => try tokens.append(Token{ .ttype = TokenType.left_paren, .value = buffer[i..i+1] }),
                ')' => try tokens.append(Token{ .ttype = TokenType.right_paren, .value = buffer[i..i+1] }),
                '{' => try tokens.append(Token{ .ttype = TokenType.left_curly, .value = buffer[i..i+1] }),
                '}' => try tokens.append(Token{ .ttype = TokenType.right_curly, .value = buffer[i..i+1] }),
                '=' => try tokens.append(Token{ .ttype = TokenType.assign, .value = buffer[i..i+1] }),
                '|' => try tokens.append(Token{ .ttype = TokenType.pipe, .value = buffer[i..i+1] }),
                '.' => {
                    if (i + 1 < buffer.len and buffer[i + 1] == '.') {
                        std.debug.print("we should be here\n", .{});
                        try tokens.append(Token{ .ttype = TokenType.range, .value = buffer[i..i+2] });
                        i += 1;
                    }
                },
                else => {},
            }
        }
    }
    try tokens.append(Token{ .ttype = TokenType.eof, .value = "" });
    return tokens.toOwnedSlice();
}