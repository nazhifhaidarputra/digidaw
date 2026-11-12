## Language

settings-language-title = Lingua
settings-language-field = Lingua dell’app
settings-language-system = Predefinita di sistema ({ $language })
settings-language-help = Cambia la lingua di menu, finestre di dialogo e messaggi. I nomi dei parametri dei plugin restano quelli assegnati dai plugin.
settings-language-change-title = Cambiare lingua?
settings-language-change-warning = Stai per cambiare la lingua dell’app. Ricorda dove si trova questo menu, così non ti perderai nella traduzione. Vuoi davvero cambiare lingua?
settings-language-change-confirm = Cambia lingua
settings-language-change-failed = Impossibile cambiare lingua
settings-language-load-failed = Impossibile caricare le impostazioni della lingua

## Settings screen

settings-title = Impostazioni
settings-close = Chiudi impostazioni
settings-page-placeholder = Questa pagina di impostazioni sarà disponibile in una fase successiva.
settings-menu-general = Generali
settings-menu-general-description = Configura il comportamento generale dell’app, come la conservazione della cronologia annullamenti.
settings-menu-host-devices = Host e dispositivi
settings-menu-host-devices-description = Scegli l’host audio e il dispositivo di uscita. I dispositivi di ingresso non sono ancora supportati.
settings-menu-project = Progetto
settings-menu-project-description = Modifica i metadati salvati con il progetto corrente.
settings-menu-appearance = Aspetto
settings-menu-appearance-description = Personalizza tema, colori, sfondo e caratteri dell’app.
settings-menu-audio = Audio
settings-menu-audio-description = Configura la frequenza di campionamento e la dimensione del blocco dell’elaborazione DSP.
settings-menu-key-bindings = Scorciatoie da tastiera
settings-menu-key-bindings-description = Rivedi e personalizza le scorciatoie da tastiera dell’app.
settings-menu-plugins = Plugin
settings-menu-plugins-description = Impostazioni di rilevamento e hosting dei plugin di terze parti.
settings-menu-logs = Log
settings-menu-logs-description = Configura la diagnostica ed esamina i log recenti dell’app.
settings-menu-info = Informazioni
settings-menu-info-description = Visualizza la versione dell’app, le licenze e le informazioni per segnalare bug.

## General

settings-general-history-limit = Numero massimo di passaggi annullabili
settings-general-history-entries = { $count ->
    [one] { $count } passaggio
   *[other] { $count } passaggi
}
settings-general-history-help = Valori più bassi usano meno memoria. Ridurre il limite rimuove subito i passaggi di annullamento e ripristino più vecchi. Scegliendo Disattivato si cancellano entrambe le cronologie.
settings-general-auto-save = Salvataggio automatico
settings-general-auto-save-enable = Attiva il salvataggio automatico
settings-general-auto-save-interval = Salva automaticamente ogni
settings-general-auto-save-help = Il salvataggio automatico scrive una copia di recupero delle modifiche non salvate. Non sovrascrive mai il file del progetto; dopo un arresto anomalo, { -app-name } propone di ripristinare la copia all’avvio successivo.
settings-general-interval-seconds = { $count ->
    [one] { $count } secondo
   *[other] { $count } secondi
}
settings-general-interval-minutes = { $count ->
    [one] { $count } minuto
   *[other] { $count } minuti
}
settings-general-folders = Cartelle
settings-general-project-folder = Cartella progetti predefinita
settings-general-project-folder-unset = Non impostata. Le finestre di salvataggio e apertura partono dove sceglie il sistema.
settings-general-project-folder-choose = Scegli la cartella progetti predefinita
settings-general-export-folder = Cartella di esportazione predefinita
settings-general-export-folder-unset = Non impostata. Scegli una cartella a ogni esportazione.
settings-general-export-folder-choose = Scegli la cartella di esportazione predefinita
settings-general-folder-missing = Questa cartella non esiste più, quindi non viene usata.
settings-general-recent-projects = Progetti recenti
settings-general-recent-projects-show = Mostra progetti recenti
settings-general-recent-projects-help = Elenca i progetti aperti di recente in Apri recenti, nel menu Progetto. Nasconderli mantiene l’elenco.
settings-general-load-failed = Impossibile caricare le impostazioni
settings-general-history-apply-failed = Impossibile applicare il limite della cronologia
settings-general-history-update-failed = Impossibile aggiornare il limite della cronologia
settings-general-history-not-saved = Limite della cronologia applicato ma non salvato
settings-general-auto-save-load-failed = Impossibile caricare le impostazioni di salvataggio automatico
settings-general-auto-save-apply-failed = Impossibile applicare le impostazioni di salvataggio automatico
settings-general-auto-save-update-failed = Impossibile aggiornare il salvataggio automatico
settings-general-auto-save-not-saved = Salvataggio automatico applicato ma non salvato
settings-general-folder-choose-failed = Impossibile scegliere una cartella
settings-general-folder-save-failed = Impossibile salvare la cartella
settings-general-recent-projects-save-failed = Impossibile salvare l’impostazione dei progetti recenti

## Audio

settings-audio-description = Le impostazioni DSP controllano il processo di elaborazione dedicato. I valori del flusso del dispositivo sono di sola lettura e possono differire senza problemi.
settings-audio-sample-rate = Frequenza di campionamento DSP
settings-audio-hertz = { $value } Hz
settings-audio-block-size = Dimensione del blocco DSP
settings-audio-frames = { $count ->
    [one] { $count } campione
   *[other] { $count } campioni
}
settings-audio-block-latency = Un blocco DSP corrisponde a circa { $milliseconds } ms. Blocchi più piccoli riducono la latenza di elaborazione ma aumentano il carico di pianificazione della CPU.
settings-audio-applying = Applicazione…
settings-audio-revert = Ripristina
settings-audio-metronome = Suono del metronomo
settings-audio-metronome-default = Clic predefinito
settings-audio-metronome-choose = Scegli suono
settings-audio-metronome-use-default = Usa predefinito
settings-audio-metronome-help = Il tuo suono viene riprodotto così com’è sui tempi deboli e un’ottava più in alto sul primo tempo. Ogni battito interrompe ciò che resta del precedente.
settings-audio-device-stream = Flusso del dispositivo (sola lettura)
settings-audio-device-stream-starting = Il flusso del dispositivo attivo si sta avviando.
settings-audio-device-output = Uscita: { $device }
settings-audio-device-sample-rate = Frequenza di campionamento del dispositivo: { $value } Hz
settings-audio-device-buffer = Buffer di callback del dispositivo: { $count } campioni
settings-audio-device-channels = Canali: { $count }
settings-audio-reset-title = Impostazioni DSP ripristinate
settings-audio-reset-message = I valori DSP salvati non supportati sono stati riportati ai valori predefiniti.
settings-audio-initialize-failed = Impossibile inizializzare le impostazioni DSP
settings-audio-apply-failed = Impossibile applicare le impostazioni DSP
settings-audio-not-saved = Impostazioni DSP applicate ma non salvate

## Host & Devices

settings-host-description = Scegli dove viene riprodotto l’audio e da quale dispositivo registrano le tracce audio.
settings-host-audio-host = Host audio
settings-host-system-default = Predefinito di sistema
settings-host-output-device = Dispositivo di uscita
settings-host-system-default-output = Uscita predefinita di sistema
settings-host-current-default = { $device } (predefinito attuale)
settings-host-audio-input = Ingresso audio
settings-host-input-enable = Attiva l’ingresso audio
settings-host-input-help = Permette alle tracce audio di registrare e monitorare il dispositivo di ingresso. Armare una traccia lo attiva.
settings-host-input-device = Dispositivo di ingresso
settings-host-system-default-input = Ingresso predefinito di sistema
settings-host-input-retry = Cerca di nuovo gli ingressi
settings-host-stream-summary = { $device } · { $rate } Hz · { $channels } canali
settings-host-retry = Cerca di nuovo
settings-host-fallback-active = { $reason } È attiva l’uscita predefinita di sistema.
settings-host-active-stream = Flusso del dispositivo attivo
settings-host-active-stream-summary = { $rate } Hz · { $frames } campioni · { $channels } canali
settings-host-output-load-failed = Impossibile caricare le impostazioni di uscita
settings-host-input-load-failed = Impossibile caricare le impostazioni di ingresso
settings-host-discover-hosts-failed = Impossibile rilevare gli host audio
settings-host-saved-host-unavailable = L’host audio salvato non è disponibile.
settings-host-saved-output-unavailable = Il dispositivo di uscita salvato non è disponibile.
settings-host-output-fallback-title = Uscita audio di riserva
settings-host-output-fallback-message = { $reason } Viene usata l’uscita predefinita di sistema.
settings-host-input-enabled-not-saved = Ingresso audio attivato ma non salvato
settings-host-input-fallback-title = Ingresso audio di riserva
settings-host-input-fallback-message = Il dispositivo di ingresso salvato non è disponibile. Viene usato l’ingresso predefinito di sistema.
settings-host-input-change-failed = Impossibile cambiare l’ingresso audio
settings-host-input-not-saved = Ingresso audio cambiato ma non salvato
settings-host-discover-outputs-failed = Impossibile rilevare i dispositivi di uscita
settings-host-output-change-failed = Impossibile cambiare l’uscita audio
settings-host-output-not-saved = Uscita audio cambiata ma non salvata

## Project

settings-project-image-open-failed = Impossibile aprire l’immagine
settings-project-cover-save-failed = Impossibile salvare la copertina
settings-project-updated = Informazioni del progetto aggiornate
settings-project-title = Titolo
settings-project-title-required = Il titolo è obbligatorio
settings-project-author = Autore
settings-project-author-help = Separa più artisti con ;
settings-project-genre = Genere
settings-project-version = Versione del progetto
settings-project-description = Descrizione
settings-project-created-at = Creato il
settings-project-saving = Salvataggio…
settings-project-save = Salva informazioni progetto
settings-project-cover = Copertina
settings-project-cover-help = Immagine quadrata incorporata nell’audio esportato
settings-project-cover-choose = Scegli immagine…
settings-project-cover-replace = Sostituisci…
settings-project-changed-banner = Il progetto corrente è cambiato mentre questo modulo ha modifiche non salvate.
settings-project-keep-edits = Mantieni modifiche
settings-project-reload = Ricarica progetto

## Appearance

settings-appearance-color-theme = Tema colori
settings-appearance-load-theme = Carica tema JSON
settings-appearance-color-theme-help = Il tema colori selezionato imposta luminosità e colori propri. Scegli Predefinito per usare la modalità del tema e la tavolozza d’accento.
settings-appearance-theme-mode = Modalità tema
settings-appearance-mode-system = Sistema
settings-appearance-mode-light = Chiaro
settings-appearance-mode-dark = Scuro
settings-appearance-accent = Tavolozza d’accento
settings-appearance-background = Sfondo dell’area di lavoro
settings-appearance-background-default = Sfondo predefinito
settings-appearance-background-choose = Scegli immagine
settings-appearance-background-fit = Adattamento immagine
settings-appearance-overlay = Velatura scura: { $percent }%
settings-appearance-font = Carattere dell’app
settings-appearance-font-system = Carattere di sistema
settings-appearance-font-choose = Scegli TTF o OTF
settings-appearance-font-use-system = Usa il carattere di sistema
settings-appearance-assets-help = Le risorse personalizzate restano nella posizione originale. Se un file viene spostato o eliminato, { -app-name } ripristina in sicurezza il valore predefinito.
settings-appearance-theme = Tema
settings-appearance-theme-remove = Rimuovi tema
settings-appearance-theme-remove-title = Rimuovere il tema colori?
settings-appearance-theme-remove-message = «{ $name }» verrà rimosso dal menu dei temi.{ $active ->
    [yes] {" "}È il tema attivo, quindi { -app-name } torna al tema Predefinito.
   *[no] {""}
}

    Il file { $file } non viene eliminato. Puoi ricaricarlo con Carica tema JSON.
settings-appearance-palette-purple = Viola
settings-appearance-palette-blue = Blu
settings-appearance-palette-teal = Verde acqua
settings-appearance-palette-orange = Arancione
settings-appearance-palette-red = Rosso
settings-appearance-palette-green = Verde
settings-appearance-palette-pink = Rosa
settings-appearance-palette-cyan = Ciano
settings-appearance-palette-indigo = Indaco
settings-appearance-palette-amber = Ambra
settings-appearance-palette-lime = Lime
settings-appearance-palette-magenta = Magenta
settings-appearance-palette-graphite = Grafite
settings-appearance-fit-cover = Copri
settings-appearance-fit-contain = Contieni
settings-appearance-fit-fill = Riempi
settings-appearance-load-failed = Impossibile caricare le impostazioni dell’aspetto
settings-appearance-background-unavailable-title = Immagine di sfondo non disponibile
settings-appearance-background-unavailable-message = L’immagine di sfondo salvata non è disponibile. Viene usato lo sfondo predefinito.
settings-appearance-font-unavailable-title = Carattere personalizzato non disponibile
settings-appearance-font-unavailable-message = Il carattere personalizzato salvato non è disponibile. Viene usato il carattere di sistema.
settings-appearance-theme-unavailable-title = Tema colori non disponibile
settings-appearance-theme-unavailable-message = { $count ->
    [one] Un file di tema colori salvato non è disponibile o non è più valido. È stato rimosso dal menu dei temi.
   *[other] { $count } file di tema colori salvati non sono disponibili o non sono più validi. Sono stati rimossi dal menu dei temi.
}
settings-appearance-theme-apply-failed = Impossibile applicare il tema colori
settings-appearance-theme-choose-failed = Impossibile scegliere il tema colori
settings-appearance-theme-load-failed = Impossibile caricare il tema colori
settings-appearance-theme-remove-failed = Impossibile rimuovere il tema colori
settings-appearance-background-choose-failed = Impossibile scegliere l’immagine di sfondo
settings-appearance-font-choose-failed = Impossibile scegliere il carattere
settings-appearance-font-load-failed = Impossibile caricare il carattere
settings-appearance-not-saved = Aspetto cambiato ma non salvato

## Key bindings

settings-keys-search = Cerca comandi
settings-keys-reset-all = Ripristina tutto
settings-keys-no-match = Nessun comando corrisponde a questa ricerca.
settings-keys-capture-hint = { $hint } Esc annulla l’acquisizione.
settings-keys-reset-all-title = Ripristinare tutte le scorciatoie?
settings-keys-reset-all-message = Ogni comando tornerà alla sua combinazione di tasti predefinita.
settings-keys-default = Predefinita: { $chord }
settings-keys-reset = Ripristina { $command }
settings-keys-change = Cambia
settings-keys-change-title = Cambia { $command }
settings-keys-press = Premi la nuova scorciatoia

## Plugins

settings-plugins-description = { -app-name } carica il catalogo in cache all’avvio. Le scansioni vengono eseguite solo su richiesta e verificano ogni plugin in un processo ausiliario isolato.
settings-plugins-additional-folders = Cartelle di scansione aggiuntive
settings-plugins-no-additional-folders = Nessuna cartella aggiuntiva configurata.
settings-plugins-add-folder = Aggiungi cartella
settings-plugins-system-folders = Cartelle di scansione di sistema
settings-plugins-no-system-folders = Nessuna cartella standard disponibile su questa piattaforma.
settings-plugins-timeout = Timeout per plugin
settings-plugins-scanning = Scansione…
settings-plugins-scan-now = Scansiona ora
settings-plugins-cancelling = Annullamento…
settings-plugins-cancel-scan = Annulla scansione
settings-plugins-retry-failed = Riprova i plugin non riusciti o in quarantena
settings-plugins-preparing = Preparazione della scansione…
settings-plugins-progress = { $completed } di { $total } moduli · { $count ->
    [one] { $count } plugin trovato
   *[other] { $count } plugin trovati
}
settings-plugins-scan-cancelled = Scansione annullata. { $count } plugin sono stati mantenuti.
settings-plugins-scan-complete = Scansione completata. { $count } plugin trovati.
settings-plugins-failures = { $count } errori di scansione
settings-plugins-external-catalog = Catalogo esterno
settings-plugins-catalog-summary = { $available } disponibili, { $unavailable } non disponibili
settings-plugins-remove-folder = Rimuovi cartella
settings-plugins-folder-choose = Scegli la cartella dei plugin
settings-plugins-initialize-failed = Impossibile inizializzare le impostazioni dei plugin
settings-plugins-folder-choose-failed = Impossibile scegliere la cartella dei plugin
settings-plugins-save-failed = Impossibile salvare le impostazioni dei plugin
settings-plugins-scan-failed = Scansione dei plugin non riuscita
settings-plugins-cancel-failed = Impossibile annullare la scansione dei plugin

## Logs

settings-logs-description = Questo visualizzatore contiene i log dell’app Flutter e del motore audio Rust. Ogni voce riporta la propria origine.
settings-logs-capture-level = Livello di acquisizione
settings-logs-retained = Voci conservate
settings-logs-search = Cerca nei log
settings-logs-display-level = Livello di visualizzazione
settings-logs-source = Origine
settings-logs-source-all = Tutte
settings-logs-resume = Riprendi visualizzazione
settings-logs-pause = Sospendi visualizzazione
settings-logs-copy = Copia filtrati
settings-logs-export = Esporta filtrati
settings-logs-count = { $shown } mostrate • { $captured }/{ $maximum } acquisite{ $paused ->
    [yes] {" "}• visualizzazione sospesa
   *[no] {""}
}
settings-logs-empty = Nessuna voce di log corrispondente.
settings-logs-copy-failed = Impossibile copiare i log
settings-logs-copied = Log filtrati copiati
settings-logs-export-failed = Impossibile esportare i log
settings-logs-exported = Log esportati in { $path }
settings-logs-export-dialog = Esporta i log di { -app-name }
settings-logs-clear-title = Cancellare i log acquisiti?
settings-logs-clear-message = Rimuove tutte le voci dal visualizzatore in memoria.
settings-logs-clear-confirm = Cancella log
settings-logs-load-failed = Impossibile caricare le impostazioni dei log
settings-logs-not-saved = Impostazione dei log applicata ma non salvata

## Info

settings-info-description = { -app-name } è una workstation audio digitale multipiattaforma realizzata con Flutter e Rust.
settings-info-application = Applicazione
settings-info-version-unavailable = Le informazioni sulla versione non sono disponibili.
settings-info-name = Nome
settings-info-version = Versione
settings-info-build = Build
settings-info-not-specified = Non specificato
settings-info-report-bug = Segnala un bug
settings-info-report-bug-help = Indica la versione di { -app-name }, il sistema operativo, i passaggi per riprodurre il problema, il risultato atteso, quello effettivo e i log pertinenti.
settings-info-copy-url = Copia l’URL per segnalare bug
settings-info-licenses = Licenze open source
settings-info-view-licenses = Visualizza licenze
settings-info-copy-url-failed = Impossibile copiare l’URL
settings-info-url-copied = URL per segnalare bug copiato

## Cover art and file dialogs

settings-cover-crop-title = Ritaglia copertina
settings-cover-crop-help = Trascina per spostare, scorri o pizzica per ingrandire
settings-cover-crop-use = Usa immagine
settings-project-cover-dialog = Scegli un’immagine di copertina
settings-audio-metronome-dialog = Scegli il suono del metronomo
settings-audio-metronome-setting-load-failed = Impossibile caricare l’impostazione del suono del metronomo
settings-audio-metronome-unavailable-title = Suono del metronomo non disponibile
settings-audio-metronome-unavailable-message = Il suono del metronomo salvato non è disponibile. Viene usato il clic predefinito.
settings-audio-metronome-choose-failed = Impossibile scegliere il suono del metronomo
settings-audio-metronome-load-failed = Impossibile caricare il suono del metronomo
settings-audio-metronome-restore-failed = Impossibile ripristinare il suono predefinito del metronomo
settings-audio-metronome-not-saved = Suono del metronomo cambiato ma non salvato
settings-appearance-background-dialog = Scegli lo sfondo dell’area di lavoro
settings-appearance-font-dialog = Scegli il carattere dell’app
settings-appearance-theme-dialog = Scegli tema colori
settings-appearance-theme-too-large = Il file del tema colori supera 1 MB

## Color theme files

settings-theme-invalid = Tema colori non valido:
settings-theme-invalid-json = Il file non è un JSON valido: { $reason }
settings-theme-not-object = Il tema deve essere un oggetto JSON.
settings-theme-unknown-field = Campo sconosciuto "{ $field }".
settings-theme-missing-field = Manca "{ $field }".
settings-theme-colors-not-object = "colors" deve essere un oggetto di ruoli colore.
settings-theme-name-not-text = "name" deve essere un testo.
settings-theme-name-empty = "name" non può essere vuoto.
settings-theme-name-too-long = "name" deve avere al massimo { $maximum } caratteri.
settings-theme-brightness-invalid = "brightness" deve essere "light" o "dark".
settings-theme-missing-color = Manca il colore obbligatorio "{ $role }".
settings-theme-color-invalid = Il colore "{ $role }" deve essere scritto come "#RRGGBB" o "#RRGGBBAA".
settings-theme-unknown-color = Colore sconosciuto "{ $role }".
