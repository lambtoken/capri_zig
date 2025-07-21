const std = @import("std");
const token = @import("token.zig");
const parse = @import("parse.zig");
const bump = @import("bump.zig");

test "parse primary int" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.int, .value = "42" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };
    var parser = parse.Parser.init(_bump, tokens[0..]);

    const node = try parser.parsePrimary();
    try std.testing.expect(node != null);
    try std.testing.expectEqual(@as(f64, 42), node.?.number);
}

test "parse primary bool true" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.bool, .value = "true" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };
    var parser = parse.Parser.init(_bump, tokens[0..]);
    const node = try parser.parsePrimary();
    try std.testing.expect(node != null);
    try std.testing.expect(node.?.boolean);
}

test "parse primary string" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.string, .value = "hello" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };
    var parser = parse.Parser.init(_bump, tokens[0..]);
    const node = try parser.parsePrimary();
    try std.testing.expect(node != null);
    try std.testing.expectEqualStrings("hello", node.?.string);
}

test "parse primary identifier" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.word, .value = "foo" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };
    var parser = parse.Parser.init(_bump, tokens[0..]);
    const node = try parser.parsePrimary();
    try std.testing.expect(node != null);
    try std.testing.expectEqualStrings("foo", node.?.identifier);
}

test "parse primary nothing" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.nothing, .value = "nothing" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };
    var parser = parse.Parser.init(_bump, tokens[0..]);
    const node = try parser.parsePrimary();
    try std.testing.expect(node != null);
    try std.testing.expect(@as(parse.ASTNodeType, node.?) == .nothing);
}

test "parse binary expression" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.int, .value = "1" },
        .{ .ttype = token.TokenType.plus, .value = "+" },
        .{ .ttype = token.TokenType.int, .value = "2" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };
    var parser = parse.Parser.init(_bump, tokens[0..]);
    const node = try parser.parseExpr(0);
    try std.testing.expect(node != null);
    try std.testing.expect(@as(parse.ASTNodeType, @as(parse.ASTNodeType, node.?.*)) == .op);
    try std.testing.expect(node.?.*.op.operation == .add);

    const left = node.?.*.op.left;
    try std.testing.expect(@as(parse.ASTNodeType, left.*) == .number);
    try std.testing.expectEqual(@as(f64, 1), left.*.number);

    const right = node.?.*.op.right;
    try std.testing.expect(@as(parse.ASTNodeType, right.*) == .number);
    try std.testing.expectEqual(@as(f64, 2), right.*.number);
}

test "precedence" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.int, .value = "1" },
        .{ .ttype = token.TokenType.plus, .value = "+" },
        .{ .ttype = token.TokenType.int, .value = "2" },
        .{ .ttype = token.TokenType.multiply, .value = "*" },
        .{ .ttype = token.TokenType.int, .value = "3" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };

    var parser = parse.Parser.init(_bump, tokens[0..]);
    const node = try parser.parseExpr(0);
    try std.testing.expect(node != null);
    try std.testing.expect(@as(parse.ASTNodeType, @as(parse.ASTNodeType, node.?.*)) == .op);
    try std.testing.expect(node.?.*.op.operation == .add);

    const left = node.?.*.op.left;
    try std.testing.expect(@as(parse.ASTNodeType, left.*) == .number);
    try std.testing.expectEqual(@as(f64, 1), left.*.number);

    const right_op = node.?.*.op.right;
    try std.testing.expect(@as(parse.ASTNodeType, @as(parse.ASTNodeType, right_op.*)) == .op);
    try std.testing.expect(right_op.*.op.operation == .mul);

    const right_left = right_op.*.op.left;
    try std.testing.expect(@as(parse.ASTNodeType, right_left.*) == .number);
    try std.testing.expectEqual(@as(f64, 2), right_left.*.number);

    const right_right = right_op.*.op.right;
    try std.testing.expect(@as(parse.ASTNodeType, right_right.*) == .number);
    try std.testing.expectEqual(@as(f64, 3), right_right.*.number);
}

test "parse variable declaration" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
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
    try std.testing.expectEqualStrings("x", node.?.*.var_decl.identifier);
    try std.testing.expect(node.?.*.var_decl.mut);

    const number = node.?.*.var_decl.right.*.number;

    try std.testing.expectEqual(@as(f64, 1), number);
}

test "parse a block" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
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

test "parse args" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.left_paren, .value = "(" },
        .{ .ttype = token.TokenType.int, .value = "1" },
        .{ .ttype = token.TokenType.comma, .value = "," },
        .{ .ttype = token.TokenType.int, .value = "2" },
        .{ .ttype = token.TokenType.right_paren, .value = ")" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };

    var parser = parse.Parser.init(_bump, tokens[0..]);
    const args = try parser.parseArgs();
    try std.testing.expect(args != null);
    try std.testing.expectEqual(@as(usize, 2), args.?.args.len);
    try std.testing.expectEqual(@as(f64, 1), args.?.args[0].number);
    try std.testing.expectEqual(@as(f64, 2), args.?.args[1].number);
}

test "parse builtin call" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.builtin, .value = "print" },
        .{ .ttype = token.TokenType.left_paren, .value = "(" },
        .{ .ttype = token.TokenType.int, .value = "1" },
        .{ .ttype = token.TokenType.comma, .value = "," },
        .{ .ttype = token.TokenType.int, .value = "2" },
        .{ .ttype = token.TokenType.right_paren, .value = ")" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };

    var parser = parse.Parser.init(_bump, tokens[0..]);
    const node = try parser.parseBuiltinCall();
    try std.testing.expect(node != null);
    try std.testing.expectEqual(parse.ASTNodeType.bcall, @as(parse.ASTNodeType, node.?.*));
    try std.testing.expectEqualStrings("print", node.?.*.bcall.name);
    try std.testing.expectEqual(@as(f64, 1), node.?.*.bcall.args.*.args[0].number);
    try std.testing.expectEqual(@as(f64, 2), node.?.*.bcall.args.*.args[1].number);
}

test "bunch of builtin calls" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.left_curly, .value = "{" },
        .{ .ttype = token.TokenType.builtin, .value = "print" },
        .{ .ttype = token.TokenType.left_paren, .value = "(" },
        .{ .ttype = token.TokenType.int, .value = "1" },
        .{ .ttype = token.TokenType.right_paren, .value = ")" },
        .{ .ttype = token.TokenType.builtin, .value = "print" },
        .{ .ttype = token.TokenType.left_paren, .value = "(" },
        .{ .ttype = token.TokenType.int, .value = "2" },
        .{ .ttype = token.TokenType.right_paren, .value = ")" },
        .{ .ttype = token.TokenType.builtin, .value = "print" },
        .{ .ttype = token.TokenType.left_paren, .value = "(" },
        .{ .ttype = token.TokenType.int, .value = "3" },
        .{ .ttype = token.TokenType.right_paren, .value = ")" },
        .{ .ttype = token.TokenType.builtin, .value = "print" },
        .{ .ttype = token.TokenType.left_paren, .value = "(" },
        .{ .ttype = token.TokenType.int, .value = "4" },
        .{ .ttype = token.TokenType.right_paren, .value = ")" },
        .{ .ttype = token.TokenType.builtin, .value = "print" },
        .{ .ttype = token.TokenType.left_paren, .value = "(" },
        .{ .ttype = token.TokenType.int, .value = "5" },
        .{ .ttype = token.TokenType.right_paren, .value = ")" },
        .{ .ttype = token.TokenType.builtin, .value = "print" },
        .{ .ttype = token.TokenType.left_paren, .value = "(" },
        .{ .ttype = token.TokenType.int, .value = "6" },
        .{ .ttype = token.TokenType.right_paren, .value = ")" },
        .{ .ttype = token.TokenType.builtin, .value = "print" },
        .{ .ttype = token.TokenType.left_paren, .value = "(" },
        .{ .ttype = token.TokenType.int, .value = "7" },
        .{ .ttype = token.TokenType.right_paren, .value = ")" },
        .{ .ttype = token.TokenType.builtin, .value = "print" },
        .{ .ttype = token.TokenType.left_paren, .value = "(" },
        .{ .ttype = token.TokenType.int, .value = "8" },
        .{ .ttype = token.TokenType.right_paren, .value = ")" },
        .{ .ttype = token.TokenType.builtin, .value = "print" },
        .{ .ttype = token.TokenType.left_paren, .value = "(" },
        .{ .ttype = token.TokenType.int, .value = "9" },
        .{ .ttype = token.TokenType.right_paren, .value = ")" },
        .{ .ttype = token.TokenType.builtin, .value = "print" },
        .{ .ttype = token.TokenType.left_paren, .value = "(" },
        .{ .ttype = token.TokenType.int, .value = "10" },
        .{ .ttype = token.TokenType.right_paren, .value = ")" },
        .{ .ttype = token.TokenType.right_curly, .value = "}" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };

    var parser = parse.Parser.init(_bump, tokens[0..]);
    const node = try parser.parseBlock();
    try std.testing.expect(node != null);
    try std.testing.expectEqual(10, node.?.*.block.len);

    try std.testing.expectEqualStrings("print", node.?.*.block[0].*.bcall.name);
    try std.testing.expectEqual(@as(f64, 1), node.?.*.block[0].*.bcall.args.*.args[0].number);
    try std.testing.expectEqual(parse.ASTNodeType.bcall, @as(parse.ASTNodeType, node.?.*.block[9].*));
    try std.testing.expectEqualStrings("print", node.?.*.block[9].*.bcall.name);
    try std.testing.expectEqual(@as(f64, 10), node.?.*.block[9].*.bcall.args.*.args[0].number);
}

test "block of expressions" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.left_curly, .value = "{" },
        .{ .ttype = token.TokenType.int, .value = "1" },
        .{ .ttype = token.TokenType.plus, .value = "+" },
        .{ .ttype = token.TokenType.int, .value = "2" },
        .{ .ttype = token.TokenType.int, .value = "3" },
        .{ .ttype = token.TokenType.plus, .value = "+" },
        .{ .ttype = token.TokenType.int, .value = "4" },
        .{ .ttype = token.TokenType.right_curly, .value = "}" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };

    var parser = parse.Parser.init(_bump, tokens[0..]);
    const node = try parser.parseBlock();
    try std.testing.expect(node != null);
    try std.testing.expectEqual(2, node.?.*.block.len);

    const one = node.?.*.block[0].*.op.left.number;
    const two = node.?.*.block[0].*.op.right.number;
    const three = node.?.*.block[1].*.op.left.number;
    const four = node.?.*.block[1].*.op.right.number;

    try std.testing.expectEqual(@as(f64, 1), one);
    try std.testing.expectEqual(@as(f64, 2), two);
    try std.testing.expectEqual(@as(f64, 3), three);
    try std.testing.expectEqual(@as(f64, 4), four);
}

test "if else" {
    const _bump: *bump.Bump = try bump.newBump(std.heap.page_allocator, 1024);
    defer bump.freeBump(_bump);

    const tokens = [_]token.Token{
        .{ .ttype = token.TokenType.if_, .value = "if" },
        .{ .ttype = token.TokenType.int, .value = "1" },
        .{ .ttype = token.TokenType.left_curly, .value = "{" },
        .{ .ttype = token.TokenType.int, .value = "1" },
        .{ .ttype = token.TokenType.right_curly, .value = "}" },
        .{ .ttype = token.TokenType.else_, .value = "else" },
        .{ .ttype = token.TokenType.if_, .value = "if" },
        .{ .ttype = token.TokenType.int, .value = "2" },
        .{ .ttype = token.TokenType.left_curly, .value = "{" },
        .{ .ttype = token.TokenType.int, .value = "2" },
        .{ .ttype = token.TokenType.right_curly, .value = "}" },
        .{ .ttype = token.TokenType.else_, .value = "else" },
        .{ .ttype = token.TokenType.left_curly, .value = "{" },
        .{ .ttype = token.TokenType.int, .value = "2" },
        .{ .ttype = token.TokenType.right_curly, .value = "}" },
        .{ .ttype = token.TokenType.eof, .value = "" },
    };

    var parser = parse.Parser.init(_bump, tokens[0..]);
    const node = try parser.parseStmt();
    try std.testing.expect(node != null);

    try std.testing.expectEqual(parse.ASTNodeType.if_stmt, @as(parse.ASTNodeType, node.?.*));
    try std.testing.expectEqual(@as(f64, 1), node.?.*.if_stmt.condition.number);
    try std.testing.expectEqual(parse.ASTNodeType.block, @as(parse.ASTNodeType, node.?.*.if_stmt.then_stmt.*));
    try std.testing.expectEqual(@as(f64, 1), node.?.*.if_stmt.then_stmt.*.block[0].number);
    try std.testing.expectEqual(parse.ASTNodeType.else_if_stmts, @as(parse.ASTNodeType, node.?.*.if_stmt.else_if_stmts.?[0].*));
    try std.testing.expectEqual(@as(f64, 2), node.?.*.if_stmt.else_if_stmts.?[0].else_if_stmts.condition.number);
    try std.testing.expectEqual(parse.ASTNodeType.block, @as(parse.ASTNodeType, node.?.*.if_stmt.else_if_stmts.?[0].else_if_stmts.then_stmt.*));
    try std.testing.expectEqual(@as(f64, 2), node.?.*.if_stmt.else_if_stmts.?[0].else_if_stmts.then_stmt.*.block[0].number);
    try std.testing.expectEqual(parse.ASTNodeType.else_stmt, @as(parse.ASTNodeType, node.?.*.if_stmt.else_if_stmts.?[1].*));
    try std.testing.expectEqual(parse.ASTNodeType.block, @as(parse.ASTNodeType, node.?.*.if_stmt.else_if_stmts.?[1].else_stmt.then_stmt.*));
    try std.testing.expectEqual(@as(f64, 2), node.?.*.if_stmt.else_if_stmts.?[1].else_stmt.then_stmt.*.block[0].number);
}
