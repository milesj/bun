const std = @import("std");
const Allocator = std.mem.Allocator;
const bun = @import("bun");
const Environment = bun.Environment;
const string = @import("string_types.zig").string;
const StringBuilder = @This();

const DebugHashTable = if (Environment.allow_assert) std.AutoHashMapUnmanaged(u64, void) else void;

len: usize = 0,
cap: usize = 0,
ptr: ?[*]u8 = null,

debug_only_checker: DebugHashTable = DebugHashTable{},

pub fn count(this: *StringBuilder, slice: string) void {
    this.cap += slice.len;
    if (comptime Environment.allow_assert) {
        _ = this.debug_only_checker.getOrPut(bun.default_allocator, bun.hash(slice)) catch unreachable;
    }
}

pub fn allocate(this: *StringBuilder, allocator: Allocator) !void {
    var slice = try allocator.alloc(u8, this.cap);
    this.ptr = slice.ptr;
    this.len = 0;
}

pub fn deinit(this: *StringBuilder, allocator: Allocator) void {
    if (this.ptr == null or this.cap == 0) return;
    allocator.free(this.ptr.?[0..this.cap]);
    if (comptime Environment.allow_assert) {
        this.debug_only_checker.deinit(bun.default_allocator);
        this.debug_only_checker = .{};
    }
}

pub fn append(this: *StringBuilder, slice: string) string {
    if (comptime Environment.allow_assert) {
        std.debug.assert(this.len <= this.cap); // didn't count everything
        std.debug.assert(this.ptr != null); // must call allocate first
        std.debug.assert(this.debug_only_checker.contains(bun.hash(slice)));
    }

    bun.copy(u8, this.ptr.?[this.len..this.cap], slice);
    const result = this.ptr.?[this.len..this.cap][0..slice.len];
    this.len += slice.len;

    if (comptime Environment.allow_assert) std.debug.assert(this.len <= this.cap);

    return result;
}

pub fn fmt(this: *StringBuilder, comptime str: string, args: anytype) string {
    if (comptime Environment.allow_assert) {
        std.debug.assert(this.len <= this.cap); // didn't count everything
        std.debug.assert(this.ptr != null); // must call allocate first
    }

    var buf = this.ptr.?[this.len..this.cap];
    const out = std.fmt.bufPrint(buf, str, args) catch unreachable;
    this.len += out.len;

    if (comptime Environment.allow_assert) std.debug.assert(this.len <= this.cap);

    return out;
}

pub fn fmtCount(this: *StringBuilder, comptime str: string, args: anytype) void {
    this.cap += std.fmt.count(str, args);
}

pub fn allocatedSlice(this: *StringBuilder) []u8 {
    var ptr = this.ptr orelse return &[_]u8{};
    if (comptime Environment.allow_assert) {
        std.debug.assert(this.cap > 0);
        std.debug.assert(this.len > 0);
    }
    return ptr[0..this.cap];
}
