const std = @import("std");
const token = @import("token.zig");
const bump = @import("bump.zig");

pub const ASTNodeType = enum {
    block,
    number,
    nothing,
    boolean,
    string,
    var_decl,
    fun_def,
    params,
    args,
    assign,
    identifier,
    op,
    expr,
    stmt,
    if_stmt,
    else_if_stmts,
    else_stmt,
    call,
    bcall,
    while_loop,
    break_,
    for_loop,
    return_,
    array,
    array_access,
};

pub const Operation = enum {
    add,
    sub,
    mul,
    div,
    range,
    lt,
    gt,
    le,
    ge,
    eq,
    ne,
    and_,
    or_,
};

pub const ASTNode = union(ASTNodeType) {
    block: []*ASTNode,
    number: f64,
    nothing: void,
    boolean: bool,
    string: []const u8,
    var_decl: struct {
        identifier: []const u8,
        right: *ASTNode,
        mut: bool,
    },
    fun_def: struct {
        identifier: []const u8,
        params: []*ASTNode,
        body: *ASTNode,
    },
    params: []*ASTNode,
    args: []*ASTNode,
    assign: struct {
        left: *ASTNode,
        right: *ASTNode,
    },
    identifier: []const u8,
    op: struct {
        left: *ASTNode,
        right: *ASTNode,
        operation: Operation,
    },
    expr: *ASTNode,
    stmt: *ASTNode,
    if_stmt: struct {
        condition: *ASTNode,
        then_stmt: *ASTNode,
        else_if_stmts: ?[]*ASTNode,
    },
    else_if_stmts: struct {
        condition: *ASTNode,
        then_stmt: *ASTNode,
    },
    else_stmt: struct {
        then_stmt: *ASTNode,
    },
    call: struct {
        name: []const u8,
        args: []*ASTNode,
    },
    bcall: struct {
        name: []const u8,
        args: *ASTNode,
    },
    while_loop: struct { condition: *ASTNode, body: *ASTNode },
    break_: void,
    for_loop: struct {
        range: *ASTNode,
        body: *ASTNode,
        iter_name: []const u8,
    },
    return_: *ASTNode,
    array: struct {
        elements: []*ASTNode,
    },
    array_access: struct {
        array_name: []const u8,
        indices: []*ASTNode,
    },
};

const Precedence = struct {
    left: i32,
    right: i32,
};

const precedence_table = [_]Precedence{
    .{ .left = 8, .right = 8 }, // div
    .{ .left = 7, .right = 7 }, // mul
    .{ .left = 6, .right = 6 }, // add
    .{ .left = 6, .right = 6 }, // sub
    .{ .left = 5, .right = 5 }, // range
    .{ .left = 4, .right = 4 }, // lt
    .{ .left = 4, .right = 4 }, // gt
    .{ .left = 4, .right = 4 }, // le
    .{ .left = 4, .right = 4 }, // ge
    .{ .left = 3, .right = 3 }, // eq
    .{ .left = 3, .right = 3 }, // ne
    .{ .left = 2, .right = 2 }, // and
    .{ .left = 1, .right = 1 }, // or
};

pub const Parser = struct {
    tokens: []const token.Token,
    pos: usize,
    bump: *bump.Bump,
    allocator: std.mem.Allocator,

    pub fn init(_bump: *bump.Bump, tokens: []const token.Token) Parser {
        return Parser{ .tokens = tokens, .pos = 0, .bump = _bump, .allocator = std.heap.page_allocator };
    }

    pub fn deinit(self: *Parser) void {
        // self.allocator.free(self.tokens);
        _ = self;
    }

    pub fn isBinaryOperator(tok: token.Token) bool {
        return switch (tok.ttype) {
            .plus, .minus, .multiply, .divide, .range, .lt, .gt, .le, .ge, .eq, .ne, .and_, .or_ => true,
            else => false,
        };
    }

    pub fn getOperationType(tok: token.Token) ?Operation {
        return switch (tok.ttype) {
            .plus => .add,
            .minus => .sub,
            .multiply => .mul,
            .divide => .div,
            .range => .range,
            .lt => .lt,
            .gt => .gt,
            .le => .le,
            .ge => .ge,
            .eq => .eq,
            .ne => .ne,
            .and_ => .and_,
            .or_ => .or_,
            else => null,
        };
    }

    fn precedence(op: Operation) u8 {
        return switch (op) {
            .div => 8,
            .mul => 7,
            .add => 6,
            .sub => 6,
            .range => 5,
            .lt => 4,
            .gt => 4,
            .le => 4,
            .ge => 4,
            .eq => 3,
            .ne => 3,
            .and_ => 2,
            .or_ => 1,
        };
    }

    pub fn peek(self: *Parser, offset: usize) ?token.Token {
        if (self.pos + offset < self.tokens.len) {
            return self.tokens[self.pos + offset];
        }
        return null;
    }

    pub fn consume(self: *Parser, amount: usize) void {
        self.pos += amount;
    }

    pub fn current(self: *Parser) ?token.Token {
        if (self.pos < self.tokens.len) {
            return self.tokens[self.pos];
        }
        return null;
    }

    pub fn parsePrimary(self: *Parser) anyerror!?ASTNode {
        const tok = self.current() orelse return null;
        switch (tok.ttype) {
            .bool => {
                self.consume(1);
                return ASTNode{ .boolean = std.mem.eql(u8, tok.value, "true") };
            },
            .int, .float => {
                self.consume(1);
                const val = try std.fmt.parseFloat(f64, tok.value);
                return ASTNode{ .number = val };
            },
            .string => {
                self.consume(1);
                return ASTNode{ .string = tok.value };
            },
            .word => {
                if (self.peek(1) orelse null) |bracket_maybe| {
                    if (bracket_maybe.ttype == .left_bracket) {
                        if (try self.parseArrayAccess(tok.value)) |access_node| {
                            return access_node.*;
                        } else {
                            return error.ExpectedExpression;
                        }
                    }
                }

                self.consume(1);
                return ASTNode{ .identifier = tok.value };
            },
            .nothing => {
                self.consume(1);
                return ASTNode{ .nothing = {} };
            },
            .builtin => {
                const name = tok.value;
                self.consume(1);

                if (try self.parseExprList()) |args| {
                    return ASTNode{ .bcall = .{ .name = name, .args = args } };
                } else {
                    return null;
                }
            },
            .left_bracket => {
                if (try self.parseArray()) |array_node| {
                    return array_node.*;
                } else {
                    return null;
                }
            },
            else => return null,
        }
    }

    pub fn parseExpr(self: *Parser, min_prec: i32) !?*ASTNode {
        const left = try self.parsePrimary();
        if (left == null) {
            return null;
        }
        var left_node = try bump.create(self.bump, ASTNode);
        left_node.* = left.?;

        while (true) {
            const curr_token = self.current() orelse break;
            if (!isBinaryOperator(curr_token)) break;

            const op = getOperationType(curr_token).?;
            const prec = precedence(op);
            if (prec < min_prec) break;

            self.consume(1);
            const right = try self.parseExpr(prec + 1);
            if (right == null) return error.ExpectedExpression;

            const op_node = try bump.create(self.bump, ASTNode);
            op_node.* = ASTNode{ .op = .{
                .left = left_node,
                .right = right.?,
                .operation = op,
            } };
            left_node = op_node;
        }

        return left_node;
    }

    pub fn parseBlock(self: *Parser) anyerror!?*ASTNode {
        const curr = self.current() orelse return null;
        if (curr.ttype != .left_curly) return null;
        // we should throw an error here. never return null
        // throw it and print it to the stdout (for now)
        self.consume(1);

        var temp = std.ArrayList(*ASTNode).init(self.allocator); // temporary list, general-purpose allocator
        defer temp.deinit();

        while (true) {
            const tok = self.current() orelse return error.UnexpectedEOF;
            if (tok.ttype == .right_curly) break;

            const node = try self.parseStmt() orelse return error.ExpectedStatement;
            try temp.append(node);
        }
        self.consume(1);

        const slice = try bump.alloc(self.bump, *ASTNode, temp.items.len);
        @memcpy(slice, temp.items);

        const block_node = try bump.create(self.bump, ASTNode);
        block_node.* = .{ .block = slice };
        return block_node;
    }

    pub fn parseStmt(self: *Parser) !?*ASTNode {
        if (try self.parseBuiltinCall()) |node| return node;
        if (try self.parseVarDecl()) |node| return node;
        if (try self.parseIfStmt()) |node| return node;
        if (try self.parseWhileLoop()) |node| return node;
        if (try self.parseForLoop()) |node| return node;
        if (try self.parseBreak()) |node| return node;
        if (try self.parseExpr(0)) |node| return node;
        // if (try self.parseFunDef()) |node| return node;
        return null;
    }

    pub fn parseIfStmt(self: *Parser) !?*ASTNode {
        const curr = self.current() orelse return null;
        if (curr.ttype != .if_) return null;
        self.consume(1);

        const condition = try self.parseExpr(0) orelse return error.ExpectedExpression;
        const then_stmt = try self.parseBlock() orelse return error.ExpectedStatement;
        const else_if_stmts = try self.parseElseIfStmts();

        const if_node = try bump.create(self.bump, ASTNode);
        if_node.* = .{ .if_stmt = .{
            .condition = condition,
            .then_stmt = then_stmt,
            .else_if_stmts = else_if_stmts,
        } };
        return if_node;
    }

    pub fn parseElseIfStmts(self: *Parser) !?[]*ASTNode {
        var stmts = std.ArrayList(*ASTNode).init(self.allocator);
        defer stmts.deinit();

        while (true) {
            const curr = self.current() orelse break;
            if (curr.ttype != .else_) break;

            const second = self.peek(1);
            if (second != null and second.?.ttype == .if_) {
                self.consume(1); // consume "else"
                self.consume(1); // consume "if"

                const condition = try self.parseExpr(0) orelse return error.ExpectedExpression;
                const then_stmt = try self.parseBlock() orelse return error.ExpectedStatement;
                const else_if_node = try bump.create(self.bump, ASTNode);
                else_if_node.* = ASTNode{ .else_if_stmts = .{
                    .condition = condition,
                    .then_stmt = then_stmt,
                } };
                try stmts.append(else_if_node);
            } else {
                if (try self.parseElseStmt()) |node| {
                    try stmts.append(node);
                    break;
                } else {
                    break;
                }
            }
        }

        if (stmts.items.len == 0) return null;

        const slice = try bump.alloc(self.bump, *ASTNode, stmts.items.len);
        @memcpy(slice, stmts.items);

        return slice;
    }

    pub fn parseElseStmt(self: *Parser) !?*ASTNode {
        const curr = self.current() orelse return null;
        if (curr.ttype != .else_) return null;
        self.consume(1);

        const then_stmt = try self.parseBlock() orelse return error.ExpectedStatement;

        const else_node = try bump.create(self.bump, ASTNode);
        else_node.* = .{ .else_stmt = .{
            .then_stmt = then_stmt,
        } };
        return else_node;
    }

    pub inline fn isVarDecl(self: *Parser) bool {
        const curr = self.current() orelse null;
        const second = self.peek(1) orelse null;
        const third = self.peek(2) orelse null;

        if (curr.?.ttype == .mut and second.?.ttype == .word and third.?.ttype == .assign or curr.?.ttype == .word and second.?.ttype == .assign) {
            return true;
        }

        return false;
    }

    fn parseVarDecl(self: *Parser) !?*ASTNode {
        if (!self.isVarDecl()) return null;

        const curr = self.current() orelse return null;
        var is_mut = false;

        if (curr.ttype == .mut) {
            is_mut = true;
            self.consume(1);
        }

        const tok = self.current() orelse return null;
        if (tok.ttype != .word) return null;
        const name = tok.value;
        self.consume(1);

        const assign = self.current() orelse return null;
        if (assign.ttype != .assign) return null;
        self.consume(1);

        const value = try self.parseExpr(0) orelse return error.ExpectedExpression;

        const decl_node = try bump.create(self.bump, ASTNode);
        decl_node.* = .{ .var_decl = .{
            .identifier = name,
            .right = value,
            .mut = is_mut,
        } };
        return decl_node;
    }

    fn parseFunDef(self: *Parser) !?*ASTNode {
        const curr = self.current() orelse return null;
        if (curr.ttype != .fun) return null;
        self.consume(1);

        const name = self.current() orelse return error.ExpectedIdentifier;
        if (name.ttype != .word) return error.ExpectedIdentifier;
        self.consume(1);

        // Parse parameters
        var params = std.ArrayList(*ASTNode).init(self.allocator);
        defer params.deinit();

        const lparen = self.current() orelse return error.ExpectedLeftParen;
        if (lparen.ttype != .left_paren) return error.ExpectedLeftParen;
        self.consume(1);

        while (true) {
            const tok = self.current() orelse return error.UnexpectedEOF;
            if (tok.ttype == .right_paren) break;

            if (tok.ttype == .comma) {
                self.consume(1);
                continue;
            }

            if (tok.ttype != .word) return error.ExpectedIdentifier;
            const param_node = try bump.create(self.bump, ASTNode);
            param_node.* = .{ .identifier = tok.value };
            try params.append(param_node);
            self.consume(1);
        }
        self.consume(1); // consume right paren

        const body = try self.parseBlock() orelse return error.ExpectedBlock;

        const fun_node = try bump.create(self.bump, ASTNode);
        fun_node.* = .{ .fun_def = .{
            .identifier = name.value,
            .params = try params.toOwnedSlice(),
            .body = body,
        } };
        return fun_node;
    }

    fn parseForLoop(self: *Parser) !?*ASTNode {
        const curr = self.current() orelse return null;
        if (curr.ttype != .for_) return null;
        self.consume(1);

        const iter = self.current() orelse return error.ExpectedIdentifier;
        if (iter.ttype != .word) return error.ExpectedIdentifier;
        self.consume(1);

        const in_tok = self.current() orelse return error.ExpectedIn;
        if (in_tok.ttype != .in_) return error.ExpectedIn;
        self.consume(1);

        const range = try self.parseExpr(0) orelse return error.ExpectedExpression;
        const body = try self.parseBlock() orelse return error.ExpectedBlock;

        const for_node = try bump.create(self.bump, ASTNode);
        for_node.* = .{ .for_loop = .{
            .range = range,
            .body = body,
            .iter_name = iter.value,
        } };
        return for_node;
    }

    pub fn parseBuiltinCall(self: *Parser) !?*ASTNode {
        const curr = self.current() orelse return null;
        if (curr.ttype != .builtin) return null;

        const name = curr.value;
        self.consume(1);

        const args = try self.parseExprList() orelse return error.ExpectedArgs;
        const call_node = try bump.create(self.bump, ASTNode);
        call_node.* = .{ .bcall = .{ .name = name, .args = args } };
        return call_node;
    }

    pub fn parseExprList(self: *Parser) !?*ASTNode {
        const curr = self.current() orelse return null;
        if (curr.ttype != .left_paren) return null;
        self.consume(1);

        var exprs = std.ArrayList(*ASTNode).init(self.allocator);
        defer exprs.deinit();

        while (true) {
            const tok = self.current() orelse return error.UnexpectedEOF;
            if (tok.ttype == .right_paren) break;

            if (tok.ttype == .comma) {
                self.consume(1);
                continue;
            }
            const arg = try self.parseExpr(0) orelse return error.ExpectedExpression;
            try exprs.append(arg);
        }
        self.consume(1);

        const slice = try bump.alloc(self.bump, *ASTNode, exprs.items.len);
        @memcpy(slice, exprs.items);

        const args_node = try bump.create(self.bump, ASTNode);
        args_node.* = .{ .args = slice };
        return args_node;
    }

    pub fn parseWhileLoop(self: *Parser) !?*ASTNode {
        const curr = self.current() orelse return null;
        if (curr.ttype != .while_) return null;
        self.consume(1);

        const condition = try self.parseExpr(0) orelse return error.ExpectedExpression;

        const body = try self.parseBlock() orelse return error.ExpectedBlock;

        const loop_node = try bump.create(self.bump, ASTNode);
        loop_node.* = .{ .while_loop = .{
            .condition = condition,
            .body = body,
        } };

        return loop_node;
    }

    fn parseBreak(self: *Parser) !?*ASTNode {
        const curr = self.current() orelse return null;
        if (curr.ttype != .break_) return null;
        self.consume(1);

        const break_node = try bump.create(self.bump, ASTNode);
        break_node.* = .break_;
        return break_node;
    }

    fn parseArray(self: *Parser) anyerror!?*ASTNode {
        const curr = self.current() orelse return null;
        if (curr.ttype != .left_bracket) return null;
        self.consume(1);

        var exprs = std.ArrayList(*ASTNode).init(self.allocator);
        defer exprs.deinit();

        // change parseExprList to not expect parens
        while (true) {
            const tok = self.current() orelse return error.UnexpectedEOF;
            if (tok.ttype == .right_bracket) break;

            if (tok.ttype == .comma) {
                self.consume(1);
                continue;
            }

            const element = try self.parseExpr(0) orelse return error.ExpectedExpression;
            try exprs.append(element);
        }

        const right_bracket = self.current() orelse return error.ExpectedRightBracket;
        if (right_bracket.ttype != .right_bracket) return error.ExpectedRightBracket;
        self.consume(1);

        const slice = try bump.alloc(self.bump, *ASTNode, exprs.items.len);
        @memcpy(slice, exprs.items);

        const array_node = try bump.create(self.bump, ASTNode);
        array_node.* = .{
            .array = .{
                .elements = slice,
            },
        };
        return array_node;
    }

    fn parseArrayAccess(self: *Parser, identifier: []const u8) anyerror!?*ASTNode {
        self.consume(1);

        var indices = std.ArrayList(*ASTNode).init(self.allocator);
        defer indices.deinit();

        while (true) {
            const curr = self.current() orelse break;
            if (curr.ttype != .left_bracket) break;
            self.consume(1);

            const index = try self.parseExpr(0) orelse return error.ExpectedExpression;
            const right_bracket = self.current() orelse return error.ExpectedRightBracket;
            if (right_bracket.ttype != .right_bracket) return error.ExpectedRightBracket;
            self.consume(1); // consume the right bracket
            try indices.append(index);
        }

        if (indices.items.len == 0) return error.ExpectedExpression;

        const slice = try bump.alloc(self.bump, *ASTNode, indices.items.len);
        @memcpy(slice, indices.items);

        const access_node = try bump.create(self.bump, ASTNode);
        access_node.* = .{
            .array_access = .{
                .array_name = identifier,
                .indices = slice,
            },
        };
        return access_node;
    }

    pub fn parseProgram(self: *Parser) !*ASTNode {
        var stmts = std.ArrayList(*ASTNode).init(self.allocator);
        defer stmts.deinit();

        while (true) {
            const tok = self.current() orelse break;
            if (tok.ttype == token.TokenType.eof) break;

            if (try self.parseStmt()) |stmt| {
                try stmts.append(stmt);
            } else {
                break;
            }
        }

        const slice = try bump.alloc(self.bump, *ASTNode, stmts.items.len);
        @memcpy(slice, stmts.items);

        const block_node = try bump.create(self.bump, ASTNode);
        block_node.* = .{ .block = slice };
        return block_node;
    }

    // TODO: This should urgently be done!
    // pub fn dumpTree(self: *Parser, node: *ASTNode, indent: usize) void {
    //     const prefix = std.fmt.allocPrint(self.allocator, "{s}", .{std.mem.repeat(" ", indent)}) catch return;
    //     defer self.allocator.free(prefix);

    //     switch (node.*) {
    //         .block => |block| {
    //             std.debug.print("{s}Block:\n", .{prefix});
    //             for (block) |stmt| {
    //                 self.dumpTree(stmt, indent + 2);
    //             }
    //         },
    //         .number => |num| {
    //             std.debug.print("{s}Number: {d}\n", .{prefix, num});
    //         },
    //         .nothing => {
    //             std.debug.print("{s}nothing\n", .{prefix});
    //         },
    //         .boolean => |bool_| {
    //             std.debug.print("{s}Boolean: {s}\n", .{prefix, if (bool) "true" else "false"});
    //         },
    //         .string => |str| {
    //             std.debug.print("{s}String: '{s}'\n", .{prefix, str});
    //         },
    //         .var_decl => |decl| {
    //             std.debug.print("{s}VarDecl: {s} = ...\n", .{prefix, decl.identifier});
    //         },
    //         .fun_def => |fun| {
    //             std.debug.print("{s}FunDef: {s}(...)\n", .{prefix, fun.identifier});
    //             for (fun.params) |param| {
    //                 self.dumpTree(param, indent + 2);
    //             }
    //             self.dumpTree(fun.body, indent + 2);
    //         },
    //         .params => |params| {
    //             std.debug.print("{s}Params:\n", .{prefix});
    //             for (params) |param| {
    //                 self.dumpTree(param, indent + 2);
    //             }
    //         },
    //         .args => |args| {
    //             std.debug.print("{s}Args:\n", .{prefix});
    //             for (args) |arg| {
    //                 self.dumpTree(arg, indent + 2);
    //             }
    //         },
    //         .assign => |assign| {
    //             std.debug.print("{s}Assign:\n", .{prefix});
    //             self.dumpTree(assign.left, indent + 2);
    //             self.dumpTree(assign.right, indent + 2);
    //         },
    //         .identifier => |id| {
    //             std.debug.print("{s}Identifier: {s}\n", .{prefix, id});
    //         },
    //         .op => |op| {
    //             std.debug.print("{s}Op: {s}\n", .{prefix, switch (op.operation) {
    //                 .add => "Add",
    //                 .sub => "Sub",
    //                 .mul => "Mul",
    //                 .div => "Div",
    //                 .range => "Range",
    //             }});
    //             self.dumpTree(op.left, indent + 2);
    //             self.dumpTree(op.right, indent + 2);
    //         },
    //         .expr => |expr| {
    //             std.debug.print("{s}Expr:\n", .{prefix});
    //             self.dumpTree(expr, indent + 2);
    //         },
    //         .stmt => |stmt| {
    //             std.debug.print("{s}Stmt:\n", .{prefix});
    //             self.dumpTree(stmt, indent + 2);
    //         },
    //         .call => |call| {
    //             std.debug.print("{s}Call: {s}(...)\n", .{prefix, call.name});
    //             for (call.args) |arg| {
    //                 self.dumpTree(arg, indent + 2);
    //             }
    //         },
    //         .bcall => |bcall| {
    //             std.debug.print("{s}Builtin Call: {s}(...)\n", .{prefix, bcall.name});
    //             self.dumpTree(bcall.args, indent + 2);
    //         },
    //         .for_loop => |loop| {
    //             std.debug.print("{s}For Loop:\n", .{prefix});
    //             self.dumpTree(loop.range, indent + 2);
    //             self.dumpTree(loop.body, indent + 2);
    //         },
    //         .return_ => |ret| {
    //             std.debug.print("{s}Return:\n", .{prefix});
    //             self.dumpTree(ret, indent + 2);
    //         },
    //         else => {
    //             std.debug.print("{s}Unknown Node Type\n", .{prefix});
    //         }
    //     }
    // }
};
