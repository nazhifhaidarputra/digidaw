## Startup

app-settings-reset-title = Impostazioni ripristinate
app-settings-reset-message = Impossibile leggere le impostazioni in { $file } ({ $reason }). Vengono usati i valori predefiniti; il vecchio file è stato conservato come { $backup }.

## Crash recovery

app-crash-recovery-unavailable = Il ripristino dopo un arresto anomalo non è disponibile
app-crash-discard-failed = Impossibile scartare il progetto recuperato
app-crash-report-export-failed = Impossibile esportare il rapporto
app-crash-report-saved = Rapporto salvato
app-crash-report-exported = Rapporto di arresto anomalo esportato in { $path }
app-crash-reports-delete-failed = Impossibile eliminare i rapporti di arresto anomalo

## Timeline

app-timeline-loop-set-failed = Impossibile impostare la regione di loop
app-timeline-loop-clear-failed = Impossibile cancellare la regione di loop
app-timeline-cue-add-failed = Impossibile aggiungere il marcatore
app-timeline-cue-remove-failed = Impossibile rimuovere il marcatore
app-timeline-cue-edit-failed = Impossibile modificare il marcatore
app-timeline-bounce-failed = Impossibile eseguire il bounce della regione di loop
app-timeline-bounced-title = Bounce in una nuova sorgente
app-timeline-bounced-message = La regione di loop ora è nell’elenco delle sorgenti.

## Background work

app-job-cancelled = L’attività in background { $id } è stata annullata.
app-job-failed = Attività in background non riuscita
app-blocking-timeout-title = Operazione scaduta
app-blocking-timeout-message = «{ $task }» non è terminata entro { $seconds } s ed è stata rilasciata; prosegue in background.
app-blocking-cancelled = «{ $task }» è stata annullata prima di iniziare.
app-blocking-failed = Operazione non riuscita

## Recording

app-recording-arm-failed = Impossibile armare la traccia
app-recording-input-on-title = Ingresso audio attivato
app-recording-input-on-message = L’ingresso audio era disattivato, quindi è stato attivato. Cambia il dispositivo di ingresso nelle Impostazioni.
app-recording-nothing-title = Niente da registrare
app-recording-nothing-message = Seleziona una traccia audio su cui registrare.
app-recording-save-failed = Impossibile salvare la registrazione
app-recordings-save-failed = Impossibile salvare le registrazioni

## Project

app-project-recover-failed = Impossibile recuperare il progetto
app-project-audio-load-failed = Impossibile caricare l’audio
app-project-source-delete-failed = Impossibile eliminare la sorgente audio
app-project-pattern-delete-failed = Impossibile eliminare il pattern
app-project-info-update-failed = Impossibile aggiornare le informazioni del progetto
app-project-undo-failed = Impossibile annullare
app-project-redo-failed = Impossibile ripetere
app-project-refresh-failed = { $action }: aggiornamento del progetto non riuscito
app-project-instrument-rename-failed = Impossibile rinominare lo strumento
app-project-trim-failed = Impossibile rifilare l’audio
app-project-envelope-edit-failed = Impossibile modificare l’inviluppo della forma d’onda
app-project-saved-title = Progetto salvato
app-project-saved-message = Progetto salvato in { $path }

## Automation targets

app-automation-missing-effect = Effetto mancante
app-automation-sampler = Campionatore
app-automation-missing-instrument = Strumento mancante
app-automation-track = Traccia
app-automation-bus = Bus
app-automation-master = Master
app-automation-transport = Trasporto
app-automation-other-group = Altro

## Tracks

app-tracks-input-change-failed = Impossibile cambiare l’ingresso della traccia
app-tracks-samples-audio-only = I campioni audio possono essere rilasciati solo su tracce audio
app-tracks-move-type-mismatch = Impossibile spostare { $count ->
    [one] una clip
   *[other] clip
} { $source ->
    [audio] audio
    [midi] MIDI
   *[automation] di automazione
} su una traccia { $target ->
    [audio] audio
    [midi] MIDI
   *[automation] di automazione
}

## Mixer channel templates

app-mixer-template-save-failed = Impossibile salvare il modello di canale
app-mixer-template-saved = Modello di canale salvato in { $path }
app-mixer-template-load-failed = Impossibile caricare il modello di canale
app-mixer-template-loaded = Modello di canale caricato
app-mixer-template-skipped = Plugin non disponibili ignorati: { $plugins }

## Menu bar

app-menu-project = Progetto
app-menu-new-project = Nuovo progetto
app-menu-open-project = Apri progetto
app-menu-open-recent = Apri recenti
app-menu-save-project = Salva progetto
app-menu-save-as = Salva con nome...
app-menu-import-audio = Importa audio
app-menu-export-project = Esporta progetto
app-menu-settings = Impostazioni
app-menu-quit = Esci da { -app-name }
app-menu-edit = Modifica
app-menu-undo = Annulla
app-menu-redo = Ripeti
app-menu-view = Vista
app-menu-zoom-in = Ingrandisci
app-menu-zoom-out = Riduci
