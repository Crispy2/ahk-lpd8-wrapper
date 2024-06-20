#Include '../lpd8_wrapper.ahk'
Persistent

onPadCombos(combos) {
    msg := ''
    separator := ''
    for presses in combos {
        msg := msg . separator . 'Combo ' . A_Index . ': '
        msg := msg . getDescriptionOfPresses(presses)
        separator := '`n'
    }
    MsgBox(msg)
}

getDescriptionOfPresses(presses) {
	msg := ''
	separator := ''
	for press in presses {
		msg := msg . separator . press.padId
		separator := ', '
	}
	return msg
}

lpd8AddPadCombosCallback(onPadCombos)
lpd8Open(LPD8_DEVICE_NAME, 600)