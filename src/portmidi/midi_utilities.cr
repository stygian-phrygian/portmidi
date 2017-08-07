# convenience methods for creating midi (short) messages
module MidiUtilities
  extend self
  def note_on(note, velocity = 90, channel = 0)
    PortMidi::MidiEvent.new 0x90 + channel, note, velocity
  end

  def note_off(note, velocity = 0, channel = 0)
    PortMidi::MidiEvent.new 0x80 + channel, note, velocity
  end

  def cc(cc_number, cc_value, channel = 0)
    PortMidi::MidiEvent.new 0xA0 + channel, cc_number, cc_value, channel
  end

  # for use in LibPortMidi.set_channel_mask
  def channel_mask(*channels : Int32) : Int16
    channels.select { |i| i >= 0 && i < 16 }.map { |n| (1 << n) }.sum
  end
end
