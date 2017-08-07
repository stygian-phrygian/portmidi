require "../src/portmidi.cr"
require "../src/portmidi/midi_utilities.cr"
include MidiUtilities
begin
  # turn on PortMidi
  PortMidi.start

  # get the default midi output device id and open a stream with it
  output = PortMidi::MidiOutputStream.new PortMidi.get_default_midi_output_device_id
  puts "Writing to (default) midi out"
  puts output

  # write to midi out
  output.write([note_on(56), note_on(77)])
  sleep(3)
  output.write([note_off(56), note_off(77)])

  # close it
  output.close

  # turn off PortMidi
  PortMidi.stop
rescue e
  puts e.message
end
