#!/bin/sh
# Local monitor and terminal control for Jarvis voice commands.
# Usage: display_control.sh screen_on|screen_off|terminal_on|terminal_off
# Works with Ivan's XFCE session on :0 (LightDM autologin).

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

TERM_CLASS="JarvisTerm"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/jarvis-terminal.pid"

terminal_running() {
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

if ! xset q >/dev/null 2>&1; then
    echo "no access to X display $DISPLAY (is the user session logged in?)" >&2
    exit 1
fi

case "$1" in
    screen_on)
        xset dpms force on
        xset s reset
        ;;
    screen_off)
        # give the voice reply time to finish before the screen goes dark
        sleep 1
        xset dpms force off
        ;;
    terminal_on)
        xset dpms force on
        if ! terminal_running; then
            setsid xterm -class "$TERM_CLASS" -maximized \
                -fa Monospace -fs 13 -bg black -fg gray90 \
                -e "${SHELL:-/bin/bash}" -l >/dev/null 2>&1 </dev/null &
            echo $! > "$PIDFILE"
        fi
        ;;
    terminal_off)
        if terminal_running; then
            kill "$(cat "$PIDFILE")"
        fi
        rm -f "$PIDFILE"
        ;;
    *)
        echo "usage: $0 screen_on|screen_off|terminal_on|terminal_off" >&2
        exit 2
        ;;
esac
