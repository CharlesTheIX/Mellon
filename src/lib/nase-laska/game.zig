const std = @import("std");
const rl = @import("raylib");

pub fn naseLaska() !void {
    rl.setTargetFPS(60);
    rl.initWindow(800, 600, "Naše Láska");
    defer rl.closeWindow();

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.white);

        rl.drawText("Hello, Mellon!", 190, 200, 20, rl.Color.black);

        rl.endDrawing();
    }

    std.process.exit(0);
}
