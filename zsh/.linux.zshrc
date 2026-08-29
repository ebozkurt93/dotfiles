if command -v xdg-open > /dev/null; then
  alias open='xdg-open'
fi

# Hyprland doesn't export this to exec'd processes (hyprwm/Hyprland#8403)
if [ -z "$WAYLAND_DISPLAY" ] && command -v systemctl > /dev/null; then
  export WAYLAND_DISPLAY="$(systemctl --user show-environment 2>/dev/null | sed -n 's/^WAYLAND_DISPLAY=//p')"
fi
