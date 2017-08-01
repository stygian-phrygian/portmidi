require "./portmidi/*"

class PortMidi

  @@opened_midi_streams = Hash(Int32, Void*).new

  def self.start()
    check_error(LibPortMidi.initialize)
    #populate_midi_devices
  end

  def self.stop()
    check_error LibPortMidi.terminate
    #@@midi_devices.clear
  end

  class PortMidiException < Exception
  end

  private def self.check_error(error : LibPortMidi::PmError)
    unless error == LibPortMidi::PmError::PmNoError
        raise PortMidiException.new String.new(LibPortMidi.get_error_text(error))
    end
  end

  def self.get_all_midi_devices()
    devices = Array(MidiDeviceInfo).new
    device_info : LibPortMidi::PmDeviceInfo
    LibPortMidi.count_devices().times do |device_id|
      device_info = LibPortMidi.get_device_info(device_id).value
      devices << MidiDeviceInfo.new(device_id, device_info) if device_info != 0
    end
    devices
  end

  def self.get_midi_inputs()
      devices = get_all_midi_devices.select {|d| d.input}
  end

  def self.get_midi_outputs()
      devices = get_all_midi_devices.select {|d| d.output}
  end


  class MidiDeviceInfo
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
    end

    def open()
      unless @opened
        if @input
          LibPortMidi.open_input(@stream.address, @device_id, 0, 512, 0, 0)
        else
          LibPortMidi.open_output(@stream.address, @device_id, 0, 512, 0, 0, 0)
        end
        @opened = true
      end
    end

    def close
      if @opened
        LibPortMidi.close(@stream)
        @opened = false
      end
    end

    def write
    end

    def read
    end

    def listen(callback)
    end

  end

end


PortMidi.start
#PortMidi.get_midi_inputs.each {|i| p i}
p PortMidi.get_all_midi_devices.select {|d| d.name.match /2/}
PortMidi.stop
#PortMidi::devices.each {|d| p d}
#PortMidi::terminate
