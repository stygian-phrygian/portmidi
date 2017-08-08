require "../src/portmidi.cr"

PortMidi.get_all_midi_device_info.each { |d| puts d }
