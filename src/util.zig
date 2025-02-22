const raylib = @import("raylib");
const std = @import("std");

const constants = @import("constants.zig");

pub fn drawCenteredX(text: [*:0]const u8, y: i32, font_size: i32, color: raylib.Color) void {
    const font = raylib.getFontDefault() catch |err| {
        std.log.err("Unable to acquire default font! {}", .{err});
        return;
    };

    const textWidth = raylib.measureTextEx(font, text, @floatFromInt(font_size), 0);
    const x_offset: i32 = @intFromFloat(textWidth.x / 2);
    raylib.drawText(text, (constants.screenWidth / 2) - x_offset, y, font_size, color);
}
