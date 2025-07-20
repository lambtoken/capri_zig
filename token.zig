const std = @import("std");
const bump = @import("./bump.zig");
const Error = @import("error.zig");

pub const TokenType = enum {
    nothing,
    bool,
    int,
    float,
    word,
    string,
    mut,
    fun,
    struct_,
    assign,
    plus,
    minus,
    divide,
    multiply,
    modulus,
    left_paren,
    right_paren,
    left_curly,
    right_curly,
    comma,
    quotes,
    d_quotes,
    if_,
    not,
    and_,
    or_,
    lt,
    gt,
    le,
    ge,
    eq,
    ne,
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

pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

pub fn printTokens(tokens: []Token) void {
    for (tokens) |token| {
        if (token.ttype == TokenType.eof) break;
        std.debug.print("{s} : {s}\n", .{ @tagName(token.ttype), token.value });
    }
}

const keywords_lookup = .{
    .{ "nothing", TokenType.nothing },
    .{ "true", TokenType.bool },
    .{ "false", TokenType.bool },
    .{ "mut", TokenType.mut },
    .{ "fun", TokenType.fun },
    .{ "struct", TokenType.struct_ },
    .{ "if", TokenType.if_ },
    .{ "not", TokenType.not },
    .{ "and", TokenType.and_ },
    .{ "or", TokenType.or_ },
    .{ "for", TokenType.for_ },
    .{ "in", TokenType.in_ },
    .{ "return", TokenType.return_ },
};

pub inline fn handleKeyword(buffer: []const u8, i: *usize, tokens: *std.ArrayList(Token)) !void {
    const start = i.*;
    while (i.* < buffer.len and (std.ascii.isAlphanumeric(buffer[i.*]) or buffer[i.*] == '_')) : (i.* += 1) {}
    const value = buffer[start..i.*];
    var ttype = TokenType.word;

    inline for (keywords_lookup) |keyword| {
        if (std.mem.eql(u8, value, keyword[0])) {
            ttype = keyword[1];
            break;
        }
    }

    try tokens.append(Token{ .ttype = ttype, .value = value });
    i.* -= 1;
}

pub fn tokenize(allocator: std.mem.Allocator, buffer: []const u8) ![]Token {
    var tokens = std.ArrayList(Token).init(allocator);
    var i: usize = 0;
    while (i < buffer.len) : (i += 1) {
        const c = buffer[i];
        // this sucks because '....' passes as 2 range ops. should return an error
        if (std.ascii.isDigit(c) or (c == '.' and i + 1 < buffer.len and std.ascii.isDigit(buffer[i + 1]))) {
            const start = i;
            var has_dot = false;
            if (c == '.') {
                has_dot = true;
                i += 1;
            }

            while (i < buffer.len and (std.ascii.isDigit(buffer[i]) or buffer[i] == '.')) : (i += 1) {
                if (buffer[i] == '.') {
                    if (!has_dot) {
                        if (i + 1 < buffer.len and buffer[i + 1] == '.') {
                            break;
                        }
                        has_dot = true;
                    } else {
                        return error.InvalidNumber;
                    }
                }
            }

            const value = buffer[start..i];
            const kind = if (has_dot) TokenType.float else TokenType.int;
            try tokens.append(Token{ .ttype = kind, .value = value });
            i -= 1;
            continue;
        } else if (c == '.' and i + 1 < buffer.len and buffer[i + 1] == '.') {
            try tokens.append(Token{ .ttype = TokenType.range, .value = buffer[i .. i + 2] });
            i += 1;
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
                '"' => {
                    const start = i + 1;
                    var end = start;
                    while (end < buffer.len and buffer[end] != '"') : (end += 1) {}
                    if (end >= buffer.len) return error.UnterminatedString;
                    try tokens.append(Token{ .ttype = TokenType.string, .value = buffer[start..end] });
                    i = end;
                },
                '@' => {
                    const start = i + 1;
                    var end = start;
                    while (end < buffer.len and std.ascii.isAlphanumeric(buffer[end])) : (end += 1) {}
                    const name = buffer[start..end];
                    try tokens.append(Token{ .ttype = TokenType.builtin, .value = name });
                    i = end - 1;
                },
                ',' => try tokens.append(Token{ .ttype = TokenType.comma, .value = buffer[i .. i + 1] }),
                '+' => try tokens.append(Token{ .ttype = TokenType.plus, .value = buffer[i .. i + 1] }),
                '-' => try tokens.append(Token{ .ttype = TokenType.minus, .value = buffer[i .. i + 1] }),
                '*' => try tokens.append(Token{ .ttype = TokenType.multiply, .value = buffer[i .. i + 1] }),
                '/' => {
                    if (i + 1 < buffer.len and buffer[i + 1] == '/') {
                        i += 2;
                        while (i < buffer.len and buffer[i] != '\n') : (i += 1) {}
                    } else {
                        try tokens.append(Token{ .ttype = TokenType.divide, .value = buffer[i .. i + 1] });
                    }
                },
                '%' => try tokens.append(Token{ .ttype = TokenType.modulus, .value = buffer[i .. i + 1] }),
                '(' => try tokens.append(Token{ .ttype = TokenType.left_paren, .value = buffer[i .. i + 1] }),
                ')' => try tokens.append(Token{ .ttype = TokenType.right_paren, .value = buffer[i .. i + 1] }),
                '{' => try tokens.append(Token{ .ttype = TokenType.left_curly, .value = buffer[i .. i + 1] }),
                '}' => try tokens.append(Token{ .ttype = TokenType.right_curly, .value = buffer[i .. i + 1] }),
                '|' => try tokens.append(Token{ .ttype = TokenType.pipe, .value = buffer[i .. i + 1] }),
                '<' => {
                    if (i + 1 < buffer.len and buffer[i + 1] == '=') {
                        try tokens.append(Token{ .ttype = TokenType.le, .value = buffer[i .. i + 2] });
                        i += 1;
                    } else {
                        try tokens.append(Token{ .ttype = TokenType.lt, .value = buffer[i .. i + 1] });
                    }
                },
                '>' => {
                    if (i + 1 < buffer.len and buffer[i + 1] == '=') {
                        try tokens.append(Token{ .ttype = TokenType.ge, .value = buffer[i .. i + 2] });
                        i += 1;
                    } else {
                        try tokens.append(Token{ .ttype = TokenType.gt, .value = buffer[i .. i + 1] });
                    }
                },
                '=' => {
                    if (i + 1 < buffer.len and buffer[i + 1] == '=') {
                        try tokens.append(Token{ .ttype = TokenType.eq, .value = buffer[i .. i + 2] });
                        i += 1;
                    } else {
                        try tokens.append(Token{ .ttype = TokenType.assign, .value = buffer[i .. i + 1] });
                    }
                },
                '!' => {
                    if (i + 1 < buffer.len and buffer[i + 1] == '=') {
                        try tokens.append(Token{ .ttype = TokenType.ne, .value = buffer[i .. i + 2] });
                        i += 1;
                    } else {
                        try tokens.append(Token{ .ttype = TokenType.not, .value = buffer[i .. i + 1] });
                    }
                },

                else => {},
            }
        }
    }
    try tokens.append(Token{ .ttype = TokenType.eof, .value = "" });
    return tokens.toOwnedSlice();
}
