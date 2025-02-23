const Tunnel = @This();

const std = @import("std");
const raylib = @import("raylib");

const constants = @import("constants.zig");
const util = @import("util.zig");

const Player = @import("player.zig");
const WrapAroundArray = @import("wrap_around_array.zig").WrapAroundArray;

const Segment = struct {
    pos: u16 = 0,
    width: u16 = 0,
};

const SEGMENT_COUNT = 200;
const MIN_SEGMENT_WIDTH = Player.SIZE * 4;
const MAX_SEGMENT_WIDTH = Player.SIZE * 16;
const MAX_SEGMENT_WIDTH_VARIABILITY = 8;
const MAX_SEGMENT_POS_VARIABILITY = Player.SIZE / 2;
const SEGMENT_HEIGHT = 5;

allocator: std.mem.Allocator,
segmentBuf: []Segment,
segments: WrapAroundArray(Segment),

pub fn init(allocator: std.mem.Allocator) !Tunnel {
    const segmentBuf = try allocator.alloc(Segment, SEGMENT_COUNT);

    // The first segment will always start in the middle of the screen, with the max width
    var segment = Segment{
        .pos = constants.screenWidth / 2,
        .width = MAX_SEGMENT_WIDTH,
    };
    segmentBuf[0] = segment;
    for (1..SEGMENT_COUNT) |i| {
        segmentBuf[i] = generateRandomSegment(segment);
        segment = segmentBuf[i];
    }

    const segments = WrapAroundArray(Segment).init(segmentBuf);

    return Tunnel{
        .allocator = allocator,
        .segmentBuf = segmentBuf,
        .segments = segments,
    };
}

pub fn deinit(tunnel: *Tunnel) void {
    tunnel.allocator.free(tunnel.segmentBuf);
}

pub fn draw(tunnel: *const Tunnel) void {
    // Iterate through the segments
    var it = tunnel.segments.iter();
    // Start the tunnel where the player begins
    var i: i32 = @intFromFloat(constants.screenHeight);
    while (it.next()) |segment| {
        raylib.drawRectangle(0, i, segment.pos - @divFloor(segment.width, 2), SEGMENT_HEIGHT, raylib.Color.fromInt(constants.tunnelColor));
        raylib.drawRectangle(segment.pos + @divFloor(segment.width, 2), i, constants.screenWidth - segment.pos + @divFloor(segment.width, 2), SEGMENT_HEIGHT, raylib.Color.fromInt(constants.tunnelColor));
        i -= SEGMENT_HEIGHT;
    }
}

pub fn advance(tunnel: *Tunnel) void {
    tunnel.segments.advanceAndReplace(generateRandomSegment(tunnel.segments.last()));
}

pub fn getCollisionPoints(tunnel: *const Tunnel, allocator: std.mem.Allocator) ![]raylib.Vector2 {
    const initial_segment_index: usize = (constants.screenHeight - @as(usize, Player.SCREEN_Y)) / SEGMENT_HEIGHT;
    const final_segment_index: usize = initial_segment_index + (Player.SIZE / SEGMENT_HEIGHT);
    var it = tunnel.segments.iter();
    var i: usize = 0;
    var arr = std.ArrayList(raylib.Vector2).init(allocator);
    while (it.next()) |segment| {
        if (i >= initial_segment_index) {
            // Left collision
            try arr.append(.{ .x = @as(f32, @floatFromInt(segment.pos - @divFloor(segment.width, 2))), .y = @as(f32, @floatFromInt(constants.screenHeight - (i * SEGMENT_HEIGHT))) });
            // Right collision
            try arr.append(.{ .x = @as(f32, @floatFromInt(segment.pos + @divFloor(segment.width, 2))), .y = @as(f32, @floatFromInt(constants.screenHeight - (i * SEGMENT_HEIGHT))) });
        }
        if (i > final_segment_index) break;
        i += 1;
    }

    return try arr.toOwnedSlice();
}

fn generateRandomSegment(reference: Segment) Segment {
    const width_variance = raylib.getRandomValue(-MAX_SEGMENT_WIDTH_VARIABILITY, MAX_SEGMENT_WIDTH_VARIABILITY);
    const pos_variance = raylib.getRandomValue(-MAX_SEGMENT_POS_VARIABILITY, MAX_SEGMENT_POS_VARIABILITY);

    const width = util.clamp(i32, @as(i32, @intCast(reference.width)) + width_variance, MIN_SEGMENT_WIDTH, MAX_SEGMENT_WIDTH);
    const pos = util.clamp(i32, @as(i32, @intCast(reference.pos)) + pos_variance, @divFloor(width, 2), constants.screenWidth - @divFloor(width, 2));
    return Segment{
        .pos = @as(u16, @intCast(pos)),
        .width = @as(u16, @intCast(width)),
    };
}

test "tunnel" {
    const tunnel = Tunnel.init();
    std.debug.print("{}\n", .{tunnel});
}
