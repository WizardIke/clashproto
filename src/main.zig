const std = @import("std");
const c = @import("c.zig");
const assert = std.debug.assert;
const panic = std.debug.panic;

const Animation = struct {
    png_data: []const u8,
    texture: *c.SDL_Texture,
    frame_count: i32,
    // in frames
    frame_delay: i32,
    center: c.SDL_Point,

    fn initialize(self: *Animation, renderer: *c.SDL_Renderer) void {
        const rwops = c.SDL_RWFromConstMem(
            self.png_data.ptr,
            @intCast(c_int, self.png_data.len),
        ).?;
        const surface = c.IMG_Load_RW(rwops, 0) orelse panic("unable to load image", .{});
        self.texture = c.SDL_CreateTextureFromSurface(renderer, surface) orelse
            panic("unable to convert surface to texture", .{});
    }
};

var idle_animation = Animation{
    .png_data = @embedFile("../assets/GraveRobber_idle.png"),
    .texture = undefined,
    .frame_count = 4,
    .frame_delay = 10,
    .center = .{
        .x = 17,
        .y = 32,
    },
};

var walk_animation = Animation{
    .png_data = @embedFile("../assets/GraveRobber_walk.png"),
    .texture = undefined,
    .frame_count = 6,
    .frame_delay = 10,
    .center = .{
        .x = 17,
        .y = 32,
    },
};

const all_animations = [_]*Animation{
    &idle_animation,
    &walk_animation,
};

const Player = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    vel_x: i32,
    vel_y: i32,
    max_spd_x: i32,
    max_spd_y: i32,
    ani: *const Animation,
    ani_frame_index: i32,
    ani_frame_delay: i32,
    friction: i32,
    direction: i32,

    fn startAnimation(player: *Player, animation: *const Animation) void {
        player.ani = animation;
        player.ani_frame_index = 0;
        player.ani_frame_delay = 0;
    }
};

pub fn main() anyerror!void {
    if (!(c.SDL_SetHintWithPriority(
        c.SDL_HINT_NO_SIGNAL_HANDLERS,
        "1",
        c.SDL_HintPriority.SDL_HINT_OVERRIDE,
    ) != c.SDL_bool.SDL_FALSE)) {
        panic("failed to disable sdl signal handlers\n", .{});
    }
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        panic("SDL_Init failed: {c}\n", .{c.SDL_GetError()});
    }
    defer c.SDL_Quit();

    const screen = c.SDL_CreateWindow(
        "Clash Game Prototype",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        800,
        600,
        c.SDL_WINDOW_RESIZABLE,
    ) orelse {
        panic("SDL_CreateWindow failed: {c}\n", .{c.SDL_GetError()});
    };
    defer c.SDL_DestroyWindow(screen);

    const renderer: *c.SDL_Renderer = c.SDL_CreateRenderer(screen, -1, 0) orelse {
        panic("SDL_CreateRenderer failed: {c}\n", .{c.SDL_GetError()});
    };
    defer c.SDL_DestroyRenderer(renderer);

    for (all_animations) |anim| {
        anim.initialize(renderer);
    }

    var player: Player = .{
        .x = 400,
        .y = 400,
        .w = 48,
        .h = 48,
        .vel_x = 0,
        .vel_y = 0,
        .max_spd_x = 3,
        .max_spd_y = 3,
        .friction = 1,
        .ani = &idle_animation,
        .ani_frame_index = 0,
        .ani_frame_delay = 0,
        .direction = 1,
    };

    while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.@"type") {
                c.SDL_QUIT => return,
                else => {},
            }
        }

        const kb_state = c.SDL_GetKeyboardState(null);
        const want_left = kb_state[c.SDL_SCANCODE_LEFT] != 0;
        const want_right = kb_state[c.SDL_SCANCODE_RIGHT] != 0;
        const moving = want_left or want_right;
        if (want_left) {
            player.direction = -1;
            if (player.vel_x > -player.max_spd_x) player.vel_x -= 2;
        }
        if (want_right) {
            player.direction = 1;
            if (player.vel_x < player.max_spd_x) player.vel_x += 2;
        }
        if (moving and player.ani == &idle_animation) {
            player.startAnimation(&walk_animation);
        } else if (!moving and player.ani != &idle_animation) {
            player.startAnimation(&idle_animation);
        }

        player.ani_frame_delay += 1;
        if (player.ani_frame_delay >= player.ani.frame_delay) {
            player.ani_frame_index = @rem(
                (player.ani_frame_index + 1),
                player.ani.frame_count,
            );
            player.ani_frame_delay = 0;
        }

        player.x += player.vel_x;
        player.y += player.vel_y;
        if (player.vel_x > 0) {
            player.vel_x -= player.friction;
            if (player.vel_x < 0) player.vel_x = 0;
        }
        if (player.vel_x < 0) {
            player.vel_x += player.friction;
            if (player.vel_x > 0) player.vel_x = 0;
        }

        sdlAssertZero(c.SDL_RenderClear(renderer));

        const src_rect = c.SDL_Rect{
            .x = player.w * player.ani_frame_index,
            .y = 0,
            .w = player.w,
            .h = player.h,
        };
        const dst_rect = c.SDL_Rect{
            .x = player.x,
            .y = player.y,
            .w = player.w,
            .h = player.h,
        };
        sdlAssertZero(c.SDL_RenderCopyEx(
            renderer,
            player.ani.texture,
            &src_rect,
            &dst_rect,
            0,
            &player.ani.center,
            if (player.direction < 0) .SDL_FLIP_HORIZONTAL else .SDL_FLIP_NONE,
        ));

        c.SDL_RenderPresent(renderer);
        // delay until the next multiple of 17 milliseconds
        const delay_millis = 17 - (c.SDL_GetTicks() % 17);
        c.SDL_Delay(delay_millis);
    }
}

fn sdlAssertZero(ret: c_int) void {
    if (ret == 0) return;
    panic("sdl function returned an error: {c}", .{c.SDL_GetError()});
}
