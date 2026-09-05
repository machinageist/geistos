-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 4,
        gaps_out = 4,

        border_size = 1,

        col = {
            active_border   = { colors = { "rgba(bd93f9ff)", "rgba(ff79c6ff)" }, angle = 45 },
            inactive_border = "rgba(44475aaa)",
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    cursor = {
        no_hardware_cursors = true,
    },

    decoration = {
        rounding = 12,

        active_opacity   = 0.93,
        inactive_opacity = 0.77,

        blur = {
            enabled           = true,
            size              = 8,
            passes            = 3,
            noise             = 0.02,
            contrast          = 1.1,
            brightness        = 1.0,
            vibrancy          = 0.2,
            new_optimizations = true,
        },

        shadow = {
            enabled      = true,
            range        = 20,
            render_power = 3,
            color        = "rgba(bd93f940)",
        },
    },
})
