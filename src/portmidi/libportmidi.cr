require "lib_c"

@[Link("portmidi")]
lib LibPortMidi
  alias Int = LibC::Int
  #
  alias PortMidiStream = Void
  alias PmDeviceID = Int
  alias PmTimestamp = Int32
  alias PmTimeProcPtr = (Void* -> PmTimestamp)*
  alias PmMessage = Int32

  enum PmError
    PmNoError            =      0
    PmNoData             =      0
    PmGotData            =      1
    PmHostError          = -10000
    PmInvalidDeviceId
    PmInsufficientMemory
    PmBufferTooSmall
    PmBufferOverflow
    PmBadPtr
    PmBadData
    PmInternalError
    PmBufferMaxSize
  end

  struct PmDeviceInfo
    structVersion : Int
    interf : LibC::Char*
    name : LibC::Char*
    input : Int
    output : Int
    opened : Int
  end

  #@[Packed]
  struct PmEvent
    message : PmMessage
    timestamp : PmTimestamp
  end

  enum PM_FILT : Int32
    # filter active sensing messages (0xFE)
    ACTIVE = (1 << 0x0E)
    # filter system exclusive messages (0xF0)
    SYSEX = (1 << 0x00)
    # filter MIDI clock message (0xF8)
    CLOCK = (1 << 0x08)
    # filter play messages (start 0xFA, stop 0xFC, continue 0xFB)
    PLAY = ((1 << 0x0A) | (1 << 0x0C) | (1 << 0x0B))
    # filter tick messages (0xF9)
    TICK = (1 << 0x09)
    # filter undefined FD messages
    FD = (1 << 0x0D)
    # filter undefined real-time messages
    UNDEFINED = FD
    # filter reset messages (0xFF)
    RESET = (1 << 0x0F)
    # filter all real-time messages
    REALTIME = (ACTIVE | SYSEX | CLOCK | PLAY | UNDEFINED | RESET | TICK)
    # filter note-on and note-off (0x90-0x9F and 0x80-0x8F
    NOTE = ((1 << 0x19) | (1 << 0x18))
    # filter channel aftertouch (most midi controllers use this) (0xD0-0xDF
    CHANNEL_AFTERTOUCH = (1 << 0x1D)
    # per-note aftertouch (0xA0-0xAF)
    POLY_AFTERTOUCH = (1 << 0x1A)
    # filter both channel and poly aftertouch
    AFTERTOUCH = (CHANNEL_AFTERTOUCH | POLY_AFTERTOUCH)
    # Program changes (0xC0-0xCF)
    PROGRAM = (1 << 0x1C)
    # Control Changes (CC's) (0xB0-0xBF
    CONTROL = (1 << 0x1B)
    # Pitch Bender (0xE0-0xE
    PITCHBEND = (1 << 0x1E)
    # MIDI Time Code (0xF1
    MTC = (1 << 0x01)
    # Song Position (0xF2)
    SONG_POSITION = (1 << 0x02)
    # Song Select (0xF3
    SONG_SELECT = (1 << 0x03)
    # Tuning request (0xF6
    TUNE = (1 << 0x06)
    # All System Common messages (mtc, song position, song select, tune request)
    SYSTEMCOMMON = (MTC | SONG_POSITION | SONG_SELECT | TUNE)
  end

  fun initialize = Pm_Initialize : PmError
  fun terminate = Pm_Terminate : PmError
  fun has_host_error = Pm_HasHostError(stream : PortMidiStream*) : Int
  fun get_error_text = Pm_GetErrorText(errnum : PmError) : LibC::Char*
  fun count_devices = Pm_CountDevices : Int
  fun get_default_input_device_id = Pm_GetDefaultInputDeviceID : PmDeviceID
  fun get_default_ouput_device_id = Pm_GetDefaultOutputDeviceID : PmDeviceID
  fun get_device_info = Pm_GetDeviceInfo(id : PmDeviceID) : PmDeviceInfo*
  fun open_input = Pm_OpenInput(stream : PortMidiStream**,
                                inputDevice : PmDeviceID,
                                inputDriverInfo : Void*,
                                bufferSize : Int32,
                                time_proc : PmTimeProcPtr,
                                time_info : Void*) : PmError
  fun open_output = Pm_OpenOutput(stream : PortMidiStream**,
                                  outputDevice : PmDeviceID,
                                  outputDriverInfo : Void*,
                                  bufferSize : Int32,
                                  time_proc : PmTimeProcPtr,
                                  time_info : Void*,
                                  latency : Int32) : PmError
  fun set_filter = Pm_SetFilter(stream : PortMidiStream*, filter : Int32) : PmError
  fun set_channel_mask = Pm_setChannelMask(stream : PortMidiStream*, mask : Int) : PmError
  #
  fun abort = Pm_Abort(stream : PortMidiStream*) : PmError
  fun close = Pm_Close(stream : PortMidiStream*) : PmError
  fun synchronize = Pm_Synchronize(stream : PortMidiStream*) : PmError
  fun read = Pm_Read(stream : PortMidiStream*, buffer : PmEvent*, length : Int32) : Int
  fun poll = Pm_Poll(stream : PortMidiStream*) : PmError
  fun write = Pm_Write(stream : PortMidiStream*, buffer : PmEvent*, length : Int32) : PmError
  fun write_short = Pm_WriteShort(stream : PortMidiStream*, when : PmTimestamp, msg : Int32) : PmError
  fun write_sysex = Pm_WriteSysEx(stream : PortMidiStream*, when : PmTimestamp, msg : UInt8*) : PmError
end
