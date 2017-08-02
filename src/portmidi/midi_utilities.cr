

def note_on(note, velocity=90, channel=0)
  midi_message(0x90, note, velocity, channel)
end

def note_off(note, velocity=0, channel=0)
  midi_message(0x80, note, velocity, channel)
end

def cc(cc_number, cc_value, channel=0)
  midi_message(0xA0, cc_number, cc_value, channel)
end

def midi_message(status : Int32, data1 : Int32, data2 : Int32, channel : Int32 = 0) : Int32
  ((data2 << 16) & 0x00FF0000) |
  ((data1 << 8 ) & 0x0000FF00) |
  (status        & 0x000000FF)
end
