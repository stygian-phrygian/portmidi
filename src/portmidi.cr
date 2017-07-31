require "./portmidi/*"

lib C
  fun printf(format : UInt8*, ...) : Int32
end

module PortMidi

  def initialize()
    LibPortMidi.initialize()
  end

  def terminate()
    LibPortMidi.terminate()
  end

  # c String to crystal String
  private def cs_to_s(p : LibC::Char*)
    return "" unless p
    s = String.build do |sb|
      while p.value != 0
        sb << p.value.chr
        p = p + 1
      end
    end
    s
  end

  private def get_midi_devices() : Array(MidiDevice)
    devices = Array(MidiDevice)
    deviceInfo : LibPortMidi::PmDeviceInfo
    LibPortMidi.count_devices().times do |deviceID|
      deviceInfo = LibPortMidi.get_device_info(deviceID).value
      #TODO
    end
    return devices
  end

  struct MidiDevice
    # stream
    private def initialize
    end
    def self.open(deviceID : Int32)
    end
    def close
    end
    def write
    end
    def read
    end
    def listen(callback)
    end
  end

  # struct PmDeviceInfo
  #   structVersion : Int
  #   interf        : LibC::Char*
  #   name          : LibC::Char*
  #   input         : Int
  #   output        : Int
  #   opened        : Int
  # end
end
# testing
##
puts "The number of available midi devices is:"
number_of_devices = LibPortMidi.count_devices()
puts number_of_devices
#
puts "the devices are: "
number_of_devices.times do |i|
    info = LibPortMidi.get_device_info(i).value
    puts i.to_s + cs_to_s(info.name)
end

