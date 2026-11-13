## Startup

app-settings-reset-title = Instellingen hersteld
app-settings-reset-message = De instellingen in { $file } konden niet worden gelezen ({ $reason }). De standaardwaarden worden gebruikt; het oude bestand is bewaard als { $backup }.

## Crash recovery

app-crash-recovery-unavailable = Crashherstel is niet beschikbaar
app-crash-discard-failed = Kan het herstelde project niet verwerpen
app-crash-report-export-failed = Kan het rapport niet exporteren
app-crash-report-saved = Rapport opgeslagen
app-crash-report-exported = Crashrapport geëxporteerd naar { $path }
app-crash-reports-delete-failed = Kan crashrapporten niet verwijderen

## Timeline

app-timeline-loop-set-failed = Kan het lusgebied niet instellen
app-timeline-loop-clear-failed = Kan het lusgebied niet wissen
app-timeline-cue-add-failed = Kan de markering niet toevoegen
app-timeline-cue-remove-failed = Kan de markering niet verwijderen
app-timeline-cue-edit-failed = Kan de markering niet bewerken
app-timeline-bounce-failed = Kan het lusgebied niet bouncen
app-timeline-bounced-title = Gebounced naar een nieuwe bron
app-timeline-bounced-message = Het lusgebied staat nu in de bronnenlijst.

## Background work

app-job-cancelled = Achtergrondtaak { $id } is geannuleerd.
app-job-failed = Achtergrondtaak mislukt
app-blocking-timeout-title = Bewerking duurde te lang
app-blocking-timeout-message = ‘{ $task }’ was niet binnen { $seconds } s klaar en is vrijgegeven; de taak loopt op de achtergrond door.
app-blocking-cancelled = ‘{ $task }’ is geannuleerd voordat het begon.
app-blocking-failed = Bewerking mislukt

## Recording

app-recording-arm-failed = Kan de track niet opnamegereed maken
app-recording-input-on-title = Audio-invoer aan
app-recording-input-on-message = De audio-invoer stond uit en is ingeschakeld. Wijzig het invoerapparaat in Instellingen.
app-recording-nothing-title = Niets om op te nemen
app-recording-nothing-message = Selecteer een audiotrack om op op te nemen.
app-recording-save-failed = Kan de opname niet opslaan
app-recordings-save-failed = Kan de opnamen niet opslaan

## Project

app-project-recover-failed = Kan het project niet herstellen
app-project-audio-load-failed = Kan audio niet laden
app-project-source-delete-failed = Kan de audiobron niet verwijderen
app-project-source-replace-failed = Kan de audiobron niet vervangen
app-project-pattern-delete-failed = Kan het patroon niet verwijderen
app-project-info-update-failed = Kan projectinformatie niet bijwerken
app-project-undo-failed = Kan niet ongedaan maken
app-project-redo-failed = Kan niet opnieuw uitvoeren
app-project-refresh-failed = { $action }: project vernieuwen mislukt
app-project-instrument-rename-failed = Kan het instrument niet hernoemen
app-project-trim-failed = Kan de audio niet inkorten
app-project-envelope-edit-failed = Kan de golfvormenvelop niet bewerken
app-project-saved-title = Project opgeslagen
app-project-saved-message = Project opgeslagen in { $path }

## Automation targets

app-automation-missing-effect = Ontbrekend effect
app-automation-sampler = Sampler
app-automation-missing-instrument = Ontbrekend instrument
app-automation-track = Track
app-automation-bus = Bus
app-automation-master = Master
app-automation-transport = Transport
app-automation-other-group = Overig

## Tracks

app-tracks-input-change-failed = Kan de invoer van de track niet wijzigen
app-tracks-samples-audio-only = Audiosamples kunnen alleen op audiotracks worden neergezet
app-tracks-move-type-mismatch = { $source ->
    [audio] Audio
    [midi] MIDI-
   *[automation] Automatiserings
}{ $count ->
    [one] clip kan
   *[other] clips kunnen
} niet naar een { $target ->
    [audio] audiotrack
    [midi] MIDI-track
   *[automation] automatiseringstrack
} worden verplaatst

## Mixer channel templates

app-mixer-template-save-failed = Kan het kanaalsjabloon niet opslaan
app-mixer-template-saved = Kanaalsjabloon opgeslagen in { $path }
app-mixer-template-load-failed = Kan het kanaalsjabloon niet laden
app-mixer-template-loaded = Kanaalsjabloon geladen
app-mixer-template-skipped = Niet-beschikbare plug-ins overgeslagen: { $plugins }

## Menu bar

app-menu-project = Project
app-menu-new-project = Nieuw project
app-menu-open-project = Project openen
app-menu-open-recent = Recent openen
app-menu-save-project = Project opslaan
app-menu-save-as = Opslaan als...
app-menu-import-audio = Audio importeren
app-menu-export-project = Project exporteren
app-menu-settings = Instellingen
app-menu-quit = { -app-name } afsluiten
app-menu-edit = Bewerken
app-menu-undo = Ongedaan maken
app-menu-redo = Opnieuw
app-menu-view = Beeld
app-menu-zoom-in = Inzoomen
app-menu-zoom-out = Uitzoomen
