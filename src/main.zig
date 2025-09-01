// mdu — fast disk usage scanner
// licensed under GPLv3+

const std = @import("std");
const usage = @embedFile("usage.txt");
pub const VERSION = "1.1.1";


/// Windows terminal size
pub const winsize = struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

/// Platform-specific helpers
fn getWinsizeLinux() ?winsize {
    var ws: winsize = undefined;
    const TIOCGWINSZ: c_ulong = 0x5413;
    if (std.c.ioctl(std.c.STDOUT_FILENO, TIOCGWINSZ, &ws) < 0) {
        return null;
    }
    return ws;
}

fn getWinsizeBSD() ?winsize {
    var ws: winsize = undefined;
    const TIOCGWINSZ: c_ulong = 0x40087468; // macOS + FreeBSD
    if (std.c.ioctl(std.c.STDOUT_FILENO, TIOCGWINSZ, &ws) < 0) {
        return null;
    }
    return ws;
}

fn getWinsizeWindows() ?winsize {
    const kernel32 = @cImport({
        @cInclude("windows.h");
    });

    var info: kernel32.CONSOLE_SCREEN_BUFFER_INFO = undefined;
    const h = kernel32.GetStdHandle(kernel32.STD_OUTPUT_HANDLE);
    if (kernel32.GetConsoleScreenBufferInfo(h, &info) == 0) {
        return null;
    }

    return winsize{
        .ws_row = @intCast(info.srWindow.Bottom - info.srWindow.Top + 1),
        .ws_col = @intCast(info.srWindow.Right - info.srWindow.Left + 1),
        .ws_xpixel = 0,
        .ws_ypixel = 0,
    };
}

/// Terminal size getter
pub fn getTerminalSize() ?winsize {
    return switch (@import("builtin").os.tag) {
        .linux => getWinsizeLinux(),
        .macos, .freebsd => getWinsizeBSD(),
        .windows => getWinsizeWindows(),
        else => null,
    };
}

/// system info
const TargetInfo = struct {
    os: []const u8,
    arch: []const u8,

    pub fn init() TargetInfo {
        const target = @import("builtin").target;

        const os = switch (target.os.tag) {
            .windows => "Windows",
            .linux => "Linux",
            .macos => "macOS",
            .freebsd => "FreeBSD",
            else => "Unknown",
        };

        const arch = switch (target.cpu.arch) {
            .x86_64 => "x86_64",
            .aarch64 => "aarch64",
            else => "Unknown",
        };

        return TargetInfo{ .os = os, .arch = arch };
    }
};

const ParsedArgs = struct {
    opts: OPTIONS,
    exclude: std.ArrayList([]const u8),
};

const OPTIONS = struct {
    verbose: bool = false,
    quiet: bool = false,
    help: bool = false,
    version: bool = false,
};

/// Parse passed arguments
fn parseArgs(args: []const []const u8, allocator: std.mem.Allocator) !ParsedArgs {
    var opts = OPTIONS{};
    var exclude = std.ArrayList([]const u8).initCapacity(allocator, 1) catch unreachable;

    for (args[1..]) |arg| {
        if (std.mem.startsWith(u8, arg, "-ex=")) {
            try exclude.append(allocator, arg[4..]);
            continue;
        }

        if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            opts.verbose = true;
        } else if (std.mem.eql(u8, arg, "-q") or std.mem.eql(u8, arg, "--quiet")) {
            opts.quiet = true;
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            opts.help = true;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "--v")) {
            opts.version = true;
        } else {
            if (std.mem.eql(u8, arg, args[0])) continue;
            if (std.mem.eql(u8, arg, args[1])) continue;

            return error.UnknownOption;
        }
    }

    return ParsedArgs{ .opts = opts, .exclude = exclude };
}

/// Main struct managing threads and counts
const MDU = struct {
    allocator: std.mem.Allocator,
    pool: std.Thread.Pool = undefined,
    wg: std.Thread.WaitGroup = .{},
    dirs_count: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    files_count: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    size: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    ws: winsize = undefined,

    pub fn init(allocator: std.mem.Allocator) MDU {
        return MDU{ .allocator = allocator };
    }

    /// Deinitialize pool
    pub fn deinit(self: *MDU) void {
        self.pool.deinit();
    }

    /// Start directory traversal
    pub fn cycle(self: *MDU, base_path: []const u8, exs: []const []const u8, opts: OPTIONS) !void {
        // Init thread pool with optimal thread count
        const cpu_count = std.Thread.getCpuCount() catch 8;
        try self.pool.init(.{
            .allocator = self.allocator,
            .n_jobs = @min(cpu_count * 2, 32), // Cap at 32 threads to prevent overhead
        });

        if (getTerminalSize()) |ws| {
            self.ws = ws;
        } else {
            // Default fallback size
            self.ws = winsize{ .ws_row = 24, .ws_col = 80, .ws_xpixel = 0, .ws_ypixel = 0 };
        }

        // Spawn root directory
        const root = try self.allocator.dupe(u8, base_path);
        self.pool.spawnWg(&self.wg, processDir, .{ self, root, exs, opts });
        // Wait for pool to finish before exiting
        self.wg.wait();
    }
};

/// Worker function; spawns recursively
fn processDir(self: *MDU, path: []u8, exs: []const []const u8, opts: OPTIONS) void {
    defer self.allocator.free(path);

    var dir = std.fs.cwd().openDir(path, .{
        .access_sub_paths = true,
        .iterate = true,
    }) catch return;
    defer dir.close();

    var local_dirs: usize = 0; // Count self
    local_dirs += 1;
    var local_files: usize = 0;
    var local_size: u64 = 0;

    var it = dir.iterate();
    while (it.next() catch null) |entry| {
        if (entry.kind == .directory) {
            // Inline exclusion check for directory names
            var skip = false;
            for (exs) |ex| {
                if (std.mem.eql(u8, entry.name, ex)) {
                    skip = true;
                    break;
                }
            }
            if (skip) continue;

            const full_path = std.fs.path.join(self.allocator, &.{ path, entry.name }) catch continue;

            // Check full path exclusions
            for (exs) |ex| {
                if (std.mem.eql(u8, full_path, ex)) {
                    self.allocator.free(full_path);
                    skip = true;
                    break;
                }
            }
            if (skip) continue;

            // Spawn child directory
            self.pool.spawnWg(&self.wg, processDir, .{ self, full_path, exs, opts });
        } else {
            // Process file
            const st = dir.statFile(entry.name) catch continue;
            local_files += 1;
            local_size += st.size;

            // Hot print if verbose - optimized for less allocations
            if (opts.verbose) {
                var path_buf: [std.fs.max_path_bytes]u8 = undefined;
                const full_path = std.fmt.bufPrint(&path_buf, "{s}{c}{s}", .{ path, std.fs.path.sep, entry.name }) catch continue;

                var size_buf: [32]u8 = undefined;
                const size_str = humanSize(&size_buf, st.size) catch {
                    const fallback = std.fmt.bufPrint(&size_buf, "{d}", .{st.size}) catch continue;
                    std.debug.print("{s}\n", .{fallback});
                    continue;
                };

                const term_cols = self.ws.ws_col;
                const size_col_width = @max(size_str.len, 8);
                const padding = 1;
                const available = if (term_cols > (size_col_width + padding))
                    term_cols - (size_col_width + padding)
                else
                    full_path.len;

                const truncated = full_path[0..@min(full_path.len, available)];
                std.debug.print("{s:<8} {s}\n", .{ size_str, truncated });
            }
        }
    }

    // Batch update counts for better cache locality
    _ = self.dirs_count.fetchAdd(local_dirs, .monotonic);
    _ = self.files_count.fetchAdd(local_files, .monotonic);
    _ = self.size.fetchAdd(local_size, .monotonic);
}

/// Main entry
pub fn main() !void {
    // Init at compile-time
    const target = TargetInfo.init();

    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("{s}", .{usage});
        std.process.exit(1);
    }

    const path = args[1];
    var parsed = parseArgs(args, allocator) catch |err| {
        std.debug.print("[ERROR]: {s}\n\n{s}", .{ @errorName(err), usage });
        std.process.exit(1);
    };
    defer parsed.exclude.deinit(allocator);

    const opts = parsed.opts;
    const exclude = parsed.exclude;

    if (opts.help) {
        std.debug.print("{s}", .{usage});
        std.process.exit(0);
    }

    if (opts.version) {
        std.debug.print("version: {s} [{s}/{s}]\n", .{ VERSION, target.os, target.arch });
        std.process.exit(0);
    }

    var mdu = MDU.init(allocator);
    defer mdu.deinit();

    try mdu.cycle(path, exclude.items, opts);

    const size = mdu.size.load(.monotonic);
    var buf_dirs: [32]u8 = undefined;
    var buf_files: [32]u8 = undefined;
    var buf_size: [32]u8 = undefined;
    var buf_mb: [64]u8 = undefined;

    std.debug.print(
        \\
        \\| Entry        | {s}
        \\| Directories  | {s}
        \\| Files        | {s}
        \\| Size         | {s} ({s}) 
        \\
    , .{
        path,
        try commaFormat(&buf_dirs, mdu.dirs_count.load(.monotonic)),
        try commaFormat(&buf_files, mdu.files_count.load(.monotonic)),
        try commaFormat(&buf_size, size),
        try humanSize(&buf_mb, size),
    });
}

fn humanSize(buf: []u8, bytes: u64) ![]u8 {
    const KB: f64 = 1024.0;
    const MB = KB * 1024.0;
    const GB = MB * 1024.0;
    const TB = GB * 1024.0;

    const fbytes = @as(f64, @floatFromInt(bytes));

    if (bytes >= @as(u64, @intFromFloat(TB)))
        return std.fmt.bufPrint(buf, "{d:.2}TB", .{fbytes / TB});
    if (bytes >= @as(u64, @intFromFloat(GB)))
        return std.fmt.bufPrint(buf, "{d:.2}GB", .{fbytes / GB});
    if (bytes >= @as(u64, @intFromFloat(MB)))
        return std.fmt.bufPrint(buf, "{d:.2}MB", .{fbytes / MB});
    if (bytes >= 1024)
        return std.fmt.bufPrint(buf, "{d:.2}KB", .{fbytes / KB});
    return std.fmt.bufPrint(buf, "{d}B", .{bytes});
}

fn commaFormat(buf: []u8, value: u64) ![]u8 {
    if (value == 0) return std.fmt.bufPrint(buf, "0", .{});

    // Count digits to optimize buffer usage
    var temp = value;
    var digit_count: usize = 0;
    while (temp > 0) {
        temp /= 10;
        digit_count += 1;
    }

    const comma_count = (digit_count - 1) / 3;
    const total_len = digit_count + comma_count;

    // Format from right to left
    var pos = total_len;
    temp = value;
    var digits_since_comma: usize = 0;

    while (temp > 0) {
        if (digits_since_comma == 3) {
            pos -= 1;
            buf[pos] = ',';
            digits_since_comma = 0;
        }
        pos -= 1;
        buf[pos] = '0' + @as(u8, @intCast(temp % 10));
        temp /= 10;
        digits_since_comma += 1;
    }

    return buf[0..total_len];
}
