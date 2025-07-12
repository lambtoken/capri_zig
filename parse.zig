const std = @import("std");
const token = @import("token.zig");
const bump = @import("bump.zig");

pub const ASTNodeType = enum {
    block,
    number,
    nope,
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
    call,
    bcall,
    for_loop,
    return_,
};

pub const Operation = enum {
    add,
    sub,
    mul,
    div,
    range,
};

pub const ASTNode = union(ASTNodeType) {
    block: []*ASTNode,
    number: f64,
    nope: void,
    boolean: bool,
    string: []const u8,
    var_decl: struct {
        identifier: []const u8,
        right: *ASTNode,
        mut: bool,
    },
    fun_def: struct {
        identifier: []const u8,
        params: []ASTNode,
        body: *ASTNode,
    },
    params: []ASTNode,
    args: []ASTNode,
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
    call: struct {
        name: []const u8,
        args: []ASTNode,
    },
    bcall: struct {
        callee: []const u8,
        args: []ASTNode,
    },
    for_loop: struct {
        range: *ASTNode,
        body: *ASTNode,
    },
    return_: *ASTNode,
};

const Precedence = struct {
    left: i32,
    right: i32,
};

const precedence_table = [_]Precedence{
    .{ .left = 1, .right = 1 }, // add
    .{ .left = 1, .right = 1 }, // sub
    .{ .left = 2, .right = 2 }, // mul
    .{ .left = 2, .right = 2 }, // div
    .{ .left = 0, .right = 0 }, // range
};

pub const Parser = struct {
    tokens: []const token.Token,
    pos: usize,
    bump: *bump.Bump,
    allocator: std.mem.Allocator,

    pub fn init(_bump: *bump.Bump, tokens: []const token.Token) Parser {
        return Parser{ 
            .tokens = tokens, 
            .pos = 0,
            .bump = _bump,
            .allocator = std.heap.page_allocator
        };
    }

    pub fn deinit(self: *Parser) void {
        // self.allocator.free(self.tokens);
        _ = self;
    }

    pub fn isBinaryOperator(tok: token.Token) bool {
        return switch (tok.ttype) {
            .plus, .minus, .multiply, .divide, .range => true,
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
            else => null,
        };
    }

    fn precedence(op: Operation) u8 {
        return switch (op) {
            .add, .sub => 1,
            .mul, .div => 2,
            .range => 0,
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

    pub fn parsePrimary(self: *Parser) !?ASTNode {
        const tok = self.current() orelse return null;
        switch (tok.ttype) {
            .bool => {
                self.consume(1);
                return ASTNode{ .boolean = std.mem.eql(u8, tok.value, "true") };
            },
            .int => {
                self.consume(1);
                const val = try std.fmt.parseFloat(f64, tok.value);
                return ASTNode{ .number = val };
            },
            .string => {
                self.consume(1);
                return ASTNode{ .string = tok.value };
            },
            .word => {
                self.consume(1);
                return ASTNode{ .identifier = tok.value };
            },
            .nope => {
                self.consume(1);
                return ASTNode{ .nope = {} };
            },
            else => return null,
        }
    }

    pub fn parseExpr(self: *Parser, min_prec: i32) !?*ASTNode {
        const left = try self.parsePrimary();
        if (left == null) return null;
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
            }};
            left_node = op_node;
        }

        return left_node;
    }

    pub fn parseBlock(self: *Parser) !?*ASTNode {
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
        if (try self.parseVarDecl()) |node| return node;
        // if (try self.parseFunDef()) |node| return node;
        // if (try self.parseForLoop()) |node| return node;
        // if (try self.parseBlock()) |node| return node;
        if (try self.parseExpr(0)) |node| return node;
        return null;
    }

    pub inline fn isVarDecl(self: *Parser) bool {
        const curr = self.current() orelse null;
        const second = self.peek(1) orelse null;
        const third = self.peek(2) orelse null;

        if (curr.?.ttype == .mut and second.?.ttype == .word and third.?.ttype == .assign
        or  curr.?.ttype == .word and second.?.ttype == .assign) {
            return true;
        }

        return false;
    }

    fn parseVarDecl(self: *Parser) !?*ASTNode {
        if (!self.isVarDecl()) {
            return null;
        }

        const curr = self.current() orelse return null;
        var is_mut = false;

        if (curr.ttype == .mut) {
            is_mut = true;
            self.consume(1);
        }

        // const tok = self.current() orelse return null;
        // if (tok.ttype != .word) return null;
        const name = curr.value;
        // self.consume(1);

        // const assign = self.current() orelse return null;
        // if (assign.ttype != .assign) return null;
        // self.consume(1);

        // const value = try self.parseExpr(0) orelse return error.ExpectedExpression;

        const decl_node = try bump.create(self.bump, ASTNode);
        const value = try bump.create(self.bump, ASTNode);
        value.* = .{.number = 1 };

        decl_node.* = .{ .var_decl = .{
            .identifier = name,
            .right = value,
            .mut = is_mut,
        }};
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
        }};
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
        }};
        return for_node;
    }
};
