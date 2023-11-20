const std = @import("std");
const ascii = std.ascii;
const mem = std.mem;
const os = std.os;
const expect = std.testing.expect;

/// Parsed option struct.
pub const Option = struct {
    /// Option character.
    opt: u8,

    /// Option argument, if any.
    arg: ?[:0]const u8 = null,
};

pub const Error = error{ InvalidOption, MissingArgument };

pub const OptionsIterator = struct {
    argv: [][*:0]const u8,
    opts: []const u8,

    /// Index of the current element of the argv vector.
    optind: usize = 1,

    optpos: usize = 1,

    /// Current option character.
    optopt: u8 = undefined,

    pub fn next(self: *OptionsIterator) Error!?Option {
        if (self.optind == self.argv.len)
            return null;

        const arg = self.argv[self.optind];

        if (mem.eql(u8, mem.span(arg), "--")) {
            self.optind += 1;
            return null;
        }

        if (arg[0] != '-' or !ascii.isAlphanumeric(arg[1]))
            return null;

        self.optopt = arg[self.optpos];

        const maybe_idx = mem.indexOfScalar(u8, self.opts, self.optopt);
        if (maybe_idx) |idx| {
            if (idx < self.opts.len - 1 and self.opts[idx + 1] == ':') {
                if (arg[self.optpos + 1] != 0) {
                    const res = Option{
                        .opt = self.optopt,
                        .arg = mem.sliceTo(arg + self.optpos + 1, 0),
                    };
                    self.optind += 1;
                    self.optpos = 1;
                    return res;
                } else if (self.optind + 1 < self.argv.len) {
                    const res = Option{
                        .opt = self.optopt,
                        .arg = mem.sliceTo(self.argv[self.optind + 1], 0),
                    };
                    self.optind += 2;
                    self.optpos = 1;
                    return res;
                } else return Error.MissingArgument;
            } else {
                self.optpos += 1;
                if (arg[self.optpos] == 0) {
                    self.optind += 1;
                    self.optpos = 1;
                }
                return Option{ .opt = self.optopt };
            }
        } else return Error.InvalidOption;
    }

    /// Return remaining arguments, if any.
    pub fn args(self: *OptionsIterator) ?[][*:0]const u8 {
        if (self.optind < self.argv.len)
            return self.argv[self.optind..]
        else
            return null;
    }
};

fn getoptArgv(argv: [][*:0]const u8, optstring: []const u8) OptionsIterator {
    return OptionsIterator{
        .argv = argv,
        .opts = optstring,
    };
}

/// Parse os.argv according to the optstring.
pub fn getopt(optstring: []const u8) OptionsIterator {
    // https://github.com/ziglang/zig/issues/8808
    const argv: [][*:0]const u8 = os.argv;
    return getoptArgv(argv, optstring);
}

test "no args separate" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-a",
        "-b",
    };

    const expected = [_]Option{
        .{ .opt = 'a' },
        .{ .opt = 'b' },
    };

    var opts = getoptArgv(&argv, "ab");

    var i: usize = 0;
    while (try opts.next()) |opt| : (i += 1) {
        try expect(opt.opt == expected[i].opt);
        if (opt.arg != null and expected[i].arg != null) {
            try expect(mem.eql(u8, opt.arg.?, expected[i].arg.?));
        } else {
            try expect(opt.arg == null and expected[i].arg == null);
        }
    }

    try expect(opts.args() == null);
}

test "no args joined" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-abc",
    };

    const expected = [_]Option{
        .{ .opt = 'a' },
        .{ .opt = 'b' },
        .{ .opt = 'c' },
    };

    var opts = getoptArgv(&argv, "abc");

    var i: usize = 0;
    while (try opts.next()) |opt| : (i += 1) {
        try expect(opt.opt == expected[i].opt);
        if (opt.arg != null and expected[i].arg != null) {
            try expect(mem.eql(u8, opt.arg.?, expected[i].arg.?));
        } else {
            try expect(opt.arg == null and expected[i].arg == null);
        }
    }
}

test "with args separate" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-a10",
        "-b",
        "-c",
        "42",
    };

    const expected = [_]Option{
        .{ .opt = 'a', .arg = "10" },
        .{ .opt = 'b' },
        .{ .opt = 'c', .arg = "42" },
    };

    var opts = getoptArgv(&argv, "a:bc:");

    var i: usize = 0;
    while (try opts.next()) |opt| : (i += 1) {
        try expect(opt.opt == expected[i].opt);
        if (opt.arg != null and expected[i].arg != null) {
            try expect(mem.eql(u8, opt.arg.?, expected[i].arg.?));
        } else {
            try expect(opt.arg == null and expected[i].arg == null);
        }
    }
}

test "with args joined" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-a10",
        "-bc",
        "42",
    };

    const expected = [_]Option{
        .{ .opt = 'a', .arg = "10" },
        .{ .opt = 'b' },
        .{ .opt = 'c', .arg = "42" },
    };

    var opts = getoptArgv(&argv, "a:bc:");

    var i: usize = 0;
    while (try opts.next()) |opt| : (i += 1) {
        try expect(opt.opt == expected[i].opt);
        if (opt.arg != null and expected[i].arg != null) {
            try expect(mem.eql(u8, opt.arg.?, expected[i].arg.?));
        } else {
            try expect(opt.arg == null and expected[i].arg == null);
        }
    }
}

test "invalid option" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-az",
    };

    var opts = getoptArgv(&argv, "a");

    // -a is ok
    try expect((try opts.next()).?.opt == 'a');

    const maybe_opt = opts.next();
    if (maybe_opt) |_| {
        unreachable;
    } else |err| {
        try expect(err == Error.InvalidOption);
        try expect(opts.optopt == 'z');
    }
}

test "missing argument" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-az",
    };

    var opts = getoptArgv(&argv, "az:");

    // -a is ok
    try expect((try opts.next()).?.opt == 'a');

    const maybe_opt = opts.next();
    if (maybe_opt) |_| {
        unreachable;
    } else |err| {
        try expect(err == Error.MissingArgument);
        try expect(opts.optopt == 'z');
    }
}

test "positional args" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-abc10",
        "-d",
        "foo",
        "bar",
    };

    const expected = [_]Option{
        .{ .opt = 'a' },
        .{ .opt = 'b' },
        .{ .opt = 'c', .arg = "10" },
        .{ .opt = 'd' },
    };

    var opts = getoptArgv(&argv, "abc:d");

    var i: usize = 0;
    while (try opts.next()) |opt| : (i += 1) {
        try expect(opt.opt == expected[i].opt);
        if (opt.arg != null and expected[i].arg != null) {
            try expect(mem.eql(u8, opt.arg.?, expected[i].arg.?));
        } else {
            try expect(opt.arg == null and expected[i].arg == null);
        }
    }

    try expect(mem.eql([*:0]const u8, opts.args().?, &[_][*:0]const u8{ "foo", "bar" }));
}

test "positional args with separator" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-ab",
        "--",
        "foo",
        "bar",
    };

    const expected = [_]Option{
        .{ .opt = 'a' },
        .{ .opt = 'b' },
    };

    var opts = getoptArgv(&argv, "ab");

    var i: usize = 0;
    while (try opts.next()) |opt| : (i += 1) {
        try expect(opt.opt == expected[i].opt);
        if (opt.arg != null and expected[i].arg != null) {
            try expect(mem.eql(u8, opt.arg.?, expected[i].arg.?));
        } else {
            try expect(opt.arg == null and expected[i].arg == null);
        }
    }

    try expect(mem.eql([*:0]const u8, opts.args().?, &[_][*:0]const u8{ "foo", "bar" }));
}

test "separate optarg is sentinel-terminated" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-a10",
    };

    var opts = getoptArgv(&argv, "a:bc:");

    const arg = (try opts.next()).?.arg.?;
    // If arg is not sentinel-terminated, this panics with index OOB
    try expect(arg[arg.len] == 0);
}

test "separate optarg is sentinel-terminated" {
    var argv = [_][*:0]const u8{
        "getopt",
        "-c",
        "42",
    };

    var opts = getoptArgv(&argv, "a:bc:");

    const arg = (try opts.next()).?.arg.?;
    // If arg is not sentinel-terminated, this panics with index OOB
    try expect(arg[arg.len] == 0);
}
