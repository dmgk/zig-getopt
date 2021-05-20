# Minimal POSIX getopt(3) implementation in Zig

This is a minimal, allocation-free getopt(3) implementation with [POSIX-conforming](http://pubs.opengroup.org/onlinepubs/9699919799/functions/getopt.html) argument parsing semantics.

## Example

```zig
const std = @import("std");
const debug = std.debug;
const getopt = @import("getopt.zig");

pub fn main() void {
    var arg: []const u8 = undefined;
    var verbose: bool = false;

    var opts = getopt.getopt("a:vh");

    while (opts.next()) |maybe_opt| {
        if (maybe_opt) |opt| {
            switch (opt.opt) {
                'a' => {
                    arg = opt.arg.?;
                    debug.print("arg = {s}\n", .{arg});
                },
                'v' => {
                    verbose = true;
                    debug.print("verbose = {}\n", .{verbose});
                },
                'h' => debug.print(
                    \\usage: example [-a arg] [-hv]
                    \\
                , .{}),
                else => unreachable,
            }
        } else break;
    } else |err| {
        switch (err) {
            getopt.Error.InvalidOption => debug.print("invalid option: {c}\n", .{opts.optopt}),
            getopt.Error.MissingArgument => debug.print("option requires an argument: {c}\n", .{opts.optopt}),
        }
    }

    debug.print("remaining args: {s}\n", .{opts.args()});
}
```

```
$ zig run example.zig -- -hv -a42 foo bar
usage: example [-a arg] [-hv]
verbose = true
arg = 42
remaining args: { foo, bar }
```
