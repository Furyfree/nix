-- Start session processes once; config reloads do not restart them.
hl.on("hyprland.start", function()
    -- Ghostty reads this GTK preference when each terminal surface is created.
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-enable-primary-paste true")

    -- Named UWSM service: separate logs and graceful session-bound shutdown.
    hl.exec_cmd("uwsm app -s s -t service -u app-noctalia.service -p TimeoutStopSec=10s -p SendSIGKILL=no -- noctalia --daemon")

    -- HyprPM owns the compiled plugins; reload the enabled set on login.
    -- Hyprland 0.56 uses this system cache. Avoid initializing it on first login.
    hl.exec_cmd([[if [ -d "/var/cache/hyprpm/$(id -un)" ]; then
        hyprpm reload && hyprctl reload config-only
    fi]])

    -- Automount removable drives; Noctalia provides the drive UI and notifications.
    hl.exec_cmd("uwsm app -s b -t service -u app-udiskie.service -- udiskie --no-tray --no-notify")

    -- The compatible fork supplies a headless user service; older builds are skipped.
    hl.exec_cmd([[command -v librepods >/dev/null 2>&1 || exit 0
    systemctl --user cat librepods.service >/dev/null 2>&1 || exit 0
    for adapter in /sys/class/bluetooth/hci*; do
        if [ -d "$adapter" ]; then exec systemctl --user start librepods.service; fi
    done]])

    -- Dictation daemon for the Super+D shortcut. Start its user unit per
    -- session only once a model has been
    -- downloaded, since the daemon fails and retries without one.
    hl.exec_cmd([[command -v voxtype >/dev/null 2>&1 || exit 0
    systemctl --user cat voxtype.service >/dev/null 2>&1 || exit 0
    set -- "${XDG_DATA_HOME:-$HOME/.local/share}/voxtype/models"/*
    [ -e "$1" ] || exit 0
    exec systemctl --user start voxtype.service]])
end)
