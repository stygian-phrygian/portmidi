# PortMidi
a Crystal binding to the PortMidi C library.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  portmidi:
    github: stygian-phrygian/portmidi
```

install portmidi and the required development files

## Usage

```crystal
require "portmidi"
require "portmidi/midi_utilities.cr" # <--- optional module w/ convenience methods
include MidiUtilities
begin
  # turn on PortMidi
  PortMidi.start

  # get the default midi output device id and open a stream with it
  output = PortMidi::MidiOutputStream.new PortMidi.get_default_midi_output_device_id
  puts "Writing to (default) midi out"
  puts output

  # write to it
  output.write([note_on(56), note_on(77)])
  sleep(3)
  output.write([note_off(56), note_off(77)])

  # get a stream for every midi input device
  inputs = PortMidi.get_all_midi_device_info.select(&.input).map &.to_input_stream

  # listen to them
  puts "Listening to midi events..."
  inputs.each { |s| puts s }
  spawn do
    loop do
      events = inputs.flat_map &.read
      events.each { |e| puts e } unless events.empty?
      sleep 10.milliseconds
    end
  end

  # sleep a bit
  sleep 10.seconds

  # close all the input and output streams
  inputs.each &.close
  output.close

  # turn off PortMidi
  PortMidi.stop
rescue e
  puts e.message
end
```
