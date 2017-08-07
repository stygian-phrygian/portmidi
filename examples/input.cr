require "../src/portmidi.cr"
require "../src/portmidi/midi_utilities.cr"
include MidiUtilities
begin
  # turn on PortMidi
  PortMidi.start

  # open every available input
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

  # close them
  inputs.each &.close

  # turn off PortMidi
  PortMidi.stop
rescue e
  puts e.message
end
