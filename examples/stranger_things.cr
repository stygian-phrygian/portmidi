require "../src/portmidi.cr"
require "../src/portmidi/midi_utilities.cr"
include MidiUtilities

BPM = 86.0
quarter_note_duration = (60/BPM).seconds
sixteenth_note_duration = (quarter_note_duration/4)
# pitch offset (in MIDI notation 36 = C3)
pitch_offset = 48
# main bassline (quarter note duration each)
bassline = [0, 0, 0, 2, 4, 4, 4, -5].map { |n| n + (pitch_offset - 12) }
# main arpeggio (sixteenth note duration each)
arpeggio = [0, 4, 7, 11, 12, 11, 7, 4].map { |n| n + (pitch_offset + 12) }
# combine the arrays into an Array of Arrays
# to fix timing issues of running greater than 2 fibers concurrently
theme = bassline.flat_map do |bass_note|
  step = arpeggio.map { |arpeggio_note| [arpeggio_note] }
  step[0] << bass_note
  step[4] << bass_note
  step
end
# number of times to repeat theme
repetitions = 2

# NB. this has serious timing issues if running more than 1 fiber
# it's best to combine all your notes into an Array of Arrays
def play(stream : PortMidi::MidiOutputStream, steps, duration : Time::Span = 1, repetitions = 1)
  spawn do
    repetitions.times do
      steps.each do |step|
        stream.write step.map { |n| note_on n }
        sleep duration
        stream.write step.map { |n| note_off n }
        Fiber.yield
      end
    end
  end
end

begin
  # turn on PortMidi
  PortMidi.start

  # get the default midi output device id and open a stream with it
  output = PortMidi::MidiOutputStream.new PortMidi.get_default_midi_output_device_id
  puts "Writing to (default) midi out"
  puts output

  # play it
  play output, theme, sixteenth_note_duration, repetitions

  # allow it to play
  # 16 beats * repetitions + error delay
  sleep quarter_note_duration * 16 * repetitions + 3.seconds

  # close it
  output.close

  # turn off PortMidi
  PortMidi.stop
rescue e
  puts e.message
end
