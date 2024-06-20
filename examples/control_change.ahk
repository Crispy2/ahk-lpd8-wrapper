#Include '../lpd8_wrapper.ahk'
Persistent

onControlChange(channel, controllerId, value) {
    msg := 'Controller ' . controllerId . ' changed to ' . value . ' (dot ' . lpd8SnapKnobValueToDot(value) . ') on channel ' . channel
    MsgBox(msg)
}

lpd8AddControlChangeCallback(onControlChange)
lpd8Open(LPD8_DEVICE_NAME, 600)