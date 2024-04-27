const std = @import("std");
const debug = std.debug;
const cow = @import("cow");
const Cow = cow.Cow;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const s1 = "hello";

    const c1: Cow([]const u8) = cow.borrowedCowAs([]const u8, s1);
    defer c1.deinit(allocator);

    const s2 = try std.fmt.allocPrint(allocator, "{s} kitty", .{c1.pointer});

    const c2: Cow([]const u8) = cow.ownedCowAs([]const u8, s2);
    defer c2.deinit(allocator);

    const c3: Cow([]u8) = try c2.cloneAs(allocator, []u8);
    defer c3.deinit(allocator);

    const c4: Cow([]const u8) = c3.toBorrowedAs([]const u8);
    defer c4.deinit(allocator);

    debug.print("{s}\n", .{c4.pointer});
}
