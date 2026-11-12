## Startup

app-settings-reset-title = Settings reset
app-settings-reset-message = Settings in { $file } could not be read ({ $reason }). Defaults are used; the old file was kept as { $backup }.

## Crash recovery

app-crash-recovery-unavailable = Crash recovery is unavailable
app-crash-discard-failed = Could not discard the recovered project
app-crash-report-export-failed = Could not export the report
app-crash-report-saved = Report saved
app-crash-report-exported = Crash report exported to { $path }
app-crash-reports-delete-failed = Could not delete crash reports

## Timeline

app-timeline-loop-set-failed = Could not set the loop region
app-timeline-loop-clear-failed = Could not clear the loop region
app-timeline-cue-add-failed = Could not add the cue marker
app-timeline-cue-remove-failed = Could not remove the cue marker
app-timeline-cue-edit-failed = Could not edit the cue marker
app-timeline-bounce-failed = Could not bounce the loop region
app-timeline-bounced-title = Bounced to a new source
app-timeline-bounced-message = The loop region is now in the source list.

## Background work

app-job-cancelled = Background job { $id } was cancelled.
app-job-failed = Background task failed
app-blocking-timeout-title = Operation timed out
app-blocking-timeout-message = “{ $task }” did not finish within { $seconds } s and was released; it continues in the background.
app-blocking-cancelled = “{ $task }” was cancelled before it started.
app-blocking-failed = Operation failed

## Recording

app-recording-arm-failed = Could not arm the track
app-recording-input-on-title = Audio input on
app-recording-input-on-message = Audio input was off, so it was turned on. Change the input device in Settings.
app-recording-nothing-title = Nothing to record
app-recording-nothing-message = Select an audio track to record on.
app-recording-save-failed = Could not save the recording
app-recordings-save-failed = Could not save the recordings

## Project

app-project-recover-failed = Could not recover the project
app-project-audio-load-failed = Could not load audio
app-project-source-delete-failed = Could not delete the audio source
app-project-pattern-delete-failed = Could not delete the pattern
app-project-info-update-failed = Could not update project information
app-project-undo-failed = Could not undo
app-project-redo-failed = Could not redo
app-project-refresh-failed = { $action }: project refresh failed
app-project-instrument-rename-failed = Could not rename the instrument
app-project-trim-failed = Could not trim the audio
app-project-envelope-edit-failed = Could not edit the waveform envelope

## Automation targets

app-automation-missing-effect = Missing effect
app-automation-sampler = Sampler
app-automation-missing-instrument = Missing instrument
app-automation-track = Track
app-automation-bus = Bus
app-automation-master = Master
app-automation-transport = Transport
app-automation-other-group = Other

## Tracks

app-tracks-input-change-failed = Could not change the track input
app-tracks-samples-audio-only = Audio samples can only be dropped on audio tracks
app-tracks-move-type-mismatch = Cannot move { $source ->
    [audio] audio
    [midi] MIDI
   *[automation] automation
} { $count ->
    [one] clip
   *[other] clips
} to { $target ->
    [audio] an audio
    [midi] a MIDI
   *[automation] an automation
} track

## Mixer channel templates

app-mixer-template-save-failed = Could not save channel template
app-mixer-template-saved = Saved channel template to { $path }
app-mixer-template-load-failed = Could not load channel template
app-mixer-template-loaded = Loaded channel template
app-mixer-template-skipped = Skipped unavailable plugins: { $plugins }

## Menu bar

app-menu-project = Project
app-menu-new-project = New project
app-menu-open-project = Open project
app-menu-open-recent = Open recent
app-menu-save-project = Save Project
app-menu-save-as = Save As...
app-menu-import-audio = Import Audio
app-menu-export-project = Export Project
app-menu-settings = Settings
app-menu-quit = Quit { -app-name }
app-menu-edit = Edit
app-menu-undo = Undo
app-menu-redo = Redo
app-menu-view = View
app-menu-zoom-in = Zoom in
app-menu-zoom-out = Zoom out

app-project-saved-title = Project saved
app-project-saved-message = Project successfully saved to { $path }
