#Include '../lpd8_wrapper.ahk'
Persistent


onPadPressed(channel, padId, velocity) {
    MsgBox('Pad ' . padId . ' pressed with velocity ' . velocity . ' on channel ' . channel)
}

onPadReleased(channel, padId, velocity) {
    MsgBox('Pad ' . padId . ' released on channel ' . channel)
}

lpd8AddPadPressedCallback(onPadPressed)
lpd8AddPadReleasedCallback(onPadReleased)
lpd8Open(LPD8_DEVICE_NAME, 600)