require "./portmidi/*"

module PortMidi
end
# testing
##
puts "The number of available midi devices is:"
number_of_devices = LibPortMidi.count_devices()
puts number_of_devices
#

#number_of_devices.times do |i|
#    info = PortMidi.get_device_info(i).value
#    puts info.name
#end

