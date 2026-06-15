const std = @import("std");
const debug = std.debug;
const getopt = @import("getopt.zig");

pub fn main(init: std.process.Init) void {
    var arg: []const u8 = undefined;
    var verbose: bool = false;

    var opts = getopt.getopt(init.minimal.args, "a:vh");

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

    // TODO: zig 0.15 is unhappy with this returning [*:0]const u8 instead of []const u8,
    // so we can't just use a "{?s}" as prior to print the list.  We could re-evaluate the API,
    // but I'm also not sure if I want to do such changes.
    if (opts.args()) |args|
        for (args) |a|
            debug.print("- {s}\n", .{std.mem.span(a)});
}
