# zig-cow
A copy-on-write library in Zig.

[Copy-on-write](https://en.wikipedia.org/wiki/Copy-on-write) is a strategy to optimize memory usage, in this context, by avoiding unnecessary heap allocation until it's actually needed.

## Goal

- To avoid unnecessary heap allocation.
- To prevent double freeing.
- To keep the abstraction as minimal as possible.

## Installation

To add `zig-cow` to your `build.zig.zon`:

```
.{
    .name = "<YOUR PROGRAM>",
    .version = "0.0.0",
    .dependencies = .{
        .cow = .{
            .url = "https://github.com/rueyxian/zig-cow/archive/refs/tags/v0.0.1.tar.gz",
            .hash = "<CORRECT HASH WILL BE SUGGESTED>",
        },
    },
}
```

To add `zig-cow` to your `build.zig`:

```
const dep_cow = b.dependency("cow", .{
    .target = target,
    .optimize = optimize,
});
exe.addModule("cow", dep_cow("cow"));
```

## Example

To run an example:

```
$ zig build <EXAMPLE>
```

where `<EXAMPLE>` is one of:

- `example_ex1`
- `example_ex2`

```zig
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
```

Output:

```
hello world
```