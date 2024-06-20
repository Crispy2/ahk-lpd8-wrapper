#Include 'midi_wrapper.ahk'

LPD8_DEVICE_NAME := 'LPD8'  ; The default MIDI device name of the LPD8 pad

class Lpd8MidiPadPress {
	__New(channelId, padId, velocity) {
		this.channelId := channelId
		this.padId := padId
		this.velocity := velocity
	}
}

lpd8_InternalPadComboCallbacks := Array()
lpd8_InternalActivePadCombo := Array()
lpd8_InternalCompletedPadCombos := Array()
lpd8_InternalLastActiveCombo := Array()
lpd8_InternalPadPressedSinceLastRelease := false
lpd8_InternalPadIdsByNoteByChannel := []

DEFAULT_PAD_IDS_BY_NOTE_BY_CHANNEL := Map(
	1, Map(
		36, 1,
		37, 2,
		38, 3,
		39, 4,
		40, 5,
		41, 6,
		42, 7,
		43, 8
	),
	2, Map(
		35, 1,
		36, 2,
		42, 3,
		39, 4,
		37, 5,
		38, 6,
		46, 7,
		44, 8
	),
	3, Map(
		60, 1,
		62, 2,
		64, 3,
		65, 4,
		67, 5,
		69, 6,
		71, 7,
		72, 8
	),
	4, Map(
		36, 1,
		38, 2,
		40, 3,
		41, 4,
		43, 5,
		45, 6,
		47, 7,
		48, 8
	),
)



/*
	Add a callback for when a pad is pressed.
	Expects callback(channel, padId, velocity)
*/
lpd8AddPadPressedCallback(callback) {
	global lpd8_InternalPadIdsByNoteByChannel, midiNoteOnCallbacks
	midiNoteOnCallbacks.push(padPressedCallback)

	padPressedCallback(channel, noteNum, velocity) {
		padId := lpd8_InternalPadIdsByNoteByChannel[channel][noteNum]
		callback(channel, padId, velocity)
	}
}

/*
    Add a callback for when a pad is released.
	Expects callback(channel, padId, velocity)
*/
lpd8AddPadReleasedCallback(callback) {
	global lpd8_InternalPadIdsByNoteByChannel, midiNoteOffCallbacks
	midiNoteOffCallbacks.push(padReleasedCallback)

	padReleasedCallback(channel, noteNum, velocity) {
		padId := lpd8_InternalPadIdsByNoteByChannel[channel][noteNum]
		callback(channel, padId, velocity)
	}
}

/*
    Add a callback for when a control change event is received.
	Expects callback(channel, controllerId, velocity)
*/
lpd8AddControlChangeCallback(callback) {
	global midiControlChangeCallbacks
	midiControlChangeCallbacks.Push(callback)
}

/*
    Add a callback for pad presses. Handles multi-pad combinations.
	Expects callback(pads: [[Lpd8MidiPadPress]]).
	Multiple combos can be fired e.g. 1-on, 2-on, 2-off, 3-on, 3-off, 1-off would be 2 combos of [1, 2], [1, 3].
	Also calls callback for single pad presses.
	Only calls callback when all pads are released.
*/
lpd8AddPadCombosCallback(callback) {
	global lpd8_InternalPadComboCallbacks
	lpd8_InternalPadComboCallbacks.Push(callback)
}

/*
    Start monitoring an LPD8 pad for events.

    name: the name of the MIDI device
    ccDebounceIntervalMs: the debounce interval (in ms) for control change events
*/
lpd8Open(name, ccDebounceIntervalMs, padIdsByNoteByChannel?) {
    global lpd8_InternalPadIdsByNoteByChannel

    if (IsSet(padIdsByNoteByChannel)) {
        lpd8_InternalPadIdsByNoteByChannel := padIdsByNoteByChannel
    } else {
        lpd8_InternalPadIdsByNoteByChannel := DEFAULT_PAD_IDS_BY_NOTE_BY_CHANNEL
    }
	deviceIndex := -1

	for deviceName in midiGetAllDeviceNames() {
		if (deviceName == name) {
			deviceIndex := A_Index - 1
			break
		}
	}

	if (deviceIndex == -1) {
		throw ValueError('midi device ' . name . ' not found')
	}

	lpd8AddPadPressedCallback(lpd8_InternalMultiPadHandlerOnPadPressed)
	lpd8AddPadReleasedCallback(lpd8_InternalMultiPadHandlerOnPadReleased)

	midiOpenDeviceForInput(deviceIndex, ccDebounceIntervalMs)
}

; Internal use only. Called when a pad is pressed
lpd8_InternalMultiPadHandlerOnPadPressed(channel, padId, velocity) {
	global lpd8_InternalPadPressedSinceLastRelease
	lpd8_InternalPadPressedSinceLastRelease := true
	lpd8_InternalActivePadCombo.push(Lpd8MidiPadPress(channel, padId, velocity))
}

; Internal use only. Called when a pad is released
lpd8_InternalMultiPadHandlerOnPadReleased(channel, padId, velocity) {
	global lpd8_InternalPadPressedSinceLastRelease

	if (lpd8_InternalPadPressedSinceLastRelease) {
		completedCombo := Array()
		for press in lpd8_InternalActivePadCombo {
			completedCombo.Push(press)
			lpd8_InternalLastActiveCombo.push(press)
		}
		lpd8_InternalCompletedPadCombos.push(completedCombo)
	}

	for press in lpd8_InternalActivePadCombo {
		if (press.padId == padId) {
			lpd8_InternalActivePadCombo.removeAt(A_Index)
			break
		}
	}

	if (lpd8_InternalActivePadCombo.Length == 0) {
		for callback in lpd8_InternalPadComboCallbacks {
			SetTimer lpd8_InternalCreateComboCallbackClosure(callback, lpd8_InternalCompletedPadCombos.Clone()), -1
		}


		loop lpd8_InternalCompletedPadCombos.Length {
			lpd8_InternalCompletedPadCombos.pop()
		}
	}
	lpd8_InternalPadPressedSinceLastRelease := false
}

; Internal use only. Creates a closure for the combo callback
lpd8_InternalCreateComboCallbackClosure(callback, combos) {
	wrapper() {
		callback(combos)
	}
	return wrapper
}

/*
    Converts the value from a rotary control knob to the dot number.

    value: the value from the rotary control knob (0-127)

    Returns the dot number (excluding the min and max points). Dot above min=1, Middle dot (i.e. up)=5, dot above max=9

*/
lpd8SnapKnobValueToDot(value) {
	dotValues := [2, 16, 31, 48, 64, 81, 98, 114, 127]
	for dotValue in dotValues {
		if (A_Index == dotValues.Length) {
			return A_Index
		}
		if (value <= (((dotValues[A_Index+1] - dotValue)/2) + dotValue)) {
			return A_Index
		}
	}
}