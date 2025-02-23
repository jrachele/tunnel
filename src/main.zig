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
    score: u64 = 0,
    seconds_since_last_advance: f64 = 0,
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

// Globals
var debug_info_enabled: bool = false;
var update_timer: std.time.Timer = undefined;
// Update 1000 times a second. If the game's speed surpasses this, this is the limit for how fast it will go
const UPDATE_INTERVAL = 1000;

pub fn main() !void {
    raylib.initWindow(constants.screenWidth, constants.screenHeight, "Tunnel");
    defer raylib.closeWindow();

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

    // Mutex for game state mutation
    var game_mutex = std.Thread.Mutex{};

    // Update thread is not bound by FPS
    update_timer = std.time.Timer.start() catch unreachable;

    const update_thread = try std.Thread.spawn(
        .{},
        updateThread,
        .{ &game_mutex, alloc, &game_state },
    );
    defer update_thread.join();

    // Draw loop, which is bound by FPS
    while (!raylib.windowShouldClose()) {
        // Draw
        raylib.beginDrawing();
        game_mutex.lock();
        draw(&game_state);
        game_mutex.unlock();
        raylib.endDrawing();
    }
}

fn updateThread(mutex: *std.Thread.Mutex, allocator: std.mem.Allocator, game_state: *GameState) void {
    while (!raylib.windowShouldClose()) {
        std.Thread.sleep((1 / UPDATE_INTERVAL) * std.time.ns_per_s);
        mutex.lock();
        defer mutex.unlock();

        update(allocator, game_state) catch |err| {
            std.log.err("Error occurred in update thread: {}", .{err});
            return;
        };
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
            const update_time: f32 = @as(f32, @floatFromInt(update_timer.read())) / std.time.ns_per_s;
            update_timer.reset();

            if (raylib.isKeyDown(.left) or raylib.isKeyDown(.a)) {
                game_state.player.pos -= game_state.player.speed * update_time;
                game_state.player.angle += game_state.player.tilt_speed * update_time;
                if (game_state.player.angle > Player.MAX_ANGLE) {
                    game_state.player.angle = Player.MAX_ANGLE;
                }
            } else if (raylib.isKeyDown(.right) or raylib.isKeyDown(.d)) {
                game_state.player.pos += game_state.player.speed * update_time;
                game_state.player.angle -= game_state.player.tilt_speed * update_time;
                if (game_state.player.angle < -Player.MAX_ANGLE) {
                    game_state.player.angle = -Player.MAX_ANGLE;
                }
            } else {
                // Slowly interp the angle back up to 0
                if (std.math.approxEqAbs(f32, game_state.player.angle, 0, Player.ANGLE_EPSILON)) {
                    game_state.player.angle = 0;
                } else {
                    game_state.player.angle *= 1 - (10 * update_time);
                }
            }

            if (raylib.isKeyPressed(.o)) {
                // Toggle debug information
                debug_info_enabled = !debug_info_enabled;
            }

            game_state.player.update();

            const collision_recs = try game_state.tunnel.getCollisionRecs(allocator);
            defer allocator.free(collision_recs);

            for (collision_recs) |rec| {
                const triangle = game_state.player.triangle;
                // You lose!
                if (raylib.checkCollisionPointRec(triangle[0], rec) or raylib.checkCollisionPointRec(triangle[1], rec) or raylib.checkCollisionPointRec(triangle[2], rec)) {
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
                game_state.seconds_since_last_advance += update_time;
            }

            game_state.advance_speed = 100 + (4 * @as(u64, @intFromFloat(game_state.time_elapsed)));

            game_state.time_elapsed += update_time;
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
    if (std.fmt.bufPrintZ(&hudBuf, "Score: {d}\nSpeed: {d}", .{ game_state.score, game_state.advance_speed })) |hud| {
        raylib.drawText(hud, 16, 16, constants.screenFontSize, raylib.Color.black);
    } else |_| {}
    if (builtin.mode == .Debug and debug_info_enabled) {
        var debugHud: [1024]u8 = undefined;
        if (std.fmt.bufPrintZ(&debugHud, "FPS: {d}\nTime: {d:.1}", .{ raylib.getFPS(), game_state.time_elapsed })) |hud| {
            util.drawTextAlignRight(hud, 16, 32, constants.screenFontSize, raylib.Color.black);
        } else |_| {}
    }
}
