-- UWSM owns session processes; Noctalia starts through its systemd unit.
hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -s b -t service -u app-udiskie.service -- udiskie --no-tray --no-notify")
    -- Hidden in the tray, so its SSH agent can ask to unlock for Git signing.
    -- 1Password's own Start at login does not start it in this session.
    hl.exec_cmd("uwsm app -s b -- 1password --silent")
end)
