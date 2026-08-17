# Audio Output Toggle

A small Bash script for quickly switching between **Headphones** and **Line Out** using PipeWire/PulseAudio's `pactl`.

This was created for a system using a **Realtek ALC887-VD** where switching directly to `Line Out` does not always produce sound. On this setup, the reliable sequence is:

```text
Headphones
    ↓
Speakers
    ↓
Line Out
```

The script handles that automatically.

---

## Script

Save the following as:

```text
~/.local/bin/toggle-audio
```

```bash
#!/bin/bash

# Toggle between headphones and Line Out.
# The Realtek ALC887-VD on this system requires the Speakers
# port to be activated briefly before Line Out works correctly.

# PipeWire/PulseAudio sink for the motherboard's analog audio output
SINK="alsa_output.pci-0000_28_00.3.analog-stereo"

# Get the currently active output port for the analog sink
CURRENT=$(pactl list sinks | awk '
/Name: alsa_output.pci-0000_28_00.3.analog-stereo/ { found=1 }
/Active Port:/ && found { print $3; exit }
')

# If currently using Line Out, switch directly to headphones
if [[ "$CURRENT" == "analog-output-lineout" ]]; then
    pactl set-sink-port "$SINK" analog-output-headphones
else
    # Initialize the speaker route first
    pactl set-sink-port "$SINK" analog-output-speaker

    # Give the audio codec a moment to initialize
    sleep 0.3

    # Switch to the actual Line Out port
    pactl set-sink-port "$SINK" analog-output-lineout
fi
```

Make it executable:

```bash
chmod +x ~/.local/bin/toggle-audio
```

Run it manually with:

```bash
~/.local/bin/toggle-audio
```

---

# How It Works

## 1. The audio sink

The script starts with:

```bash
SINK="alsa_output.pci-0000_28_00.3.analog-stereo"
```

A **sink** is an audio output device in PipeWire/PulseAudio.

You can see the available sinks with:

```bash
pactl list sinks
```

On the system this script was created for, the motherboard's analog sink is:

```text
alsa_output.pci-0000_28_00.3.analog-stereo
```

This name is **hardware/system-specific**. Another computer may have a different sink name.

---

## 2. Finding the active port

The command:

```bash
pactl list sinks
```

prints information about all audio sinks.

For example, the relevant part may look like:

```text
Name: alsa_output.pci-0000_28_00.3.analog-stereo

Ports:
    analog-output-lineout: Line Out
    analog-output-speaker: Speakers
    analog-output-headphones: Headphones

Active Port: analog-output-lineout
```

We only need to know which port is currently active.

The script uses:

```bash
CURRENT=$(pactl list sinks | awk '
/Name: alsa_output.pci-0000_28_00.3.analog-stereo/ { found=1 }
/Active Port:/ && found { print $3; exit }
')
```

### What the first `awk` rule does

```awk
/Name: alsa_output.pci-0000_28_00.3.analog-stereo/ { found=1 }
```

This searches for our specific sink.

When `awk` finds:

```text
Name: alsa_output.pci-0000_28_00.3.analog-stereo
```

it sets:

```text
found = 1
```

This tells the next rule that we are now inside the information belonging to our sink.

### What the second `awk` rule does

```awk
/Active Port:/ && found { print $3; exit }
```

It looks for the `Active Port:` line after our sink has been found.

For example:

```text
Active Port: analog-output-lineout
```

`awk` splits this into fields:

```text
$1 = Active
$2 = Port:
$3 = analog-output-lineout
```

Therefore:

```awk
print $3
```

returns:

```text
analog-output-lineout
```

The `exit` stops `awk` once it has found the answer.

The result is stored in:

```bash
CURRENT
```

For example:

```text
CURRENT="analog-output-lineout"
```

or:

```text
CURRENT="analog-output-headphones"
```

---

# Switching Ports

The command used to change the active port is:

```bash
pactl set-sink-port "$SINK" <port>
```

For example:

```bash
pactl set-sink-port "$SINK" analog-output-headphones
```

means:

```text
SINK
 ↓
alsa_output.pci-0000_28_00.3.analog-stereo
 ↓
switch its active port to
 ↓
analog-output-headphones
```

The three ports used by this script are:

| Port | Meaning |
|---|---|
| `analog-output-headphones` | Headphones |
| `analog-output-speaker` | Speakers |
| `analog-output-lineout` | Line Out |

---

# Why Speakers Is Used as an Intermediate Step

This is the hardware-specific part of the script.

On the Realtek ALC887-VD setup this was created for, switching directly from Headphones to Line Out can leave the Line Out jack silent.

The reliable sequence is:

```text
Headphones
     ↓
Speakers
     ↓
Line Out
```

Therefore the script does:

```bash
pactl set-sink-port "$SINK" analog-output-speaker
sleep 0.3
pactl set-sink-port "$SINK" analog-output-lineout
```

The `Speakers` port is not the final destination. It is used to initialize the audio route before switching to Line Out.

The `0.3` second delay gives the audio codec a short amount of time to initialize the intermediate route.

---

# Toggle Logic

The main logic is:

```bash
if [[ "$CURRENT" == "analog-output-lineout" ]]; then
    pactl set-sink-port "$SINK" analog-output-headphones
else
    pactl set-sink-port "$SINK" analog-output-speaker
    sleep 0.3
    pactl set-sink-port "$SINK" analog-output-lineout
fi
```

In plain English:

### If Line Out is currently active

```text
Line Out
   ↓
Headphones
```

The script can switch directly to headphones:

```bash
pactl set-sink-port "$SINK" analog-output-headphones
```

### If anything else is currently active

```text
Headphones
   ↓
Speakers
   ↓
Line Out
```

or:

```text
Speakers
   ↓
Line Out
```

So the script always initializes the Speakers route before selecting Line Out.

The resulting behavior is:

| Current port | Result |
|---|---|
| Headphones | Speakers → Line Out |
| Speakers | Speakers → Line Out |
| Line Out | Headphones |

Effectively, the script gives you:

```text
🎧 Headphones  ←→  🔊 Line Out
```

without manually performing the intermediate Speakers switch.

---

# Finding Your Own Sink Name

If the script does not work on another system, first run:

```bash
pactl list sinks
```

Look for the desired analog output and its:

```text
Name:
```

For example:

```text
Name: alsa_output.pci-XXXX_XX_XX.X.analog-stereo
```

Then replace the value of `SINK` in the script:

```bash
SINK="your-sink-name-here"
```

You can also inspect the available ports with:

```bash
pactl list sinks
```

Look for:

```text
Ports:
    analog-output-lineout
    analog-output-speaker
    analog-output-headphones
```

The exact ports available depend on the audio hardware.

---

# Optional: Bind It to a Key

For Hyprland, add a keybinding to your:

```text
~/.config/hypr/bindings.lua
```

For example:

```ini
o.bind("SUPER + SHIFT + CTRL + L", "Toggle audio output", "~/.local/bin/toggle-audio")
```

Then reload Hyprland:

```bash
hyprctl reload
```

Now:

```text
SUPER + SHIFT + CTRL + L
```

toggles between:

```text
🎧 Headphones
       ↕
🔊 Line Out
```

---

## Notes

- This script is primarily intended for the **Realtek ALC887-VD** setup for which it was created.
- The `SINK` name is hardware-specific.
- The `Speakers → Line Out` workaround may not be necessary on other hardware.
- The script requires `pactl`, provided by the PipeWire/PulseAudio compatibility layer.
