require "./portmidi/*"

module PortMidi
  extend self

  def start
    check_error LibPortMidi.initialize
  end

  def stop
    check_error LibPortMidi.terminate
  end

  class PortMidiException < Exception
  end

  private def check_error(error : LibPortMidi::PmError)
    unless error == LibPortMidi::PmError::PmNoError
      raise PortMidiException.new String.new(LibPortMidi.get_error_text(error))
    end
  end

  def get_all_midi_devices
    devices = Array(MidiDevice).new
    device_info : LibPortMidi::PmDeviceInfo
    LibPortMidi.count_devices.times do |device_id|
      device_info = LibPortMidi.get_device_info(device_id).value
      devices << MidiDevice.new(device_id, device_info) if device_info != 0
    end
    devices
  end

  # this class is the same as the PmDeviceInfo struct
  # with the addition of the device id for added convenience
  private class MidiDevice
    @@opened_streams = Hash(Int32, LibPortMidi::PortMidiStream*).new

    # these need type specification (else crystal refuses to compile)
    @input : Bool
    @output : Bool

    getter :input, :output, :opened, :name, :device_id

    def initialize(device_id : Int32, device_info : LibPortMidi::PmDeviceInfo)
      @device_id = device_id
      @name = String.new(device_info.name)
      @input = device_info.input != 0
      @output = device_info.output != 0
      @opened = device_info.opened != 0
      @stream = uninitialized LibPortMidi::PortMidiStream*
    end

    private def check_error(error : LibPortMidi::PmError)
      unless error == LibPortMidi::PmError::PmNoError
        raise PortMidiException.new String.new(LibPortMidi.get_error_text(error))
      end
    end

    def open
      unless @@opened_streams[@device_id]?
        if @input
          check_error LibPortMidi.open_input(out @stream, @device_id, nil, 512, nil, nil)
        else
          check_error LibPortMidi.open_output(out @stream, @device_id, nil, 512, nil, nil, 0)
        end
        @opened = true
        @@opened_streams[@device_id] = @stream
      end
    end

    def close
      if @@opened_streams[@device_id]?
        check_error LibPortMidi.close(@stream)
        @opened = false
        @@opened_streams.delete @device_id
        @stream.value = nil
      end
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
      check_error LibPortMidi.write(@stream, buffer, buffer.size)
    end

    def read
      buffer = StaticArray(LibPortMidi::PmEvent, 1024).new(LibPortMidi::PmEvent.new)
      # read() returns the number of events read
      # OR a negative integer (representing a PmError enum value)
      events_read = LibPortMidi.read(@stream, buffer, buffer.size)
      check_error LibPortMidi::PmError.new(events_read) if events_read < 0
      Array(MidiMessage).new(events_read.to_i32) do |i|
        MidiMessage.from_i32(buffer[i].message)
      end
    end

    def listen(callback)
    end
  end
end

PortMidi.start
# # get the devices
# d_in = PortMidi.get_all_midi_devices.select { |d| d.input && d.name.match /2/ }[0]
# d_out = PortMidi.get_all_midi_devices.select { |d| d.output }[0]
# # open them
# d_in.open
# d_out.open
# # log them
# p d_in
# p d_out
# # write midi out
# d_out.write([note_on(56), note_on(77)])
# sleep(3)
# d_out.write([note_off(56), note_off(77)])
# # get midi in
# messages = d_in.read
# p messages
# # close them
# d_in.close
# d_out.close
#
# d_in0 = PortMidi.get_all_midi_devices.select { |d| d.input && d.name.match /2/ }[0]
# d_in1 = PortMidi.get_all_midi_devices.select { |d| d.input && d.name.match /2/ }[0]
# d_out0 = PortMidi.get_all_midi_devices.select { |d| d.output }[0]
# d_out1 = PortMidi.get_all_midi_devices.select { |d| d.output }[0]
# # open them
# d_in0.open
# d_in1.open
# d_out0.open
# d_out1.open
# 
# # close them
# d_in0.close
# d_in1.close
# d_out0.close
# d_out1.close
# 
PortMidi.stop
