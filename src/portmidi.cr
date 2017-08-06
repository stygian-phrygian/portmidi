require "./portmidi/*"

module PortMidi
  extend self

  def start
    check_error LibPortMidi.initialize
  end

  def stop
    check_error LibPortMidi.terminate
  end

  def check_error(error : LibPortMidi::PmError)
    unless error == LibPortMidi::PmError::PmNoError
      raise PortMidiException.new String.new(LibPortMidi.get_error_text(error))
    end
  end

  def get_all_midi_device_info
    Array(MidiDeviceInfo).new(LibPortMidi.count_devices) do |device_id|
      MidiDeviceInfo.new device_id
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

    private def check_open
      raise PortMidiException.new "Cannot access a closed stream" unless @opened
    end

    def close
      check_open
      PortMidi.check_error LibPortMidi.close @stream
      @opened = false
    end

    def abort
      check_open
      PortMidi.check_error LibPortMidi.abort @stream
      @opened = false
    end
  end

  class MidiInputStream < MidiStream
    def initialize(@device_id : Int32)
      super
      PortMidi.check_error LibPortMidi.open_input(out @stream, @device_id, nil, 512, nil, nil)
      @opened = true
    end

    # read midi short messages
    # TODO: make this method work with MidiMessage instead
    def read
      check_open
      buffer = StaticArray(LibPortMidi::PmEvent, 1024).new(LibPortMidi::PmEvent.new)
      # read() returns the number of events read
      # OR a negative integer (representing a PmError enum value)
      events_read = LibPortMidi.read(@stream, buffer, buffer.size)
      PortMidi.check_error LibPortMidi::PmError.new(events_read) if events_read < 0
      Array(MidiShortMessage).new(events_read) do |i|
        MidiShortMessage.from_i32(buffer[i].message)
      end
    end

    # calling poll after your stream is closed will crash it
    def poll
      check_open
      # result is 0 (false) ,1 (true), or PmError
      result = LibPortMidi.poll(@stream)
      return true if result.pm_got_data?
      return false if result.pm_no_data?
      PortMidi.check_error result
    end

    def set_filter(filter : Int32)
      check_open
      PortMidi.check_error LibPortMidi.set_filter(@stream, filter)
    end

    def set_channel_mask(mask : Int32)
      check_open
      PortMidi.check_error LibPortMidi.set_channel_mask(@stream, mask)
    end

    def listen(callback)
      check_open
      # TODO:
    end
  end

  class MidiOutputStream < MidiStream
    def initialize(@device_id : Int32)
      super
      PortMidi.check_error LibPortMidi.open_output(out @stream, @device_id, nil, 512, nil, nil, 0)
      @opened = true
    end

    # TODO: make this method work for all kinds of midi message
    # this only writes short messages ie."Channel Voice Messages" (not SysEx)
    # see: https://www.midi.org/specifications/item/table-1-summary-of-midi-message
    def write(messages : Array(MidiShortMessage))
      check_open
      # convert the MidiShortMessages into PmEvents that portmidi understands
      buffer = Array(LibPortMidi::PmEvent).new(messages.size) do |i|
        event = LibPortMidi::PmEvent.new
        event.timestamp = 0
        event.message = messages[i].to_i32
        event
      end
      PortMidi.check_error LibPortMidi.write(@stream, buffer, buffer.size)
    end

    def write_bytes(bytes : Array(UInt8))
    end

    def write_short(message : MidiShortMessage)
      check_open
      check_error LibPortMidi.write_short(@stream, 0, message.to_i32)
    end

    # message is just a sequence of bytes
    # message had better start with 0xFF and end with 0xF7
    # also the bytes between those delimiters can only be from 0x00 - 0x7F
    def write_sysex(message : Array(UInt8))
      check_open
      check_error LibPortMidi.write_sysex(@stream, 0, message)
    end
  end

  class PortMidiException < Exception
  end

  # this class is the same as the PmDeviceInfo struct
  # with the addition of the device id for added convenience
  class MidiDeviceInfo
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

    def to_input_stream
      return MidiInputStream.new @device_id if @input
      raise PortMidiException.new "Cannot create a MidiInputStream from this device"
    end

    def to_output_stream
      return MidiOutputStream.new @device_id if @output
      raise PortMidiException.new "Cannot create a MidiOutputStream from this device"
    end
  end
end

# turnon PortMidi
PortMidi.start
# get the midi streams (and open them)
d_in =
  PortMidi.get_all_midi_device_info.select { |d| d.input && d.name.match /2/ }[0].to_input_stream
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
p d_in.read if d_in.poll
# close them
d_in.close
d_out.close
# turn off PortMidi
PortMidi.stop
