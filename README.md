# ahk-lpd8-wrapper
A wrapper that enables you to use the Akai LPD8 MIDI pad controller in Autohotkey v2.
You can react to these events:
* a pad being pressed
* a pad being released
* multiple pads being pressed at the same time
* control change events (either from the rotary knobs or the pads in CC mode).

## Dependencies
The wrapper uses [ahk-midi-wrapper](https://github.com/Crispy2/ahk-midi-wrapper).
Put the `midi_wrapper.ahk` file in the same directory as the `lpd8_wrapper.ahk` file.
If you want to have the files in different directories then you could use
[Symbolic Links](https://www.howtogeek.com/16226/complete-guide-to-symbolic-links-symlinks-on-windows-or-linux/) to achieve this.

## How to use
See the [examples](examples) folder for complete examples.

### Import the wrapper
First you need to import the wrapper. If your script is in a different directory to the `lpd8_wrapper.ahk` file then
change the path accordingly. The `midi_wrapper.ahk` file must always be in the same directory as the
`lpd8_wrapper.ahk` file though.

Using `Persistent` ensures that your script will keep running and be able to react to events. Otherwise it will
probably run all the setup and then exit. 
```autohotkey
#Include 'lpd8_wrapper.ahk'
Persistent
```

### Register callbacks
Callbacks are the functions that you want to run when an event occurs. To set them up, define a function that you want
to be triggered when the event happens, and then pass it to the appropriate `lpd8Add...Callback` function.

#### Pad pressed
```autohotkey
onPadPressed(channel, padId, velocity) {
    MsgBox('Pad ' . padId . ' pressed with velocity ' . velocity . ' on channel ' . channel)
}
lpd8AddPadPressedCallback(onPadPressed)
```
The `onPadPressed` function will run as soon as a pad is pressed.

#### Pad released
```autohotkey
onPadReleased(channel, padId, velocity) {
    MsgBox('Pad ' . padId . ' released on channel ' . channel)
}
lpd8AddPadReleasedCallback(onPadReleased)
```

The velocity value is included in the callback parameters, but in practice is always 127.

#### Control change
```autohotkey
onControlChange(channel, controllerId, value) {
    MsgBox('Controller ' . controllerId . ' changed to ' . value . ' on channel ' . channel)
}
lpd8AddControlChangeCallback(onControlChange)
```

#### Simultaneous pad presses (combos)
You can register a callback for combinations of pad presses.
Important things to note:
* the callback will be triggered if only a single pad is pressed
* the callback will only be triggered once all pads have been released
* multiple combinations are supported.

The callback must have one parameter, which will be an `Array`.
There will be one entry in the array for each combination of pad presses.
The order of the entries is the order in which the combinations occurred.
Each entry will itself be an array of `Lpd8MidiPadPress` objects.
Each `Lpd8MidiPadPress` object represents a single pad press and has these properties:
* channelId: the ID of the channel
* padId: the ID of the pad
* velocity: the velocity of the pad press.
 
The order of the `Lpd8MidiPadPress` objects is the order in which the pads were pressed.

See [examples/multiple_pad_presses.ahk](examples/multiple_pad_presses.ahk) for an example. Running the example script
will trigger a message box with details of combinations that occurred, so running the example script
and seeing what happens may be more helpful than the explanations below!

##### Simple 2-pad example

|  Time  |  Pad 1   |  Pad 2   |
|:------:|:--------:|:--------:|
|   1    | Pressed  |          |
|   2    |   Held   | Pressed  |
|   3    |   Held   | Released |
|   4    | Released |          |

This is a single combination of 2 presses: pad 1 and pad 2.
The callback will receive an array like this (with appropriate channel and velocity values):
```autohotkey
[
    [Lpd8MidiPadPress(channelId=1, padId=1, velocity=50),
    Lpd8MidiPadPress(channelId=1, padId=2, velocity=50)]
]
```

##### 3 pads together
| Time |  Pad 1   |  Pad 2   |  Pad 3   |
|:----:|:--------:|:--------:|:--------:|
|  1   | Pressed  |          |          |
|  2   |   Held   | Pressed  |          |
|  3   |   Held   |   Held   | Pressed  |
|  4   |   Held   | Released |   Held   |
|  5   |   Held   |          | Released |
|  6   | Released |          |          |

This is a single combination of 3 presses: pad 1, pad 2 and pad 3.
Note that the order in which the pads are released does not matter (i.e. the same result would occur if pad 3 were released before pad 2).

```autohotkey
[
    [Lpd8MidiPadPress(channelId=1, padId=1, velocity=50),
    Lpd8MidiPadPress(channelId=1, padId=2, velocity=50),
    Lpd8MidiPadPress(channelId=1, padId=3, velocity=50)]
]
```

##### 2 combinations
| Time |  Pad 1   |  Pad 2   |  Pad 3   |
|:----:|:--------:|:--------:|:--------:|
|  1   | Pressed  |          |          |
|  2   |   Held   | Pressed  |          |
|  3   |   Held   | Released |          |
|  4   |   Held   |          |          |
|  5   |   Held   |          | Pressed  |
|  6   |   Held   |          | Released |
|  7   | Released |          |          |

2 different combinations occurred:
* pad 1 and 2
* pad 1 and 3

```autohotkey
[
    [Lpd8MidiPadPress(channelId=1, padId=1, velocity=50),
    Lpd8MidiPadPress(channelId=1, padId=2, velocity=50)]
    ,
    [Lpd8MidiPadPress(channelId=1, padId=1, velocity=50),
    Lpd8MidiPadPress(channelId=1, padId=3, velocity=50)]
]
```

### Start listening for events
You must call the `lpd8Open` function to start listening for events. The MIDI device will be automatically closed when
the script exits.
```autohotkey
lpd8Open(LPD8_DEVICE_NAME, 600)
```


_Parameters_:
* name: the name of the MIDI device. The wrapper exposes `LPD8_DEVICE_NAME` (LPD8) which is the default name
* ccDebounceIntervalMs: the debounce interval (in ms) for control change events (see below)
* padIdsByNoteByChannel (optional): a mapping of pad IDs to note for each channel (see below)

_name_:
If the device has a different name, the `midi_wrapper.ahk` includes the function `midiGetAllDeviceNames()` which
returns an array of the names of all the MIDI devices, so that can be used to find the correct name.

_ccDebounceIntervalMs_:
Controller change events can be [debounced](https://dev.to/aneeqakhan/throttling-and-debouncing-explained-1ocb). This is
because when a rotary control is turned from 1 to 30 then separate events are sent for every new value
(2, 3, 4, 5, ..., 30). If this is desired, use 0 as the value of ```ccDebounceIntervalMs```.
If you are only interested in the final value of the control (30 in this case) then
specifying a suitable debounce interval will prevent the events for intermediate values from triggering your callback.
The suitable interval depends on the user (i.e. how quickly they move the control), but 600ms is a good starting point.

_padIdsByNoteByChannel_:
`Map(channel: Map(noteNumber: padId))`

E.g.
```autohotkey
Map (
    1, Map(
        36, 1,
        37, 2
    )
)
```
specifies

|  Channel | Note number | Pad number |
|---------:|------------:|-----------:|
|        1 |          36 |          1 |
|        1 |          37 |          2 |

The parameter is optional - if no value is specified then what I think are the default mappings are used instead.
You can check what note numbers are triggered by using a MIDI monitor such as [https://midi.chromatone.center](https://midi.chromatone.center)