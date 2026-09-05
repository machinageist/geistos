----------------
---- LAYOUT ----
----------------

-- "Smart gaps" / "No gaps when only" examples from the generated config.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

hl.config({
    dwindle = {
        -- Keep the split orientation selected by `layoutmsg togglesplit`.
        -- Without this, dwindle can auto-flip the orientation again when the
        -- tree changes, which makes the split-orientation bind feel broken.
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})
