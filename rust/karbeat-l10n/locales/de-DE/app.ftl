## Startup

app-settings-reset-title = Einstellungen zurückgesetzt
app-settings-reset-message = Die Einstellungen in { $file } konnten nicht gelesen werden ({ $reason }). Es werden die Standardwerte verwendet; die alte Datei wurde als { $backup } aufbewahrt.

## Crash recovery

app-crash-recovery-unavailable = Die Absturzwiederherstellung ist nicht verfügbar
app-crash-discard-failed = Das wiederhergestellte Projekt konnte nicht verworfen werden
app-crash-report-export-failed = Der Bericht konnte nicht exportiert werden
app-crash-report-saved = Bericht gespeichert
app-crash-report-exported = Absturzbericht nach { $path } exportiert
app-crash-reports-delete-failed = Absturzberichte konnten nicht gelöscht werden

## Timeline

app-timeline-loop-set-failed = Loop-Bereich konnte nicht festgelegt werden
app-timeline-loop-clear-failed = Loop-Bereich konnte nicht entfernt werden
app-timeline-cue-add-failed = Marker konnte nicht hinzugefügt werden
app-timeline-cue-remove-failed = Marker konnte nicht entfernt werden
app-timeline-cue-edit-failed = Marker konnte nicht bearbeitet werden
app-timeline-bounce-failed = Loop-Bereich konnte nicht gebounct werden
app-timeline-bounced-title = In eine neue Quelle gebounct
app-timeline-bounced-message = Der Loop-Bereich ist jetzt in der Quellenliste.

## Background work

app-job-cancelled = Hintergrundaufgabe { $id } wurde abgebrochen.
app-job-failed = Hintergrundaufgabe fehlgeschlagen
app-blocking-timeout-title = Zeitüberschreitung
app-blocking-timeout-message = „{ $task }“ wurde nicht innerhalb von { $seconds } s fertig und freigegeben; die Aufgabe läuft im Hintergrund weiter.
app-blocking-cancelled = „{ $task }“ wurde vor dem Start abgebrochen.
app-blocking-failed = Vorgang fehlgeschlagen

## Recording

app-recording-arm-failed = Spur konnte nicht scharf geschaltet werden
app-recording-input-on-title = Audioeingang eingeschaltet
app-recording-input-on-message = Der Audioeingang war aus und wurde eingeschaltet. Das Eingabegerät kannst du in den Einstellungen ändern.
app-recording-nothing-title = Nichts aufzunehmen
app-recording-nothing-message = Wähle eine Audiospur für die Aufnahme.
app-recording-save-failed = Aufnahme konnte nicht gespeichert werden
app-recordings-save-failed = Aufnahmen konnten nicht gespeichert werden

## Project

app-project-recover-failed = Projekt konnte nicht wiederhergestellt werden
app-project-audio-load-failed = Audio konnte nicht geladen werden
app-project-source-delete-failed = Audioquelle konnte nicht gelöscht werden
app-project-pattern-delete-failed = Pattern konnte nicht gelöscht werden
app-project-info-update-failed = Projektinformationen konnten nicht aktualisiert werden
app-project-undo-failed = Rückgängig machen nicht möglich
app-project-redo-failed = Wiederholen nicht möglich
app-project-refresh-failed = { $action }: Projekt konnte nicht aktualisiert werden
app-project-instrument-rename-failed = Instrument konnte nicht umbenannt werden
app-project-trim-failed = Audio konnte nicht getrimmt werden
app-project-envelope-edit-failed = Wellenform-Hüllkurve konnte nicht bearbeitet werden
app-project-saved-title = Projekt gespeichert
app-project-saved-message = Projekt unter { $path } gespeichert

## Automation targets

app-automation-missing-effect = Fehlender Effekt
app-automation-sampler = Sampler
app-automation-missing-instrument = Fehlendes Instrument
app-automation-track = Spur
app-automation-bus = Bus
app-automation-master = Master
app-automation-transport = Transport
app-automation-other-group = Sonstige

## Tracks

app-tracks-input-change-failed = Eingang der Spur konnte nicht geändert werden
app-tracks-samples-audio-only = Audio-Samples können nur auf Audiospuren abgelegt werden
app-tracks-move-type-mismatch = { $source ->
    [audio] Audio
    [midi] MIDI
   *[automation] Automations
}-{ $count ->
    [one] Clip kann
   *[other] Clips können
} nicht auf eine { $target ->
    [audio] Audiospur
    [midi] MIDI-Spur
   *[automation] Automationsspur
} verschoben werden

## Mixer channel templates

app-mixer-template-save-failed = Kanalvorlage konnte nicht gespeichert werden
app-mixer-template-saved = Kanalvorlage unter { $path } gespeichert
app-mixer-template-load-failed = Kanalvorlage konnte nicht geladen werden
app-mixer-template-loaded = Kanalvorlage geladen
app-mixer-template-skipped = Nicht verfügbare Plugins übersprungen: { $plugins }

## Menu bar

app-menu-project = Projekt
app-menu-new-project = Neues Projekt
app-menu-open-project = Projekt öffnen
app-menu-open-recent = Zuletzt geöffnet
app-menu-save-project = Projekt speichern
app-menu-save-as = Speichern unter...
app-menu-import-audio = Audio importieren
app-menu-export-project = Projekt exportieren
app-menu-settings = Einstellungen
app-menu-quit = { -app-name } beenden
app-menu-edit = Bearbeiten
app-menu-undo = Rückgängig
app-menu-redo = Wiederholen
app-menu-view = Ansicht
app-menu-zoom-in = Vergrößern
app-menu-zoom-out = Verkleinern
