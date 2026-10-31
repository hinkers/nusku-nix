-- Nusku - keyboard, mouse, touchpad and gestures.
-- The keyboard layout is in <config>/nusku/input.lua, written by Nix from the installer's answer.

hl.config({
    input = {
        follow_mouse = 1,
        sensitivity = 0,

        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
        },
    },
})

-- Three-finger horizontal swipe switches workspaces.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
