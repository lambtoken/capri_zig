const std = @import("std");
const token = @import("./token.zig");

test "tokenize simple int and word" {
    const allocator = std.testing.allocator;
    const input = "123 abc";
    const tokens = try token.tokenize(allocator, input);
    defer allocator.free(tokens);
    try std.testing.expectEqual(token.TokenType.int, tokens[0].ttype);
    try std.testing.expectEqualStrings("123", tokens[0].value);
    try std.testing.expectEqual(token.TokenType.word, tokens[1].ttype);
    try std.testing.expectEqualStrings("abc", tokens[1].value);
    try std.testing.expectEqual(token.TokenType.eof, tokens[2].ttype);
}

test "tokenize keywords and symbols" {
    const allocator = std.testing.allocator;
    const input = "fun if for + - * / =";
    const tokens = try token.tokenize(allocator, input);
    defer allocator.free(tokens);
    try std.testing.expectEqual(token.TokenType.fun, tokens[0].ttype);
    try std.testing.expectEqual(token.TokenType.if_, tokens[1].ttype);
    try std.testing.expectEqual(token.TokenType.for_, tokens[2].ttype);
    try std.testing.expectEqual(token.TokenType.plus, tokens[3].ttype);
    try std.testing.expectEqual(token.TokenType.minus, tokens[4].ttype);
    try std.testing.expectEqual(token.TokenType.multiply, tokens[5].ttype);
    try std.testing.expectEqual(token.TokenType.divide, tokens[6].ttype);
    try std.testing.expectEqual(token.TokenType.assign, tokens[7].ttype);
    try std.testing.expectEqual(token.TokenType.eof, tokens[8].ttype);
}

test "tokenize string literal" {
    const allocator = std.testing.allocator;
    const input = "'hello'";
    const tokens = try token.tokenize(allocator, input);
    defer allocator.free(tokens);
    try std.testing.expectEqual(token.TokenType.string, tokens[0].ttype);
    try std.testing.expectEqualStrings("hello", tokens[0].value);
    try std.testing.expectEqual(token.TokenType.eof, tokens[1].ttype);
}

test "var declaration" {
    const allocator = std.testing.allocator;
    const input = "var x = 42";
    const tokens = try token.tokenize(allocator, input);
    defer allocator.free(tokens);
    try std.testing.expectEqual(token.TokenType.word, tokens[0].ttype);
    try std.testing.expectEqualStrings("x", tokens[1].value);
    try std.testing.expectEqual(token.TokenType.assign, tokens[2].ttype);
    try std.testing.expectEqual(token.TokenType.int, tokens[3].ttype);
    try std.testing.expectEqualStrings("42", tokens[3].value);
    try std.testing.expectEqual(token.TokenType.eof, tokens[4].ttype);
}

test "floats" {
    const allocator = std.testing.allocator;
    const input = "3.14 2.71828 .0001";
    const tokens = try token.tokenize(allocator, input);
    defer allocator.free(tokens);

    try std.testing.expectEqual(4, tokens.len);

    try std.testing.expectEqual(token.TokenType.float, tokens[0].ttype);
    try std.testing.expectEqualStrings("3.14", tokens[0].value);
    try std.testing.expectEqual(token.TokenType.float, tokens[1].ttype);
    try std.testing.expectEqualStrings("2.71828", tokens[1].value);
    try std.testing.expectEqual(token.TokenType.float, tokens[2].ttype);
    try std.testing.expectEqualStrings(".0001", tokens[2].value);
    try std.testing.expectEqual(token.TokenType.eof, tokens[3].ttype);
}

test "tokenize range" {
    const allocator = std.testing.allocator;
    const input = "1..10";
    const tokens = try token.tokenize(allocator, input);
    defer allocator.free(tokens);
    
    try std.testing.expectEqual(4, tokens.len);
    try std.testing.expectEqual(token.TokenType.int, tokens[0].ttype);
    try std.testing.expectEqualStrings("1", tokens[0].value);
    try std.testing.expectEqual(token.TokenType.range, tokens[1].ttype);
    try std.testing.expectEqualStrings("..", tokens[1].value);
    try std.testing.expectEqual(token.TokenType.int, tokens[2].ttype);
    try std.testing.expectEqualStrings("10", tokens[2].value);
}

test "tokenize comment" {
    const allocator = std.testing.allocator;
    const input = "// This is a comment\nvar x = 42";
    const tokens = try token.tokenize(allocator, input);
    defer allocator.free(tokens);

    try std.testing.expectEqual(5, tokens.len);
    try std.testing.expectEqual(token.TokenType.word, tokens[0].ttype);
    try std.testing.expectEqualStrings("x", tokens[1].value);
    try std.testing.expectEqual(token.TokenType.assign, tokens[2].ttype);
    try std.testing.expectEqual(token.TokenType.int, tokens[3].ttype);
    try std.testing.expectEqualStrings("42", tokens[3].value);
    try std.testing.expectEqual(token.TokenType.eof, tokens[4].ttype);
}

test "tokenize not and or" {
    const allocator = std.testing.allocator;
    const input = "not true and false or maybe";
    const tokens = try token.tokenize(allocator, input);
    defer allocator.free(tokens);

    try std.testing.expectEqual(7, tokens.len);
    try std.testing.expectEqualStrings("not", tokens[0].value);
    try std.testing.expectEqual(token.TokenType.not, tokens[0].ttype);
    try std.testing.expectEqualStrings("and", tokens[2].value);
    try std.testing.expectEqual(token.TokenType.and_, tokens[2].ttype);
    try std.testing.expectEqualStrings("or", tokens[4].value);
    try std.testing.expectEqual(token.TokenType.or_, tokens[4].ttype);
}