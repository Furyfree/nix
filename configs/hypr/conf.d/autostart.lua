-- UWSM owns session processes; Noctalia starts through its systemd unit.
hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -s b -t service -u app-udiskie.service -- udiskie --no-tray --no-notify")
end)
