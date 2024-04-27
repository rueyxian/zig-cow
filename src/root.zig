const std = @import("std");
const debug = std.debug;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Size = std.builtin.Type.Pointer.Size;
const PointerInfo = std.builtin.Type.Pointer;

fn getPointerInfo(comptime Pointer: type) PointerInfo {
    const info = @typeInfo(Pointer);
    if (info != .Pointer) {
        @compileError("Must be a pointer, cannot use `" ++ @typeName(Pointer) ++ "`.");
    }
    if (info.Pointer.size != .One and info.Pointer.size != .Slice) {
        @compileError("Must be a slice or a single-item pointer, cannot use `" ++ @typeName(Pointer) ++ "`.");
    }
    debug.assert(info.Pointer.sentinel == null or info.Pointer.size == .Slice);
    return info.Pointer;
}

pub fn borrowedCow(pointer: anytype) Cow(@TypeOf(pointer)) {
    return borrowedCowAs(@TypeOf(pointer), pointer);
}

pub fn ownedCow(pointer: anytype) Cow(@TypeOf(pointer)) {
    return ownedCowAs(@TypeOf(pointer), pointer);
}

pub fn borrowedCowAs(comptime Pointer: type, pointer: Pointer) Cow(Pointer) {
    return Cow(Pointer){
        .is_owned = false,
        .pointer = pointer,
    };
}

pub fn ownedCowAs(comptime Pointer: type, pointer: Pointer) Cow(Pointer) {
    return Cow(Pointer){
        .is_owned = true,
        .pointer = pointer,
    };
}

pub fn Cow(comptime PointerType: type) type {
    const info = getPointerInfo(PointerType);

    return struct {
        is_owned: bool,
        pointer: Pointer,

        pub const Self = @This();
        pub const Pointer: type = PointerType;
        pub const Child: type = info.child;
        pub const is_const = info.is_const;
        pub const pointer_size: Size = info.size;
        pub const alignment: ?u29 = info.alignment;
        pub const sentinel: ?Child = if (info.sentinel) |s| @as(*const Child, @ptrCast(@alignCast(s))).* else null;

        pub fn deinit(self: Self, allocator: Allocator) void {
            const Impl = switch (pointer_size) {
                .One => struct {
                    fn f(cow: Self, alloc: Allocator) void {
                        if (!cow.is_owned) return;
                        alloc.destroy(cow.pointer);
                    }
                },
                .Slice => struct {
                    fn f(cow: Self, alloc: Allocator) void {
                        if (!cow.is_owned) return;
                        alloc.free(cow.pointer);
                    }
                },
                else => unreachable,
            };
            Impl.f(self, allocator);
        }

        pub fn toBorrowed(self: Self) Self {
            return self.toBorrowedAs(Self.Pointer);
        }

        pub fn toBorrowedAs(self: Self, comptime NewPointer: type) Cow(NewPointer) {
            return Cow(NewPointer){
                .is_owned = false,
                .pointer = self.pointer,
            };
        }

        pub fn clone(self: *const Self, allocator: Allocator) Allocator.Error!Self {
            return self.cloneAs(allocator, Self.Pointer);
        }

        pub fn cloneAs(self: *const Self, allocator: Allocator, comptime NewPointer: type) Allocator.Error!Cow(NewPointer) {
            const Impl = switch (pointer_size) {
                .One => struct {
                    fn f(cow: *const Self, alloc: Allocator) Allocator.Error!Cow(NewPointer) {
                        const pointer = try alloc.create(Child);
                        pointer.* = cow.pointer.*;
                        return Cow(NewPointer){
                            .is_owned = true,
                            .pointer = pointer,
                        };
                    }
                },
                .Slice => struct {
                    fn f(cow: *const Self, alloc: Allocator) Allocator.Error!Cow(NewPointer) {
                        const pointer = try alloc.dupe(Child, cow.pointer);
                        return Cow(NewPointer){
                            .is_owned = true,
                            .pointer = pointer,
                        };
                    }
                },
                else => unreachable,
            };
            return Impl.f(self, allocator);
        }
    };
}

test "basic" {
    const allocator = std.testing.allocator;

    const s1 = "hello";

    const cow1 = borrowedCow(s1);
    defer cow1.deinit(allocator);
    try testing.expectEqualSlices(u8, cow1.pointer, "hello");
    try testing.expectEqual(cow1.is_owned, false);
    try testing.expectEqual(@TypeOf(cow1).Pointer, *const [s1.len:0]u8);
    try testing.expectEqual(@TypeOf(cow1).is_const, true);

    const cow2 = borrowedCowAs([]const u8, s1);
    defer cow2.deinit(allocator);
    try testing.expectEqualSlices(u8, cow2.pointer, "hello");
    try testing.expectEqual(cow2.is_owned, false);
    try testing.expectEqual(@TypeOf(cow2).Pointer, []const u8);
    try testing.expectEqual(@TypeOf(cow2).is_const, true);

    const s2 = try std.fmt.allocPrint(allocator, "{s} {s}", .{ s1, "kitty" });

    const cow3 = ownedCow(s2);
    defer cow3.deinit(allocator);
    try testing.expectEqualSlices(u8, cow3.pointer, "hello kitty");
    try testing.expectEqual(cow3.is_owned, true);
    try testing.expectEqual(@TypeOf(cow3).Pointer, []u8);
    try testing.expectEqual(@TypeOf(cow3).is_const, false);

    const s3 = try std.fmt.allocPrint(allocator, "{s} {s}", .{ s2, "yay" });

    const cow4 = ownedCowAs([]u8, s3);
    defer cow4.deinit(allocator);
    try testing.expectEqualSlices(u8, cow4.pointer, "hello kitty yay");
    try testing.expectEqual(cow4.is_owned, true);
    try testing.expectEqual(@TypeOf(cow4).Pointer, []u8);
    try testing.expectEqual(@TypeOf(cow4).is_const, false);

    const cow5 = cow4.toBorrowedAs([]const u8);
    defer cow5.deinit(allocator);
    try testing.expectEqualSlices(u8, cow5.pointer, "hello kitty yay");
    try testing.expectEqual(cow5.is_owned, false);
    try testing.expectEqual(@TypeOf(cow5).Pointer, []const u8);
    try testing.expectEqual(@TypeOf(cow5).is_const, true);

    const cow7 = try cow5.cloneAs(allocator, []u8);
    defer cow7.deinit(allocator);
    try testing.expectEqualSlices(u8, cow7.pointer, "hello kitty yay");
    try testing.expectEqual(cow7.is_owned, true);
    try testing.expectEqual(@TypeOf(cow7).Pointer, []u8);
    try testing.expectEqual(@TypeOf(cow7).is_const, false);

    const cow8 = cow7.toBorrowed();
    defer cow8.deinit(allocator);
    try testing.expectEqualSlices(u8, cow8.pointer, "hello kitty yay");
    try testing.expectEqual(cow8.is_owned, false);
    try testing.expectEqual(@TypeOf(cow8).Pointer, []u8);
    try testing.expectEqual(@TypeOf(cow8).is_const, false);

    const cow9 = try cow8.clone(allocator);
    defer cow9.deinit(allocator);
    try testing.expectEqualSlices(u8, cow9.pointer, "hello kitty yay");
    try testing.expectEqual(cow9.is_owned, true);
    try testing.expectEqual(@TypeOf(cow9).Pointer, []u8);
    try testing.expectEqual(@TypeOf(cow9).is_const, false);
}
