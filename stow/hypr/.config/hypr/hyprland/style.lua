hl.config({
	general = {
	  gaps_in = 4
	  gaps_out = 6

	  border_size = 2
    col = {
      active_border = { colors = {"rgb(89b4fa)", "rgb(89b4fa)"}, angle = 45 }
      inactive_border = "rgb(1a1b26)"
    }

	  # layout = scrolling

	  allow_tearing = false
	}

  decoration = {
    dim_special = 0.2
    rounding = 4
    active_opacity = 1
    inactive_opacity = 0.9

    shadow = {
      enabled = true
      range = 4
      render_power = 3
      color = rgba(1a1b26ee)
    }

    blur = {
      enabled = true
      size = 5
      passes = 5
    }
  }

  animations = {
      enabled = yes
      bezier = defaultBezier, 0.05, 0.9, 0.1, 1.05
      animation = windows, 1, 7, defaultBezier
      animation = windowsOut, 1, 7, default, popin 80%
      animation = border, 1, 10, default
      animation = borderangle, 1, 8, default
      animation = fade, 1, 7, default
      animation = workspaces, 1, 6, defaultBezier
  }

  master = {
      mfact = 0.5
  }

  binds = {
      workspace_back_and_forth = true
      allow_workspace_cycles = true
  }
})
