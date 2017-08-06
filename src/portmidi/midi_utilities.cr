
class MidiMessage
end

enum MidiRealTimeMessage
  Clock = 0xF8
  Start = 0xFA
  Continue = 0xFB
  Stop = 0xFC
  ActiveSensing = 0xFE
  Reset = 0xFF
end

class MidiSysexMessage < MidiMessage
  def initialize(@bytes: Array(UInt8))
  end
end

class MidiShortMessage < MidiMessage
  getter :status, :data1, :data2

  def initialize(@status : Int32, @data1 : Int32, @data2 : Int32)
  end

  # parse the Int32 midi message which portmidi gives us
  def self.from_i32(message : Int32)
    self.new message & 0x000000FF,
      (message >> 8) & 0x000000FF,
      (message >> 16) & 0x000000FF
  end

  # manufacture the Int32 message that portmidi utilizes
  def to_i32 : Int32
    ((@data2 << 16) & 0x00FF0000) |
      ((@data1 << 8) & 0x0000FF00) |
      (@status & 0x000000FF)
  end

  private def get_status_without_channel
    (@status >> 4) & 0x0000000F
  end

  def note_off?
    0x8 == get_status_without_channel || (note_on? && @data2 == 0)
  end

  def note_on?
    0x9 == get_status_without_channel
  end

  def polyphonic_key_pressure?
    0xA == get_status_without_channel
  end

  def cc?
    0xB == get_status_without_channel
  end

  def program_change?
    0xC == get_status_without_channel
  end

  def channel_pressure?
    0xD == get_status_without_channel
  end

  def pitch_bend?
    0xE == get_status_without_channel
  end

  def aftertouch?
    channel_pressure?
  end

  def channel
    @status & 0x0F
  end
end

# convenience methods for creating midi (short) messages

def note_on(note, velocity = 90, channel = 0)
  MidiShortMessage.new 0x90 + channel, note, velocity
end

def note_off(note, velocity = 0, channel = 0)
  MidiShortMessage.new 0x80 + channel, note, velocity
end

def cc(cc_number, cc_value, channel = 0)
  MidiShortMessage.new 0xA0 + channel, cc_number, cc_value, channel
end

# for use in LibPortMidi.set_channel_mask
def channel_mask(*channels : Int32) : Int16
  channels.select {|i| i >= 0 && i < 16}.map {|n| (1 << n)}.sum
end
