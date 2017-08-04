require "./portmidi/*"

module PortMidi
  extend self

  def start
    check_error LibPortMidi.initialize
  end

  def stop
    check_error LibPortMidi.terminate
  end

  def get_all_midi_device_info
    Array(MidiDeviceInfo).new(LibPortMidi.count_devices) do |device_id|
      MidiDeviceInfo.new device_id
    end
  end

  def check_error(error : LibPortMidi::PmError)
    unless error == LibPortMidi::PmError::PmNoError
      raise PortMidiException.new String.new(LibPortMidi.get_error_text(error))
    end
  end

  def get_default_midi_input_device_id
    # result can be a device_id (0-N) or "pmNoDevice" == -1
    device_id = LibPortMidi.get_default_input_device_id
    raise PortMidiException.new "No default input device found." if device_id == LibPortMidi::PmNoDevice
    device_id
  end

  def get_default_midi_output_device_id
    # result can be a device_id (0-N) or "pmNoDevice" == -1
    device_id = LibPortMidi.get_default_output_device_id
    raise PortMidiException.new "No default output device found." if device_id == LibPortMidi::PmNoDevice
    device_id
  end

  private abstract class MidiStream
    getter :device_id, :stream

    def initialize(@device_id : Int32)
      @stream = uninitialized LibPortMidi::PortMidiStream*
      # opening the input/output stream happens here in the subclasses
    end

    # this only writes "Channel Voice Messages" (not SysEx)
    # see: https://www.midi.org/specifications/item/table-1-summary-of-midi-message
    def write(messages : Array(MidiMessage))
      buffer = Array(LibPortMidi::PmEvent).new(messages.size) do |i|
        event = LibPortMidi::PmEvent.new
        event.timestamp = 0
        event.message = messages[i].to_i32
        event
      end
      PortMidi.check_error LibPortMidi.write(@stream, buffer, buffer.size)
    end

    def read
      buffer = StaticArray(LibPortMidi::PmEvent, 1024).new(LibPortMidi::PmEvent.new)
      # read() returns the number of events read
      # OR a negative integer (representing a PmError enum value)
      events_read = LibPortMidi.read(@stream, buffer, buffer.size)
      PortMidi.check_error LibPortMidi::PmError.new(events_read) if events_read < 0
      Array(MidiMessage).new(events_read.to_i32) do |i|
        MidiMessage.from_i32(buffer[i].message)
      end
    end

    def listen(callback)
      # TODO:
    end

    def close
      PortMidi.check_error LibPortMidi.close @stream
    end

    def poll
      # result is 0 (false) ,1 (true), or PmError
      result = LibPortMidi.poll(@stream)
      return result == 1 if result >=0
      PortMidi.check_error result
    end

    def abort
      PortMidi.check_error LibPortMidi.abort @stream
    end

    def set_filter(filter : Int32)
      PortMidi.check_error LibPortMidi.set_filter(@stream, filter)
    end

    def set_channel_mask(mask : Int32)
      PortMidi.check_error LibPortMidi.set_channel_mask(@stream, mask)
    end
  end

  class MidiInputStream < MidiStream
    def initialize(@device_id : Int32)
      super
      PortMidi.check_error LibPortMidi.open_input(out @stream, @device_id, nil, 512, nil, nil)
    end
  end

  class MidiOutputStream < MidiStream
    def initialize(@device_id : Int32)
      super
      PortMidi.check_error LibPortMidi.open_output(out @stream, @device_id, nil, 512, nil, nil, 0)
    end
  end

  class PortMidiException < Exception
  end

  # this class is the same as the PmDeviceInfo struct
  # with the addition of the device id for added convenience
  private class MidiDeviceInfo
    getter :device_id, :name, :input, :output

    @input : Bool
    @output : Bool

    def initialize(device_id : Int32)
      device_info = get_pm_midi_device_info device_id
      @device_id = device_id
      @name = String.new(device_info.name)
      @input = device_info.input != 0
      @output = device_info.output != 0
      # @opened is not immutable
      # hence we need a getter method which queries LibPortMidi with each access
      # to avoid the possibility of multiple objects refering to the same device_id
      # having a contradictory @opened instance variable between them
    end

    def opened
      device_info = get_pm_midi_device_info @device_info
      @opened = device_info.opened != 0
    end

    private def get_pm_midi_device_info(device_id)
      device_info_p = LibPortMidi.get_device_info(device_id)
      raise PortMidiException.new("Invalid device id, cannot retrieve device info") unless device_info_p
      device_info_p.value
    end

    def to_stream
      return MidiInputStream.new @device_id if @input
      return MidiOutputStream.new @device_id
    end
  end
end

# turnon PortMidi
PortMidi.start
# get the midi streams (and open them)
d_in = PortMidi.get_all_midi_device_info.select { |d| d.input && d.name.match /2/ }[0].to_stream
# d_out = PortMidi.get_all_midi_device_info.select { |d| d.output }[0].to_stream
d_out = PortMidi::MidiOutputStream.new PortMidi.get_default_midi_output_device_id
# log them
p d_in
p d_out
# write midi out
d_out.write([note_on(56), note_on(77)])
sleep(3)
d_out.write([note_off(56), note_off(77)])
# get midi in
messages = d_in.read
p messages
# close them
d_in.close
d_out.close
# turn off PortMidi
PortMidi.stop
