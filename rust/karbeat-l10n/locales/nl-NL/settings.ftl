## Language

settings-language-title = Taal
settings-language-field = Taal van de app
settings-language-system = Systeemstandaard ({ $language })
settings-language-help = Wijzigt de taal van menu’s, dialoogvensters en meldingen. Parameternamen van plug-ins blijven zoals de plug-in ze noemt.
settings-language-change-title = Taal wijzigen?
settings-language-change-warning = Je staat op het punt de taal van de app te wijzigen. Onthoud waar dit menu zit, zodat je niet verdwaalt in de vertaling. Weet je zeker dat je de taal wilt wijzigen?
settings-language-change-confirm = Taal wijzigen
settings-language-change-failed = Kan de taal niet wijzigen
settings-language-load-failed = Kan de taalinstellingen niet laden

## Settings screen

settings-title = Instellingen
settings-close = Instellingen sluiten
settings-page-placeholder = Deze instellingenpagina komt in een latere fase.
settings-menu-general = Algemeen
settings-menu-general-description = Stel het algemene gedrag van de app in, zoals hoeveel ongedaan-maken-geschiedenis wordt bewaard.
settings-menu-host-devices = Host en apparaten
settings-menu-host-devices-description = Kies de audiohost en het uitvoerapparaat. Invoerapparaten worden nog niet ondersteund.
settings-menu-project = Project
settings-menu-project-description = Bewerk de metadata die bij het huidige project worden opgeslagen.
settings-menu-appearance = Uiterlijk
settings-menu-appearance-description = Pas het thema, de kleuren, de achtergrond en het lettertype van de app aan.
settings-menu-audio = Audio
settings-menu-audio-description = Stel de samplefrequentie en blokgrootte van de DSP-verwerking in.
settings-menu-key-bindings = Sneltoetsen
settings-menu-key-bindings-description = Bekijk en wijzig de sneltoetsen van de app.
settings-menu-plugins = Plug-ins
settings-menu-plugins-description = Instellingen voor het vinden en hosten van plug-ins van derden.
settings-menu-logs = Logboeken
settings-menu-logs-description = Stel diagnostiek in en bekijk recente logboeken van de app.
settings-menu-info = Info
settings-menu-info-description = Bekijk de appversie, licenties en informatie voor het melden van fouten.

## General

settings-general-history-limit = Maximaal aantal ongedaan-maken-stappen
settings-general-history-entries = { $count ->
    [one] { $count } stap
   *[other] { $count } stappen
}
settings-general-history-help = Lagere waarden gebruiken minder geheugen. Een lagere limiet verwijdert meteen de oudste stappen voor ongedaan maken en opnieuw uitvoeren. Uitgeschakeld wist beide geschiedenissen.
settings-general-auto-save = Automatisch opslaan
settings-general-auto-save-enable = Automatisch opslaan inschakelen
settings-general-auto-save-interval = Automatisch opslaan elke
settings-general-auto-save-help = Automatisch opslaan schrijft een herstelkopie van niet-opgeslagen wijzigingen. Je projectbestand wordt nooit overschreven; na een crash biedt { -app-name } bij de volgende start aan de kopie te herstellen.
settings-general-interval-seconds = { $count ->
    [one] { $count } seconde
   *[other] { $count } seconden
}
settings-general-interval-minutes = { $count ->
    [one] { $count } minuut
   *[other] { $count } minuten
}
settings-general-folders = Mappen
settings-general-project-folder = Standaard projectmap
settings-general-project-folder-unset = Niet ingesteld. Opslaan- en openvensters beginnen waar het systeem kiest.
settings-general-project-folder-choose = Standaard projectmap kiezen
settings-general-export-folder = Standaard exportmap
settings-general-export-folder-unset = Niet ingesteld. Kies bij elke export een map.
settings-general-export-folder-choose = Standaard exportmap kiezen
settings-general-folder-missing = Deze map bestaat niet meer en wordt daarom niet gebruikt.
settings-general-recent-projects = Recente projecten
settings-general-recent-projects-show = Recente projecten tonen
settings-general-recent-projects-help = Toont recent geopende projecten onder Recent openen in het menu Project. Verbergen bewaart de lijst.
settings-general-load-failed = Kan instellingen niet laden
settings-general-history-apply-failed = Kan geschiedenislimiet niet toepassen
settings-general-history-update-failed = Kan geschiedenislimiet niet bijwerken
settings-general-history-not-saved = Geschiedenislimiet toegepast maar niet opgeslagen
settings-general-auto-save-load-failed = Kan instellingen voor automatisch opslaan niet laden
settings-general-auto-save-apply-failed = Kan instellingen voor automatisch opslaan niet toepassen
settings-general-auto-save-update-failed = Kan automatisch opslaan niet bijwerken
settings-general-auto-save-not-saved = Automatisch opslaan toegepast maar niet opgeslagen
settings-general-folder-choose-failed = Kan geen map kiezen
settings-general-folder-save-failed = Kan de map niet opslaan
settings-general-recent-projects-save-failed = Kan de instelling voor recente projecten niet opslaan

## Audio

settings-audio-description = DSP-instellingen bepalen het eigen verwerkingsproces. Waarden van de apparaatstream zijn alleen-lezen en mogen veilig afwijken.
settings-audio-sample-rate = DSP-samplefrequentie
settings-audio-hertz = { $value } Hz
settings-audio-block-size = DSP-blokgrootte
settings-audio-frames = { $count ->
    [one] { $count } frame
   *[other] { $count } frames
}
settings-audio-block-latency = Eén DSP-blok is ongeveer { $milliseconds } ms. Kleinere blokken verlagen de verwerkingslatentie maar belasten de CPU-planning meer.
settings-audio-applying = Toepassen…
settings-audio-revert = Terugzetten
settings-audio-metronome = Metronoomgeluid
settings-audio-metronome-default = Standaardklik
settings-audio-metronome-choose = Geluid kiezen
settings-audio-metronome-use-default = Standaard gebruiken
settings-audio-metronome-help = Je geluid klinkt zoals opgenomen op de offbeats en een octaaf hoger op de eerste tel. Elke tel kapt af wat er van de vorige over is.
settings-audio-device-stream = Apparaatstream (alleen-lezen)
settings-audio-device-stream-starting = De actieve apparaatstream wordt gestart.
settings-audio-device-output = Uitvoer: { $device }
settings-audio-device-sample-rate = Samplefrequentie apparaat: { $value } Hz
settings-audio-device-buffer = Callbackbuffer apparaat: { $count } frames
settings-audio-device-channels = Kanalen: { $count }
settings-audio-reset-title = DSP-instellingen hersteld
settings-audio-reset-message = Niet-ondersteunde opgeslagen DSP-waarden zijn teruggezet naar de standaard.
settings-audio-initialize-failed = Kan DSP-instellingen niet initialiseren
settings-audio-apply-failed = Kan DSP-instellingen niet toepassen
settings-audio-not-saved = DSP-instellingen toegepast maar niet opgeslagen

## Host & Devices

settings-host-description = Kies waar audio wordt afgespeeld en van welk apparaat audiotracks opnemen.
settings-host-audio-host = Audiohost
settings-host-system-default = Systeemstandaard
settings-host-output-device = Uitvoerapparaat
settings-host-system-default-output = Standaarduitvoer van het systeem
settings-host-current-default = { $device } (huidige standaard)
settings-host-audio-input = Audio-invoer
settings-host-input-enable = Audio-invoer inschakelen
settings-host-input-help = Laat audiotracks het invoerapparaat opnemen en beluisteren. Een track opnamegereed maken schakelt het in.
settings-host-input-device = Invoerapparaat
settings-host-system-default-input = Standaardinvoer van het systeem
settings-host-input-retry = Invoerapparaten opnieuw zoeken
settings-host-stream-summary = { $device } · { $rate } Hz · { $channels } kanalen
settings-host-retry = Opnieuw zoeken
settings-host-fallback-active = { $reason } De standaarduitvoer van het systeem is actief.
settings-host-active-stream = Actieve apparaatstream
settings-host-active-stream-summary = { $rate } Hz · { $frames } frames · { $channels } kanalen
settings-host-output-load-failed = Kan uitvoerinstellingen niet laden
settings-host-input-load-failed = Kan invoerinstellingen niet laden
settings-host-discover-hosts-failed = Kan geen audiohosts vinden
settings-host-saved-host-unavailable = De opgeslagen audiohost is niet beschikbaar.
settings-host-saved-output-unavailable = Het opgeslagen uitvoerapparaat is niet beschikbaar.
settings-host-output-fallback-title = Vervangende audio-uitvoer
settings-host-output-fallback-message = { $reason } De standaarduitvoer van het systeem wordt gebruikt.
settings-host-input-enabled-not-saved = Audio-invoer ingeschakeld maar niet opgeslagen
settings-host-input-fallback-title = Vervangende audio-invoer
settings-host-input-fallback-message = Het opgeslagen invoerapparaat is niet beschikbaar. De standaardinvoer van het systeem wordt gebruikt.
settings-host-input-change-failed = Kan audio-invoer niet wijzigen
settings-host-input-not-saved = Audio-invoer gewijzigd maar niet opgeslagen
settings-host-discover-outputs-failed = Kan geen uitvoerapparaten vinden
settings-host-output-change-failed = Kan audio-uitvoer niet wijzigen
settings-host-output-not-saved = Audio-uitvoer gewijzigd maar niet opgeslagen

## Project

settings-project-image-open-failed = Kan de afbeelding niet openen
settings-project-cover-save-failed = Kan de hoes niet opslaan
settings-project-updated = Projectinformatie bijgewerkt
settings-project-title = Titel
settings-project-title-required = Titel is verplicht
settings-project-author = Auteur
settings-project-author-help = Scheid meerdere artiesten met ;
settings-project-genre = Genre
settings-project-version = Projectversie
settings-project-description = Beschrijving
settings-project-created-at = Gemaakt op
settings-project-saving = Opslaan…
settings-project-save = Projectinfo opslaan
settings-project-cover = Hoesafbeelding
settings-project-cover-help = Vierkante afbeelding die in geëxporteerde audio wordt ingesloten
settings-project-cover-choose = Afbeelding kiezen…
settings-project-cover-replace = Vervangen…
settings-project-changed-banner = Het huidige project is gewijzigd terwijl dit formulier niet-opgeslagen wijzigingen heeft.
settings-project-keep-edits = Wijzigingen behouden
settings-project-reload = Project opnieuw laden

## Appearance

settings-appearance-color-theme = Kleurenthema
settings-appearance-load-theme = JSON-thema laden
settings-appearance-color-theme-help = Het gekozen kleurenthema bepaalt zijn eigen helderheid en kleuren. Kies Standaard om de themamodus en het accentpalet te gebruiken.
settings-appearance-theme-mode = Themamodus
settings-appearance-mode-system = Systeem
settings-appearance-mode-light = Licht
settings-appearance-mode-dark = Donker
settings-appearance-accent = Accentpalet
settings-appearance-background = Achtergrond van de werkruimte
settings-appearance-background-default = Standaardachtergrond
settings-appearance-background-choose = Afbeelding kiezen
settings-appearance-background-fit = Afbeelding passend maken
settings-appearance-overlay = Donkere laag: { $percent }%
settings-appearance-font = Lettertype van de app
settings-appearance-font-system = Systeemlettertype
settings-appearance-font-choose = TTF of OTF kiezen
settings-appearance-font-use-system = Systeemlettertype gebruiken
settings-appearance-assets-help = Eigen bestanden blijven op hun oorspronkelijke locatie. Als een bestand wordt verplaatst of verwijderd, zet { -app-name } veilig de standaard terug.
settings-appearance-theme = Thema
settings-appearance-theme-remove = Thema verwijderen
settings-appearance-theme-remove-title = Kleurenthema verwijderen?
settings-appearance-theme-remove-message = ‘{ $name }’ wordt uit het themamenu verwijderd.{ $active ->
    [yes] {" "}Het is het actieve thema, dus { -app-name } schakelt terug naar het standaardthema.
   *[no] {""}
}

    Het bestand { $file } wordt niet verwijderd. Je kunt het opnieuw laden met JSON-thema laden.
settings-appearance-palette-purple = Paars
settings-appearance-palette-blue = Blauw
settings-appearance-palette-teal = Blauwgroen
settings-appearance-palette-orange = Oranje
settings-appearance-palette-red = Rood
settings-appearance-palette-green = Groen
settings-appearance-palette-pink = Roze
settings-appearance-palette-cyan = Cyaan
settings-appearance-palette-indigo = Indigo
settings-appearance-palette-amber = Amber
settings-appearance-palette-lime = Limoen
settings-appearance-palette-magenta = Magenta
settings-appearance-palette-graphite = Grafiet
settings-appearance-fit-cover = Bedekken
settings-appearance-fit-contain = Inpassen
settings-appearance-fit-fill = Opvullen
settings-appearance-load-failed = Kan instellingen voor uiterlijk niet laden
settings-appearance-background-unavailable-title = Achtergrondafbeelding niet beschikbaar
settings-appearance-background-unavailable-message = De opgeslagen achtergrondafbeelding is niet beschikbaar. De standaardachtergrond wordt gebruikt.
settings-appearance-font-unavailable-title = Eigen lettertype niet beschikbaar
settings-appearance-font-unavailable-message = Het opgeslagen eigen lettertype is niet beschikbaar. Het systeemlettertype wordt gebruikt.
settings-appearance-theme-unavailable-title = Kleurenthema niet beschikbaar
settings-appearance-theme-unavailable-message = { $count ->
    [one] Een opgeslagen kleurenthemabestand is niet beschikbaar of niet meer geldig. Het is uit het themamenu verwijderd.
   *[other] { $count } opgeslagen kleurenthemabestanden zijn niet beschikbaar of niet meer geldig. Ze zijn uit het themamenu verwijderd.
}
settings-appearance-theme-apply-failed = Kan kleurenthema niet toepassen
settings-appearance-theme-choose-failed = Kan kleurenthema niet kiezen
settings-appearance-theme-load-failed = Kan kleurenthema niet laden
settings-appearance-theme-remove-failed = Kan kleurenthema niet verwijderen
settings-appearance-background-choose-failed = Kan achtergrondafbeelding niet kiezen
settings-appearance-font-choose-failed = Kan lettertype niet kiezen
settings-appearance-font-load-failed = Kan lettertype niet laden
settings-appearance-not-saved = Uiterlijk gewijzigd maar niet opgeslagen

## Key bindings

settings-keys-search = Opdrachten zoeken
settings-keys-reset-all = Alles herstellen
settings-keys-no-match = Geen opdrachten gevonden voor deze zoekopdracht.
settings-keys-capture-hint = { $hint } Escape annuleert het vastleggen.
settings-keys-reset-all-title = Alle sneltoetsen herstellen?
settings-keys-reset-all-message = Elke opdracht krijgt weer zijn standaardtoetscombinatie.
settings-keys-default = Standaard: { $chord }
settings-keys-reset = { $command } herstellen
settings-keys-change = Wijzigen
settings-keys-change-title = { $command } wijzigen
settings-keys-press = Druk op de nieuwe sneltoets

## Plugins

settings-plugins-description = { -app-name } laadt bij het starten de gecachte catalogus. Scans worden alleen op verzoek uitgevoerd en testen elke plug-in in een afgeschermd hulpproces.
settings-plugins-additional-folders = Extra scanmappen
settings-plugins-no-additional-folders = Geen extra mappen ingesteld.
settings-plugins-add-folder = Map toevoegen
settings-plugins-system-folders = Systeemscanmappen
settings-plugins-no-system-folders = Er zijn geen standaardmappen op dit platform.
settings-plugins-timeout = Time-out per plug-in
settings-plugins-scanning = Scannen…
settings-plugins-scan-now = Nu scannen
settings-plugins-cancelling = Annuleren…
settings-plugins-cancel-scan = Scan annuleren
settings-plugins-retry-failed = Mislukte/in quarantaine geplaatste plug-ins opnieuw proberen
settings-plugins-preparing = Scan voorbereiden…
settings-plugins-progress = { $completed } van { $total } modules · { $count ->
    [one] { $count } plug-in gevonden
   *[other] { $count } plug-ins gevonden
}
settings-plugins-scan-cancelled = Scan geannuleerd. { $count } plug-ins zijn behouden.
settings-plugins-scan-complete = Scan voltooid. { $count } plug-ins gevonden.
settings-plugins-failures = { $count } mislukte scans
settings-plugins-external-catalog = Externe catalogus
settings-plugins-catalog-summary = { $available } beschikbaar, { $unavailable } niet beschikbaar
settings-plugins-remove-folder = Map verwijderen
settings-plugins-folder-choose = Plug-inmap kiezen
settings-plugins-initialize-failed = Kan plug-ininstellingen niet initialiseren
settings-plugins-folder-choose-failed = Kan plug-inmap niet kiezen
settings-plugins-save-failed = Kan plug-ininstellingen niet opslaan
settings-plugins-scan-failed = Plug-inscan mislukt
settings-plugins-cancel-failed = Kan plug-inscan niet annuleren

## Logs

settings-logs-description = Deze weergave bevat logboeken van de Flutter-app en van de Rust-audio-engine. Elke regel vermeldt zijn bron.
settings-logs-capture-level = Vastlegniveau
settings-logs-retained = Bewaarde regels
settings-logs-search = Logboeken doorzoeken
settings-logs-display-level = Weergaveniveau
settings-logs-source = Bron
settings-logs-source-all = Alle
settings-logs-resume = Weergave hervatten
settings-logs-pause = Weergave pauzeren
settings-logs-copy = Gefilterde kopiëren
settings-logs-export = Gefilterde exporteren
settings-logs-count = { $shown } getoond • { $captured }/{ $maximum } vastgelegd{ $paused ->
    [yes] {" "}• weergave gepauzeerd
   *[no] {""}
}
settings-logs-empty = Geen overeenkomende logregels.
settings-logs-copy-failed = Kan logboeken niet kopiëren
settings-logs-copied = Gefilterde logboeken gekopieerd
settings-logs-export-failed = Kan logboeken niet exporteren
settings-logs-exported = Logboeken geëxporteerd naar { $path }
settings-logs-export-dialog = { -app-name }-logboeken exporteren
settings-logs-clear-title = Vastgelegde logboeken wissen?
settings-logs-clear-message = Hiermee worden alle regels uit de weergave in het geheugen verwijderd.
settings-logs-clear-confirm = Logboeken wissen
settings-logs-load-failed = Kan logboekinstellingen niet laden
settings-logs-not-saved = Logboekinstelling toegepast maar niet opgeslagen

## Info

settings-info-description = { -app-name } is een digitaal audiowerkstation voor meerdere platforms, gebouwd met Flutter en Rust.
settings-info-application = Applicatie
settings-info-version-unavailable = Versie-informatie is niet beschikbaar.
settings-info-name = Naam
settings-info-version = Versie
settings-info-build = Build
settings-info-not-specified = Niet opgegeven
settings-info-report-bug = Fout melden
settings-info-report-bug-help = Vermeld je { -app-name }-versie, besturingssysteem, stappen om het te reproduceren, verwacht resultaat, werkelijk resultaat en relevante logboeken.
settings-info-copy-url = URL voor foutmeldingen kopiëren
settings-info-licenses = Opensourcelicenties
settings-info-view-licenses = Licenties bekijken
settings-info-copy-url-failed = Kan URL niet kopiëren
settings-info-url-copied = URL voor foutmeldingen gekopieerd

## Cover art and file dialogs

settings-cover-crop-title = Hoes bijsnijden
settings-cover-crop-help = Sleep om te verplaatsen, scrol of knijp om te zoomen
settings-cover-crop-use = Afbeelding gebruiken
settings-project-cover-dialog = Hoesafbeelding kiezen
settings-audio-metronome-dialog = Metronoomgeluid kiezen
settings-audio-metronome-setting-load-failed = Kan de instelling voor het metronoomgeluid niet laden
settings-audio-metronome-unavailable-title = Metronoomgeluid niet beschikbaar
settings-audio-metronome-unavailable-message = Het opgeslagen metronoomgeluid is niet beschikbaar. De standaardklik wordt gebruikt.
settings-audio-metronome-choose-failed = Kan metronoomgeluid niet kiezen
settings-audio-metronome-load-failed = Kan metronoomgeluid niet laden
settings-audio-metronome-restore-failed = Kan het standaard metronoomgeluid niet terugzetten
settings-audio-metronome-not-saved = Metronoomgeluid gewijzigd maar niet opgeslagen
settings-appearance-background-dialog = Achtergrond van de werkruimte kiezen
settings-appearance-font-dialog = Lettertype van de app kiezen
settings-appearance-theme-dialog = Kleurenthema kiezen
settings-appearance-theme-too-large = Het kleurenthemabestand is groter dan 1 MB

## Color theme files

settings-theme-invalid = Ongeldig kleurenthema:
settings-theme-invalid-json = Het bestand is geen geldige JSON: { $reason }
settings-theme-not-object = Het thema moet een JSON-object zijn.
settings-theme-unknown-field = Onbekend veld "{ $field }".
settings-theme-missing-field = "{ $field }" ontbreekt.
settings-theme-colors-not-object = "colors" moet een object met kleurrollen zijn.
settings-theme-name-not-text = "name" moet tekst zijn.
settings-theme-name-empty = "name" mag niet leeg zijn.
settings-theme-name-too-long = "name" mag hoogstens { $maximum } tekens lang zijn.
settings-theme-brightness-invalid = "brightness" moet "light" of "dark" zijn.
settings-theme-missing-color = Verplichte kleur "{ $role }" ontbreekt.
settings-theme-color-invalid = Kleur "{ $role }" moet worden geschreven als "#RRGGBB" of "#RRGGBBAA".
settings-theme-unknown-color = Onbekende kleur "{ $role }".
