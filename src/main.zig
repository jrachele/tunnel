const builtin = @import("builtin");
const std = @import("std");
const raylib = @import("raylib");

const constants = @import("constants.zig");
const util = @import("util.zig");

const Screen = enum { Title, Game, GameOver };

const Player = struct {
    pub const SIZE = 30;
    pub const MAX_ANGLE = std.math.pi / 6.0; // 30 degree angle max
    pub const ANGLE_EPSILON = 0.01;
    pub const SCREEN_Y = constants.screenHeight * 0.9;

    pos: f32 = constants.screenWidth / 2.0,
    angle: f32 = 0,
    speed: f32 = 500,
    tilt_speed: f32 = 5,

    fn draw(player: *const Player) void {
        // Draw a triangle, and rotate it based on the player rotation
        const vertices = [3]@Vector(2, f32){
            .{ 1, 0 },
            .{ 0, 2 },
            .{ -1, 0 },
        };

        // Rotate about the centroid
        const center_x = (vertices[0][0] + vertices[1][0] + vertices[2][0]) / 3;
        const center_y = (vertices[0][1] + vertices[1][1] + vertices[2][1]) / 3;

        const cos_angle = std.math.cos(player.angle);
        const sin_angle = std.math.sin(player.angle);

        var rotated_points: [3]@Vector(2, f32) = undefined;
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

        // Update the rotated points to adapt to player size
        for (&rotated_points) |*p| {
            const s: @Vector(2, f32) = @splat(Player.SIZE / 2);
            p.* *= s;
        }

        if (builtin.mode == .Debug and debug_info_enabled) {
            // Draw a debug box underneath the player
            raylib.drawRectangleRec(.{
                .x = player.pos - (Player.SIZE / 2),
                .y = Player.SCREEN_Y - Player.SIZE,
                .width = Player.SIZE,
                .height = Player.SIZE,
            }, .init(200, 122, 255, 100));
        }

        raylib.drawTriangle(
            raylib.Vector2{ .x = player.pos + rotated_points[0][0], .y = Player.SCREEN_Y - rotated_points[0][1] },
            raylib.Vector2{ .x = player.pos + rotated_points[1][0], .y = Player.SCREEN_Y - rotated_points[1][1] },
            raylib.Vector2{ .x = player.pos + rotated_points[2][0], .y = Player.SCREEN_Y - rotated_points[2][1] },
            raylib.Color.red,
        );
    }
};

const Tunnel = struct {
    const Segment = struct {
        pos: u4 = 0,
        width: u4 = 0,
    };

    segments: std.fifo.LinearFifo(Segment, .{ .Static = 256 }),

    // pub fn init() Tunnel {
    // }
    //
    // pub fn advance(tunnel: *Tunnel) void {
    //
    // }
};

const GameState = struct {
    screen: Screen,
    player: Player,
};

var debug_info_enabled: bool = false;

pub fn main() !void {
    raylib.initWindow(constants.screenWidth, constants.screenHeight, "Tunnel");
    defer raylib.closeWindow();

    raylib.setTargetFPS(300);
    var game_state = GameState{
        .screen = .Title,
        .player = .{},
    };

    while (!raylib.windowShouldClose()) {
        // Update
        update(&game_state);

        // Draw
        raylib.beginDrawing();
        draw(&game_state);
        raylib.endDrawing();
    }
}

fn update(game_state: *GameState) void {
    // Manage screens
    switch (game_state.screen) {
        .Title => {
            if (raylib.isKeyPressed(.space)) {
                game_state.screen = .Game;
            }
        },
        .Game => {
            if (raylib.isKeyDown(.left) or raylib.isKeyDown(.a)) {
                game_state.player.pos -= game_state.player.speed * raylib.getFrameTime();
                game_state.player.angle += game_state.player.tilt_speed * raylib.getFrameTime();
                if (game_state.player.angle > Player.MAX_ANGLE) {
                    game_state.player.angle = Player.MAX_ANGLE;
                }
            } else if (raylib.isKeyDown(.right) or raylib.isKeyDown(.d)) {
                game_state.player.pos += game_state.player.speed * raylib.getFrameTime();
                game_state.player.angle -= game_state.player.tilt_speed * raylib.getFrameTime();
                if (game_state.player.angle < -Player.MAX_ANGLE) {
                    game_state.player.angle = -Player.MAX_ANGLE;
                }
            } else {
                // Slowly interp the angle back up to 0
                if (std.math.approxEqAbs(f32, game_state.player.angle, 0, Player.ANGLE_EPSILON)) {
                    game_state.player.angle = 0;
                } else {
                    game_state.player.angle *= 0.95;
                }
            }

            if (raylib.isKeyPressed(.o)) {
                // Toggle debug information
                debug_info_enabled = !debug_info_enabled;
            }
        },
        .GameOver => {},
    }
}

fn draw(game_state: *GameState) void {
    raylib.clearBackground(raylib.Color.ray_white);

    switch (game_state.screen) {
        .Title => {
            util.drawCenteredX("TUNNEL", constants.screenHeight / 2, constants.screenFontSize, raylib.Color.black);
            util.drawCenteredX("PRESS SPACE TO START", (constants.screenHeight / 2) + 40, constants.screenFontSize, raylib.Color.black);
        },
        .Game => {
            drawGame(game_state);
        },
        .GameOver => {
            util.drawCenteredX("Game Over!", constants.screenHeight / 2, constants.screenFontSize, raylib.Color.black);
        },
    }
}

fn drawGame(game_state: *GameState) void {
    if (game_state.screen != .Game) return;

    if (builtin.mode == .Debug and debug_info_enabled) {
        var currentFps: [64]u8 = undefined;
        if (std.fmt.bufPrintZ(&currentFps, "FPS: {d}", .{raylib.getFPS()})) |fps| {
            raylib.drawText(fps, 16, 16, constants.screenFontSize, raylib.Color.black);
        } else |_| {}
    }
    game_state.player.draw();
}
