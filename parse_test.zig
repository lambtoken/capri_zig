const std = @import("std");
const token = @import("token.zig");
const parse = @import("parse.zig");
const bump = @import("bump.zig");

// test "parse primary int" {
//     const allocator = std.testing.allocator;

//     const tokens = [_]token.Token{
//         .{ .ttype = token.TokenType.int, .value = "42" },
//         .{ .ttype = token.TokenType.eof, .value = "" },
//     };
//     var parser = parse.Parser.init(allocator, &tokens);
//     defer parser.deinit();

//     const node = try parser.parsePrimary();
//     try std.testing.expect(node != null);
//     try std.testing.expectEqual(@as(f64, 42), node.?.number);
// }

// test "parse primary bool true" {
//     const allocator = std.testing.allocator;
//     const tokens = [_]token.Token{
//         .{ .ttype = token.TokenType.bool, .value = "true" },
//         .{ .ttype = token.TokenType.eof, .value = "" },
//     };
//     var parser = parse.Parser.init(allocator, &tokens);
//     const node = try parser.parsePrimary();
//     try std.testing.expect(node != null);
//     try std.testing.expect(node.?.bool);
// }

// test "parse primary string" {
//     const allocator = std.testing.allocator;

//     const tokens = [_]token.Token{
//         .{ .ttype = token.TokenType.string, .value = "hello" },
//         .{ .ttype = token.TokenType.eof, .value = "" },
//     };
//     var parser = parse.Parser.init(allocator, &tokens);
//     const node = try parser.parsePrimary();
//     try std.testing.expect(node != null);
//     try std.testing.expectEqualStrings("hello", node.?.string);
// }

// test "parse primary identifier" {
//     const allocator = std.testing.allocator;

//     const tokens = [_]token.Token{
//         .{ .ttype = token.TokenType.word, .value = "foo" },
//         .{ .ttype = token.TokenType.eof, .value = "" },
//     };
//     var parser = parse.Parser.init(allocator, &tokens);
//     const node = try parser.parsePrimary();
//     try std.testing.expect(node != null);
//     try std.testing.expectEqualStrings("foo", node.?.identifier);
// }

// test "parse primary nope" {
//     const allocator = std.testing.allocator;

//     const tokens = [_]token.Token{
//         .{ .ttype = token.TokenType.nope, .value = "nope" },
//         .{ .ttype = token.TokenType.eof, .value = "" },
//     };
//     var parser = parse.Parser.init(allocator, &tokens);
//     const node = try parser.parsePrimary();
//     try std.testing.expect(node != null);
//     try std.testing.expect(@as(parse.ASTNodeType, node.?) == .nope);
// }

// test "parse binary expression" {
//     const allocator = std.testing.allocator;
//     const tokens = [_]token.Token{
//         .{ .ttype = token.TokenType.int, .value = "1" },
//         .{ .ttype = token.TokenType.plus, .value = "+" },
//         .{ .ttype = token.TokenType.int, .value = "2" },
//         .{ .ttype = token.TokenType.eof, .value = "" },
//     };
//     var parser = parse.Parser.init(allocator, &tokens);
//     const node = try parser.parseExpr(0);
//     try std.testing.expect(node != null);
//     try std.testing.expect(@as(parse.ASTNodeType, @as(parse.ASTNodeType, node.?.*)) == .op);
//     try std.testing.expect(node.?.*.op.operation == .add);
    
//     const left = node.?.*.op.left;
//     try std.testing.expect(@as(parse.ASTNodeType, left.*) == .number);
//     try std.testing.expectEqual(@as(f64, 1), left.*.number);
    
//     const right = node.?.*.op.right;
//     try std.testing.expect(@as(parse.ASTNodeType, right.*) == .number);
//     try std.testing.expectEqual(@as(f64, 2), right.*.number);
    
//     allocator.destroy(node.?);
//     allocator.destroy(left);
//     allocator.destroy(right);
// }

// test "precedence" {
//     // we use arena here but should use our bump allocator in the future
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     const allocator = arena.allocator();
//     defer arena.deinit();

//     const tokens = [_]token.Token{
//         .{ .ttype = token.TokenType.int, .value = "1" },
//         .{ .ttype = token.TokenType.plus, .value = "+" },
//         .{ .ttype = token.TokenType.int, .value = "2" },
//         .{ .ttype = token.TokenType.multiply, .value = "*" },
//         .{ .ttype = token.TokenType.int, .value = "3" },
//         .{ .ttype = token.TokenType.eof, .value = "" },
//     };

//     var parser = parse.Parser.init(allocator, &tokens);
//     const node = try parser.parseExpr(0);
//     try std.testing.expect(node != null);
//     try std.testing.expect(@as(parse.ASTNodeType, @as(parse.ASTNodeType, node.?.*)) == .op);
//     try std.testing.expect(node.?.*.op.operation == .add);

//     const left = node.?.*.op.left;
//     try std.testing.expect(@as(parse.ASTNodeType, left.*) == .number);
//     try std.testing.expectEqual(@as(f64, 1), left.*.number);

//     const right_op = node.?.*.op.right;
//     try std.testing.expect(@as(parse.ASTNodeType, @as(parse.ASTNodeType, right_op.*)) == .op);
//     try std.testing.expect(right_op.*.op.operation == .mul);

//     const right_left = right_op.*.op.left;
//     try std.testing.expect(@as(parse.ASTNodeType, right_left.*) == .number);
//     try std.testing.expectEqual(@as(f64, 2), right_left.*.number);

//     const right_right = right_op.*.op.right;
//     try std.testing.expect(@as(parse.ASTNodeType, right_right.*) == .number);
//     try std.testing.expectEqual(@as(f64, 3), right_right.*.number);
// }

test "parse variable declaration" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024, true);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.mut, .value = "mut" },
        .{ .ttype = token.TokenType.word, .value = "x" },
        .{ .ttype = token.TokenType.assign, .value = "=" },
        .{ .ttype = token.TokenType.int, .value = "1" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };

    var parser = parse.Parser.init(_bump, tokens[0..]);
    
    const node = try parser.parseStmt();
    try std.testing.expect(node != null);
    try std.testing.expectEqual(parse.ASTNodeType.var_decl, @as(parse.ASTNodeType, node.?.*));
    try std.testing.expectEqualStrings("mut", node.?.*.var_decl.identifier);
    try std.testing.expect(node.?.*.var_decl.mut);

    const number = node.?.*.var_decl.right.*.number;

    try std.testing.expectEqual(@as(f64, 1), number);
}

test "parse a block" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024, true);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.left_curly, .value = "{" },
        .{ .ttype = token.TokenType.int, .value = "123" },
        .{ .ttype = token.TokenType.right_curly, .value = "}" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };

    var parser = parse.Parser.init(_bump, tokens[0..]);
    const node = try parser.parseBlock();
    try std.testing.expect(node != null);

    try std.testing.expectEqual(123, node.?.*.block[0].number);
}

// test "parse function definition" {
//     const allocator = std.testing.allocator;

//     const tokens = [_]token.Token{
//         .{ .ttype = token.TokenType.fun, .value = "fun" },
//         .{ .ttype = token.TokenType.word, .value = "add" },
//         .{ .ttype = token.TokenType.left_paren, .value = "(" },
//         .{ .ttype = token.TokenType.word, .value = "a" },
//         .{ .ttype = token.TokenType.comma, .value = "," },
//         .{ .ttype = token.TokenType.word, .value = "b" },
//         .{ .ttype = token.TokenType.right_paren, .value = ")" },
//         .{ .ttype = token.TokenType.left_curly, .value = "{" },
//         .{ .ttype = token.TokenType.word, .value = "a" },
//         .{ .ttype = token.TokenType.plus, .value = "+" },
//         .{ .ttype = token.TokenType.word, .value = "b" },
//         .{ .ttype = token.TokenType.right_curly, .value = "}" },
//         .{ .ttype = token.TokenType.eof, .value = "" },
//     };
//     var parser = parse.Parser.init(allocator, tokens[0..]);
//     const node = try parser.parseStmt();
//     try std.testing.expect(node != null);
//     try std.testing.expectEqual(parse.ASTNodeType.fun_def, node.?.*);
//     try std.testing.expectEqualStrings("add", node.?.*.fun_def.identifier);
//     try std.testing.expectEqual(@as(usize, 2), node.?.*.fun_def.params.len);
// }
