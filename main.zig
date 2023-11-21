const std = @import("std");
const ArrayList = std.ArrayList;

const LETTER_LIST = "JCPAOEIRHFBT";
const MAX_LENGTH = (1 << 12) * 12;

const Entry = struct {
    word: []u8,
    mask: u32,
    startsWith: u8,
    endsWith: u8,
};

const ShortestPathRecord = struct {
    words: ArrayList([]u8),
    newWord: ?[]u8,
    length: u8,

    fn init() ShortestPathRecord {
        return ShortestPathRecord{
            .words = ArrayList([]u8).init(std.heap.page_allocator),
            .newWord = null,
            .length = 0,
        };
    }

    fn deinit(self: ShortestPathRecord) void {
        self.words.deinit();
    }
};
fn shortestPathsCleanUp(paths: []ShortestPathRecord) void {
    for (paths) |*path| {
        path.words.deinit();
    }
}

fn entriesCleanUp(entries: []ArrayList(Entry)) void {
    for (entries) |*entry| {
        entry.*.deinit();
    }
}

fn getEntryFrom(word: []u8) !?Entry {
    var result: u32 = 0;
    var previousIndexOpt: ?u32 = null;
    for (word, 0..) |_, index| {
        const letter = word[index .. index + 1];
        const letterIndexOpt = std.mem.indexOf(u8, LETTER_LIST, letter);
        if (letterIndexOpt == null) {
            return null;
        }
        if (previousIndexOpt != null and (letterIndexOpt.? / 3 == previousIndexOpt.? / 3)) {
            return null;
        }
        result |= std.math.shl(u32, 1, letterIndexOpt.?);
        previousIndexOpt = @intCast(letterIndexOpt.?);
    }
    const firstLetterIndex: u8 = @intCast(std.mem.indexOf(u8, LETTER_LIST, word[0..1]).?);
    const lastLetterIndex: u8 = @intCast(std.mem.indexOf(u8, LETTER_LIST, word[word.len - 1 .. word.len]).?);
    const entry = Entry{
        .word = try std.mem.Allocator.dupe(std.heap.page_allocator, u8, word),
        .mask = result,
        .startsWith = firstLetterIndex,
        .endsWith = lastLetterIndex,
    };
    return entry;
}

fn findShortestPath(shortestPaths: []ShortestPathRecord, entries: []ArrayList(Entry)) !void {
    const startRange = MAX_LENGTH - 12;
    var step: ?u8 = null;
    const writer = std.io.getStdOut().writer();

    while (step == null) {
        for (shortestPaths) |*path| {
            if (path.*.newWord != null) {
                defer path.*.newWord = null;
                try path.words.append(path.*.newWord.?);
                path.*.length += 1;
            }
        }
        for (shortestPaths, 0..) |*path, index| {
            if (path.*.length == 0) {
                continue;
            }

            if (path.*.newWord != null) {
                continue;
            }

            const mask = index / 12;
            const endsWith = index % 12;
            const targetEntries = entries[endsWith];
            for (targetEntries.items) |*entry| {
                const newMask = mask | entry.*.mask;
                const newEndsWith = entry.*.endsWith;
                const newIndex = newMask * 12 + newEndsWith;
                const pathPtr = &shortestPaths[newIndex];
                if (pathPtr.*.length < path.length or (pathPtr.*.length == path.length and pathPtr.*.newWord != null)) {
                    pathPtr.*.words.clearRetainingCapacity();
                    try pathPtr.*.words.appendSlice(path.words.items);
                    pathPtr.*.newWord = entry.*.word;
                    pathPtr.*.length = @intCast(pathPtr.*.words.items.len);
                }

                if (newIndex > startRange) {
                    if (step == null) {
                        step = pathPtr.*.length + 1;
                        try writer.print("Total length: {}\n", .{step.?});
                    }

                    for (pathPtr.*.words.items) |word| {
                        try writer.print("{s} ", .{word});
                    }
                    try writer.print("{s}\n", .{pathPtr.*.newWord.?});
                }
            }
        }
    }
}

fn getAnswer(shortestPath: []ShortestPathRecord) ?ShortestPathRecord {
    const startRange = MAX_LENGTH - 12;
    for (startRange..MAX_LENGTH) |index| {
        if (shortestPath[index].length != 0) {
            return shortestPath[index];
        }
    }
    return null;
}

pub fn main() !void {
    // read lines from dictionary.txt
    var f = try std.fs.cwd().openFile("../dictionary.txt", .{});
    defer f.close();
    var bufferReader = std.io.bufferedReader(f.reader());
    var inStream = bufferReader.reader();
    const writer = std.io.getStdOut().writer();

    var buf: [1024]u8 = undefined;

    var shortestPaths: [MAX_LENGTH]ShortestPathRecord = undefined;
    for (&shortestPaths) |*path| {
        path.* = ShortestPathRecord.init();
    }

    var entries: [12]ArrayList(Entry) = undefined;
    for (&entries) |*entry| {
        entry.* = ArrayList(Entry).init(std.heap.page_allocator);
    }
    defer entriesCleanUp(entries[0..]);

    // read words from dictionary.txt and encode words
    try writer.print("Pre-processing dictionary...\n", .{});
    while (true) {
        const wordOpt = try inStream.readUntilDelimiterOrEof(&buf, '\n');
        if (wordOpt == null) {
            break;
        }
        const word = wordOpt.?;
        if (word.len <= 2) {
            continue;
        }

        const entryOpt = try getEntryFrom(word);
        if (entryOpt == null) {
            continue;
        }
        var entry = entryOpt.?;
        try entries[entry.startsWith].append(entry);
        const index = entry.mask * 12 + entry.endsWith;
        shortestPaths[index].newWord = entry.word;
    }

    // find shortest path and print
    try writer.print("Finding shortest path...\n", .{});
    try findShortestPath(&shortestPaths, &entries);
}
