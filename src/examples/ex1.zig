const std = @import("std");
const debug = std.debug;
const cow = @import("cow");
const Cow = cow.Cow;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const s1 = "hello";

    const c1: Cow(*const [5:0]u8) = cow.borrowedCow(s1);
    defer c1.deinit(allocator);

    const s2 = try std.fmt.allocPrint(allocator, "{s} world", .{c1.pointer});

    const c2: Cow([]u8) = cow.ownedCow(s2);
    defer c2.deinit(allocator);

    const c3: Cow([]u8) = try c2.clone(allocator);
    defer c3.deinit(allocator);

    const c4: Cow([]u8) = c3.toBorrowed();
    defer c4.deinit(allocator);

    debug.print("{s}\n", .{c4.pointer});
}
