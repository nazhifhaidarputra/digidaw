## Note edits and pattern transport

piano-roll-notes-action-failed = { $action ->
    [quantize] Could not quantize notes
    [legato] Could not apply legato to notes
    [humanize] Could not humanize notes
    [chop] Could not chop notes
    [slice] Could not slice the note
    [transpose] Could not transpose notes
    [stretch] Could not stretch notes
    [shift] Could not shift notes
    [draw] Could not draw notes
    [duplicate] Could not duplicate notes
   *[edit] Could not edit notes
}
piano-roll-choose-generator = Choose a generator to play this pattern
piano-roll-transport-failed = { $action ->
    [play] Could not play the pattern
    [stop] Could not stop the pattern
    [seek] Could not move the pattern playhead
   *[loop] Could not set the loop region
}

piano-roll-this-pattern-has-no-notes = This pattern has no notes.
piano-roll-velocity = Velocity
piano-roll-pitch = Pitch
piano-roll-pan = Pan
piano-roll-pattern-loop = Pattern loop
piano-roll-clear-loop-region = Clear loop region
piano-roll-select-region-tool = Select Region tool
piano-roll-quantize = Quantize
piano-roll-quantize-start-times = Quantize start times
piano-roll-legato = Legato
piano-roll-humanize = Humanize
piano-roll-chop-into-steps = Chop into steps
piano-roll-stretch = Stretch
piano-roll-longer-1-25 = Longer 1.25×
piano-roll-longer-1-5 = Longer 1.5×
piano-roll-longer-2 = Longer 2×
piano-roll-shorter-0-75 = Shorter 0.75×
piano-roll-shorter-0-5 = Shorter 0.5×
piano-roll-transpose = Transpose
piano-roll-up-a-semitone = Up a semitone
piano-roll-down-a-semitone = Down a semitone
piano-roll-up-an-octave = Up an octave
piano-roll-down-an-octave = Down an octave
piano-roll-shift-in-time = Shift in time
piano-roll-left-one-step = Left one step
piano-roll-right-one-step = Right one step
piano-roll-note-properties = Note properties…
piano-roll-copy = Copy
piano-roll-cut = Cut
piano-roll-paste = Paste
piano-roll-more = More…
piano-roll-keyboard = Keyboard
piano-roll-note-parameters = Note parameters
piano-roll-stop-and-rewind = Stop and rewind
piano-roll-switch-pattern = Switch pattern
piano-roll-grab-alt-1 = Grab (Alt+1)
piano-roll-draw-stamps-the-last-selection = Draw: stamps the last selection (Alt+2)
piano-roll-delete-alt-3 = Delete (Alt+3)
piano-roll-select-alt-4 = Select (Alt+4)
piano-roll-select-region-drag-the-ruler = Select region: drag the ruler to loop (Alt+5)
piano-roll-slice-alt-6 = Slice (Alt+6)
piano-roll-stretch-selected-notes-alt-9 = Stretch selected notes (Alt+9)
piano-roll-pan-alt-7 = Pan (Alt+7)
piano-roll-zoom-alt-8 = Zoom (Alt+8)
piano-roll-zoom-in = Zoom In
piano-roll-zoom-out = Zoom Out
piano-roll-shorter-note-rows-alt-scroll = Shorter note rows (Alt+scroll)
piano-roll-taller-note-rows-alt-scroll = Taller note rows (Alt+scroll)
piano-roll-note-tools-quantize-legato-chop = Note tools: quantize, legato, chop, transpose…
piano-roll-snap-step-for-drawing-and = Snap step for drawing and moving notes
piano-roll-grid = Grid

piano-roll-param-draw-hint = Drag across the lane to draw values.
piano-roll-param-draw-selection = Drawing edits the { $count } selected notes.
piano-roll-mixed = Mixed
piano-roll-note-properties-title = Note properties
piano-roll-note-properties-count = Note properties · { $count } notes
piano-roll-all-notes = All notes
piano-roll-notes-count = { $count ->
    [one] { $count } note
   *[other] { $count } notes
}
piano-roll-midi-controller = MIDI CONTROLLER
piano-roll-octave-key = Octave { $octave } · Key { $key }
piano-roll-octave = OCTAVE
piano-roll-range = RANGE
piano-roll-select-synth = Select Synth
piano-roll-key = KEY
piano-roll-no-pattern-selected = No Pattern Selected
piano-roll-no-patterns = No Patterns Available
piano-roll-choose-pattern = Choose a Pattern
piano-roll-pattern-not-found = Pattern not found
piano-roll-pause = Pause (Space)
piano-roll-play = Play pattern (Space)
piano-roll-grid-label = Grid{" "}
piano-roll-step-label = Step{" "}
piano-roll-generator-label = Generator:{" "}
piano-roll-open-plugin-unavailable = Choose a plugin generator to open its screen
piano-roll-open-plugin = Open plugin screen
