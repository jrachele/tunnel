const std = @import("std");

pub fn WrapAroundArray(
    comptime T: type,
) type {
    return struct {
        buf: []T,
        cursor: usize,

        const Self = @This();

        /// Init the wrap around array with a slice
        pub fn init(buf: []T) Self {
            if (buf.len == 0) {
                std.debug.panic("Cannot create wrap around array from empty slice!", .{});
            }
            return .{
                .buf = buf,
                .cursor = 0,
            };
        }

        /// Gets the first element in the wrap-around-array, semantically
        /// This is not the first element in the underlying buffer.
        pub fn first(self: *const Self) T {
            if (self.cursor >= self.buf.len) {
                std.debug.panic("Cursor exceeds buffer length!", .{});
            }

            return self.buf[self.cursor];
        }

        /// Gets the last element in the wrap-around-array, semantically
        /// This is not the last element in the underlying buffer.
        pub fn last(self: *const Self) T {
            if (self.cursor >= self.buf.len) {
                std.debug.panic("Cursor exceeds buffer length!", .{});
            }

            if (self.cursor == 0) {
                return self.buf[self.buf.len - 1];
            }

            return self.buf[self.cursor - 1];
        }

        /// Replace the current element with `elem` then
        /// advance the cursor forward
        pub fn advanceAndReplace(self: *Self, elem: T) void {
            if (self.cursor >= self.buf.len) {
                std.debug.panic("Cursor exceeds buffer length!", .{});
            }

            self.buf[self.cursor] = elem;
            self.cursor = (self.cursor + 1) % self.buf.len;
        }

        pub fn iter(self: *const Self) Iterator {
            return .{ .wrap_around_array = self };
        }

        const Iterator = struct {
            index: ?usize = null,
            wrap_around_array: *const Self,

            pub fn next(iterator: *Iterator) ?T {
                if (iterator.wrap_around_array.buf.len == 0) return null;

                if (iterator.index) |index| {
                    if (index == iterator.wrap_around_array.cursor) {
                        // We have reached the end
                        return null;
                    }
                    const ret = iterator.wrap_around_array.buf[index];
                    iterator.index = (index + 1) % iterator.wrap_around_array.buf.len;
                    return ret;
                } else {
                    const ret = iterator.wrap_around_array.first();
                    iterator.index = (iterator.wrap_around_array.cursor + 1) % iterator.wrap_around_array.buf.len;

                    return ret;
                }
            }
        };
    };
}

test "wrap_around_array iterate like array" {
    var buf = [_]i32{ 2, 4, 6, 8, 10, 12 };
    const arr: WrapAroundArray(i32) = .init(&buf);
    // Test forward iteration
    var it = arr.iter();
    var i: usize = 0;
    while (it.next()) |e| {
        try std.testing.expectEqual(e, buf[i]);
        i += 1;
    }

    try std.testing.expectEqual(arr.first(), 2);
    try std.testing.expectEqual(arr.last(), 12);
}

test "wrap_around_array advanceAndReplace" {
    var buf = [_]i32{ 2, 4, 6, 8, 10, 12 };
    var arr: WrapAroundArray(i32) = .init(&buf);

    arr.advanceAndReplace(1337);

    try std.testing.expectEqual(arr.cursor, 1);
    try std.testing.expectEqual(arr.first(), 4);
    try std.testing.expectEqual(arr.last(), 1337);
    const expected_iter_results = [_]i32{ 4, 6, 8, 10, 12, 1337 };

    var it = arr.iter();
    var i: usize = 0;
    while (it.next()) |e| {
        try std.testing.expectEqual(e, expected_iter_results[i]);
        i += 1;
    }
}
