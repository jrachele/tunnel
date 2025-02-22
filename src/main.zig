const std = @import("std");
const raylib = @import("raylib");

const constants = @import("constants.zig");
const util = @import("util.zig");

const Screen = enum { Title, Game, GameOver };

const GameState = struct {
    screen: Screen,
};

pub fn main() !void {
    raylib.initWindow(constants.screenWidth, constants.screenHeight, "Tunnel");
    defer raylib.closeWindow();

    raylib.setTargetFPS(300);
    var game_state = GameState{
        .screen = .Title,
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
        .Game => {},
        .GameOver => {},
    }
}

fn draw(game_state: *GameState) void {
    raylib.clearBackground(raylib.Color.gold);

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

    util.drawCenteredX("Game", constants.screenHeight / 2, constants.screenFontSize, raylib.Color.black);
}
