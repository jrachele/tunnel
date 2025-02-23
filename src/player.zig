const Player = @This();

const raylib = @import("raylib");
const std = @import("std");

const constants = @import("constants.zig");

pub const SIZE = 30;
pub const MAX_ANGLE = std.math.pi / 6.0; // 30 degree angle max
pub const ANGLE_EPSILON = 0.01;
pub const SCREEN_Y = constants.screenHeight * 0.9;

pos: f32 = constants.screenWidth / 2.0,
angle: f32 = 0,
speed: f32 = 500,
tilt_speed: f32 = 5,
triangle: [3]raylib.Vector2 = undefined,

pub fn update(player: *Player) void {
    // Draw a triangle, and rotate it based on the player rotation
    const vertices = [3]@Vector(2, f32){
        .{ 1, 0 },
        .{ 0, 2 },
        .{ -1, 0 },
    };

    var rotated_points: [3]@Vector(2, f32) = vertices;

    if (player.angle != 0) {
        const cos_angle = std.math.cos(player.angle);
        const sin_angle = std.math.sin(player.angle);

        // Rotate about the centroid
        const center_x = (vertices[0][0] + vertices[1][0] + vertices[2][0]) / 3;
        const center_y = (vertices[0][1] + vertices[1][1] + vertices[2][1]) / 3;

        for (vertices, 0..) |vertex, i| {
            const x = vertex[0];
            const y = vertex[1];

            const translated_x = x - center_x;
            const translated_y = y - center_y;

            const rotated_x = (translated_x * cos_angle) - (translated_y * sin_angle);
            const rotated_y = (translated_x * sin_angle) + (translated_y * cos_angle);

            const final_x = rotated_x + center_x;
            const final_y = rotated_y + center_y;
            rotated_points[i][0] = final_x;
            rotated_points[i][1] = final_y;
        }
    }
    // Update the rotated points to adapt to player size
    for (&rotated_points) |*p| {
        const s: @Vector(2, f32) = @splat(Player.SIZE / 2);
        p.* *= s;
    }

    player.triangle[0] = raylib.Vector2{ .x = player.pos + rotated_points[0][0], .y = Player.SCREEN_Y - rotated_points[0][1] };
    player.triangle[1] = raylib.Vector2{ .x = player.pos + rotated_points[1][0], .y = Player.SCREEN_Y - rotated_points[1][1] };
    player.triangle[2] = raylib.Vector2{ .x = player.pos + rotated_points[2][0], .y = Player.SCREEN_Y - rotated_points[2][1] };
}

pub fn draw(player: *const Player) void {
    raylib.drawTriangle(
        player.triangle[0],
        player.triangle[1],
        player.triangle[2],
        raylib.Color.fromInt(constants.playerColor),
    );
}
