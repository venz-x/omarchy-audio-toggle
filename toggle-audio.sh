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