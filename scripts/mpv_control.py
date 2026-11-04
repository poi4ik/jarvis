#!/usr/bin/env python3
"""mpv control for Jarvis voice commands.

Usage: mpv_control.py <action>

  video        play ~/Видео as a playlist, fullscreen on the local monitor
  music        play ~/Музыка as a shuffled playlist, audio only
  pause        pause playback
  resume       resume playback
  toggle       toggle pause
  stop         quit the player
  louder       volume +10 (system volume if the player is not running)
  quieter      volume -10 (system volume if the player is not running)
  forward      seek +30 s
  back         seek -15 s
  next / prev  next / previous playlist entry
  fullscreen   toggle fullscreen

The player talks to Jarvis over a JSON IPC socket in $XDG_RUNTIME_DIR.
The script returns immediately: Jarvis "cli" commands wait for exit.
"""

import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
SOCK = os.path.join(RUNTIME, "jarvis-mpv.sock")
HOME = Path.home()
VIDEO_DIR = HOME / "Видео"
MUSIC_DIR = HOME / "Музыка"

os.environ.setdefault("DISPLAY", ":0")
os.environ.setdefault("XAUTHORITY", str(HOME / ".Xauthority"))


def ipc(*command, quiet=False):
    """Send one command to mpv; return the reply dict or None if not running."""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(2)
            s.connect(SOCK)
            s.sendall((json.dumps({"command": list(command)}) + "\n").encode())
            for line in s.makefile("rb"):
                msg = json.loads(line)
                if "error" in msg:  # lines without it are async events
                    return msg
    except (FileNotFoundError, ConnectionRefusedError, socket.timeout, OSError, ValueError):
        if not quiet:
            print("mpv is not running", file=sys.stderr)
        return None
    return None


def running():
    return ipc("get_property", "pid", quiet=True) is not None


def start(path, audio_only):
    if not path.is_dir() or not any(path.iterdir()):
        print(f"{path} is empty", file=sys.stderr)
        sys.exit(1)
    if running():
        ipc("quit")
        time.sleep(0.5)
    args = [
        "mpv",
        f"--input-ipc-server={SOCK}",
        "--really-quiet",
        "--idle=no",
        "--volume=70",
        str(path),
    ]
    if audio_only:
        args[1:1] = ["--no-video", "--shuffle", "--loop-playlist=inf"]
    else:
        subprocess.run(["xset", "dpms", "force", "on"], check=False)
        subprocess.run(["xset", "s", "reset"], check=False)
        args[1:1] = ["--fullscreen", "--force-window=yes"]
    subprocess.Popen(
        args,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def system_volume(step):
    subprocess.run(
        ["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{step:+d}%"], check=False
    )


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    if action == "video":
        start(VIDEO_DIR, audio_only=False)
    elif action == "music":
        start(MUSIC_DIR, audio_only=True)
    elif action in ("louder", "quieter"):
        step = 10 if action == "louder" else -10
        if ipc("add", "volume", step, quiet=True) is None:
            system_volume(step)
    else:
        commands = {
            "pause": ("set_property", "pause", True),
            "resume": ("set_property", "pause", False),
            "toggle": ("cycle", "pause"),
            "stop": ("quit",),
            "forward": ("seek", 30),
            "back": ("seek", -15),
            "next": ("playlist-next",),
            "prev": ("playlist-prev",),
            "fullscreen": ("cycle", "fullscreen"),
        }
        if action not in commands:
            print(__doc__, file=sys.stderr)
            sys.exit(2)
        if ipc(*commands[action]) is None:
            sys.exit(1)


if __name__ == "__main__":
    main()
