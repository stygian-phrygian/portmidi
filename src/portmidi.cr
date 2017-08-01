require "./portmidi/*"

module PortMidi
  extend self

  def start
    check_error(LibPortMidi.initialize)
    # populate_midi_devices
  end

  def stop
    check_error LibPortMidi.terminate
    # @@midi_devices.clear
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

  private class MidiDevice
    @@opened_streams = Hash(Int32, LibPortMidi::PortMidiStream*).new

    # this class is the same as the PmDeviceInfo struct
    # with the addition of the device id for added convenience

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

    def open
      unless @@opened_streams[@device_id]?
        if @input
          LibPortMidi.open_input(out @stream, @device_id, nil, 512, nil, nil)
        else
          LibPortMidi.open_output(out @stream, @device_id, nil, 512, nil, nil, 0)
        end
        @opened = true
        @@opened_streams[@device_id] = @stream
      end
    end

    def close
      if @@opened_streams[@device_id]?
        LibPortMidi.close(@stream)
        @opened = false
        @@opened_streams.delete @device_id
        @stream.value = nil
      end
    end

    def write(bytes)
    end

    def read
    end

    def listen(callback)
    end
  end
end

PortMidi.start
d_in = PortMidi.get_all_midi_devices.select { |d| d.input }[0]
d_out = PortMidi.get_all_midi_devices.select { |d| d.output }[0]
d_in.open
d_out.open
p d_in
p d_out
d_in.close
d_out.close

# p PortMidi.get_all_midi_devices.select {|d| d.input }
# p PortMidi.get_all_midi_devices.select {|d| d.name.match /2/}
PortMidi.stop
