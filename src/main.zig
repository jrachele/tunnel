const builtin = @import("builtin");
const std = @import("std");
const raylib = @import("raylib");

const constants = @import("constants.zig");
const util = @import("util.zig");

const Player = @import("player.zig");
const Tunnel = @import("tunnel.zig");

const WrapAroundArray = @import("wrap_around_array.zig").WrapAroundArray;

const Screen = enum { Title, Game, GameOver };

const GameState = struct {
    allocator: std.mem.Allocator,

    screen: Screen = .Title,
    player: Player = .{},
    tunnel: Tunnel = undefined,
    advance_speed: u64 = 100, // Per second advance
    seconds_since_last_advance: f64 = 0,
    score: u64 = 0,
    time_elapsed: f64 = 0,

    pub fn init(allocator: std.mem.Allocator) !GameState {
        var state = GameState{
            .allocator = allocator,
        };
        state.tunnel = try Tunnel.init(allocator);
        return state;
    }

    pub fn deinit(game_state: *GameState) void {
        game_state.tunnel.deinit();
    }

    /// Resets the game state. Frees then reallocates the tunnel
    pub fn reset(game_state: *GameState) !void {
        game_state.deinit();
        game_state.* = try GameState.init(game_state.allocator);
    }
};

var debug_info_enabled: bool = false;
pub fn main() !void {
    raylib.initWindow(constants.screenWidth, constants.screenHeight, "Tunnel");
    defer raylib.closeWindow();

    raylib.setTargetFPS(300);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer switch (gpa.deinit()) {
        .leak => {
            std.log.debug("Leaks detected!", .{});
        },
        .ok => {},
    };

    const alloc = gpa.allocator();

    var game_state = try GameState.init(alloc);
    defer game_state.deinit();

    while (!raylib.windowShouldClose()) {
        // Update
        try update(alloc, &game_state);

        // Draw
        raylib.beginDrawing();
        draw(&game_state);
        raylib.endDrawing();
    }
}

fn update(allocator: std.mem.Allocator, game_state: *GameState) !void {
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

            game_state.player.update();

            const collision_points = try game_state.tunnel.getCollisionPoints(allocator);
            defer allocator.free(collision_points);

            for (collision_points) |point| {
                const triangle = game_state.player.triangle;
                // You lose!
                if (raylib.checkCollisionPointTriangle(point, triangle[0], triangle[1], triangle[2])) {
                    game_state.screen = .GameOver;
                    return;
                }
            }

            // Advance the tunnel
            if (game_state.seconds_since_last_advance > (1.0 / @as(f64, @floatFromInt(game_state.advance_speed)))) {
                game_state.tunnel.advance();
                game_state.score += 1;
                game_state.seconds_since_last_advance = 0;
            } else {
                game_state.seconds_since_last_advance += raylib.getFrameTime();
            }

            game_state.advance_speed = 100 + (@as(u64, @intFromFloat(game_state.time_elapsed)));

            game_state.time_elapsed += raylib.getFrameTime();
        },
        .GameOver => {
            if (raylib.isKeyPressed(.space)) {
                try game_state.reset();
                game_state.screen = .Game;
            }
        },
    }
}

fn draw(game_state: *GameState) void {
    raylib.clearBackground(raylib.Color.ray_white);

    switch (game_state.screen) {
        .Title => {
            util.drawCenteredX("TUNNEL", constants.screenHeight / 2, constants.screenFontSize * 2, raylib.Color.black);
            util.drawCenteredX("PRESS SPACE TO START", (constants.screenHeight / 2) + constants.screenFontSize * 2, constants.screenFontSize, raylib.Color.black);
        },
        .Game => {
            drawGame(game_state);
        },
        .GameOver => {
            drawGame(game_state);
            raylib.drawRectangle(0, 0, constants.screenWidth, constants.screenHeight, raylib.Color.init(255, 255, 255, 150));

            util.drawCenteredX("GAME OVER!", constants.screenHeight / 2, constants.screenFontSize * 2, raylib.Color.black);
            var finalScore: [64]u8 = undefined;
            if (std.fmt.bufPrintZ(&finalScore, "FINAL SCORE: {d}", .{game_state.score})) |score| {
                util.drawCenteredX(score, (constants.screenHeight / 2) + constants.screenFontSize * 2, constants.screenFontSize, raylib.Color.black);
            } else |_| {}
            util.drawCenteredX("PRESS ESC TO QUIT", (constants.screenHeight / 2) + constants.screenFontSize * 3, constants.screenFontSize, raylib.Color.black);
            util.drawCenteredX("PRESS SPACE TO PLAY AGAIN", (constants.screenHeight / 2) + constants.screenFontSize * 4, constants.screenFontSize, raylib.Color.black);
        },
    }
}

fn drawGame(game_state: *GameState) void {
    raylib.clearBackground(raylib.Color.fromInt(constants.backgroundColor));
    game_state.player.draw();
    game_state.tunnel.draw();

    var hudBuf: [128]u8 = undefined;
    if (std.fmt.bufPrintZ(&hudBuf, "Score: {d}\t|\tSpeed: {d}", .{ game_state.score, game_state.advance_speed })) |hud| {
        raylib.drawText(hud, 16, 16, constants.screenFontSize, raylib.Color.black);
    } else |_| {}
    if (builtin.mode == .Debug and debug_info_enabled) {
        var currentFps: [64]u8 = undefined;
        if (std.fmt.bufPrintZ(&currentFps, "FPS: {d}", .{raylib.getFPS()})) |fps| {
            util.drawTextAlignRight(fps, 16, 16, constants.screenFontSize, raylib.Color.black);
        } else |_| {}
    }
}
