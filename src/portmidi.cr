require "./portmidi/libportmidi.cr"

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

  def get_midi_device_info(device_id : Int32)
    MidiDeviceInfo.new device_id
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
      # if the stream is opened, @opened is set to true
    end

    def to_s(io : IO)
      MidiDeviceInfo.new(@device_id).to_s(io)
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

    def read
      check_open
      buffer = StaticArray(LibPortMidi::PmEvent, 1024).new(LibPortMidi::PmEvent.new)
      # read() returns the number of events read
      # OR a negative integer (representing a PmError enum value)
      events_read = LibPortMidi.read(@stream, buffer, buffer.size)
      PortMidi.check_error LibPortMidi::PmError.new(events_read) if events_read < 0
      Array(MidiEvent).new(events_read) do |i|
        MidiEvent.from_PmEvent(buffer[i])
      end
    end

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
  end

  class MidiOutputStream < MidiStream
    def initialize(@device_id : Int32)
      super
      PortMidi.check_error LibPortMidi.open_output(out @stream, @device_id, nil, 512, nil, nil, 0)
      @opened = true
    end

    # writes an array of MidiEvent
    def write(events : Array(MidiEvent))
      check_open
      buffer = Array(LibPortMidi::PmEvent).new(events.size) do |i|
        event = LibPortMidi::PmEvent.new
        event.timestamp = events[i].timestamp
        event.message = events[i].to_i32
        event
      end
      PortMidi.check_error LibPortMidi.write(@stream, buffer, buffer.size)
    end

    # writes midi short messages
    def write_short(status : Int32, data1 : Int32, data2 : Int32)
      write [MidiEvent.new status, data1, data2]
    end

    # writes sysex message from an array of UInt8
    # message must start with 0xFF and end with 0xF7
    # the bytes between those delimiters can only be from 0x00 - 0x7F
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
    getter :device_id, :name, :input, :output, :interf

    @input : Bool
    @output : Bool

    def initialize(device_id : Int32)
      device_info = get_pm_midi_device_info device_id
      @device_id = device_id
      @name = String.new device_info.name
      @input = device_info.input != 0
      @output = device_info.output != 0
      @interf = String.new device_info.interf
      # @opened is not immutable
      # hence we need a getter method which queries LibPortMidi with each access
      # to avoid the possibility of multiple objects refering to the same device_id
      # having a contradictory @opened instance variable between them
    end

    def to_s(io : IO)
      io << "#{@device_id} [input ]: #{@interf}, #{@name}" if @input
      io << "#{@device_id} [output]: #{@interf}, #{@name}" if @output
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

  # this is essentially a translation of the PortMidi PmEvent struct
  class MidiEvent
    getter :status, :data1, :data2, :data3, :timestamp

    def initialize(@status : Int32,
                   @data1 : Int32,
                   @data2 : Int32 = 0,
                   @data3 : Int32 = 0, # for use in sysex messages
                   @timestamp : Int32 = 0                   )
    end

    def to_s(io : IO)
      case @status
      when (0x80...0x90)
        io << "Note Off: #{@status}, #{@data1}, #{@data2}"
      when (0x90...0xA0)
        io << "Note On: #{@status}, #{@data1}, #{@data2}"
      when (0xA0...0xB0)
        io << "Polyphonic Key Pressure: #{@status}, #{@data1}, #{@data2}"
      when (0xB0...0xC0)
        io << "CC: #{@status}, #{@data1}, #{@data2}"
      when (0xC0...0xD0)
        io << "Program Change: #{@status}, #{@data1}, #{@data2}"
      when (0xD0...0xE0)
        io << "Aftertouch: #{@status}, #{@data1}, #{@data2}"
      when (0xE0...0xF0)
        io << "Pitch Bend: #{@status}, #{@data1}, #{@data2}"
      else
        # this handles sysex, and realtime messages
        io << "#{@status}, #{@data1}, #{@data2}, #{@data3}"
      end
    end

    # alias for status
    def data0
      @status
    end

    # creates a new MidiEvent from a PortMidi PmEvent
    def self.from_PmEvent(e : LibPortMidi::PmEvent)
      m = e.message
      self.new m & 0x000000FF,
        (m >> 8) & 0x000000FF,
        (m >> 16) & 0x000000FF,
        (m >> 24) & 0x000000FF,
        e.timestamp
    end

    # translates self's constituent bytes into an Int32 value
    # compatible with PortMidi's PmEvent.message order and size
    def to_i32 : Int32
      ((@data3 << 24) & 0xFF000000) |
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
end
