## Language

settings-language-title = Sprache
settings-language-field = App-Sprache
settings-language-system = Systemstandard ({ $language })
settings-language-help = Ändert die Sprache von Menüs, Dialogen und Meldungen. Parameternamen von Plugins bleiben so, wie die Plugins sie benennen.
settings-language-change-title = Sprache ändern?
settings-language-change-warning = Du bist dabei, die Sprache der App zu ändern. Merke dir, wo dieses Menü ist, damit du dich in der Übersetzung nicht verirrst. Möchtest du die Sprache wirklich ändern?
settings-language-change-confirm = Sprache ändern
settings-language-change-failed = Die Sprache konnte nicht geändert werden
settings-language-load-failed = Die Spracheinstellungen konnten nicht geladen werden

## Settings screen

settings-title = Einstellungen
settings-close = Einstellungen schließen
settings-page-placeholder = Diese Einstellungsseite wird in einer späteren Phase umgesetzt.
settings-menu-general = Allgemein
settings-menu-general-description = Lege das allgemeine Verhalten der App fest, etwa wie viel Rückgängig-Verlauf behalten wird.
settings-menu-host-devices = Host & Geräte
settings-menu-host-devices-description = Wähle den Audio-Host und das Ausgabegerät. Eingabegeräte werden noch nicht unterstützt.
settings-menu-project = Projekt
settings-menu-project-description = Bearbeite die Metadaten, die mit dem aktuellen Projekt gespeichert werden.
settings-menu-appearance = Darstellung
settings-menu-appearance-description = Passe Design, Farben, Hintergrund und Schrift der App an.
settings-menu-audio = Audio
settings-menu-audio-description = Lege Abtastrate und Blockgröße der DSP-Verarbeitung fest.
settings-menu-key-bindings = Tastenkürzel
settings-menu-key-bindings-description = Prüfe und ändere die Tastenkürzel der App.
settings-menu-plugins = Plugins
settings-menu-plugins-description = Einstellungen zum Finden und Hosten von Drittanbieter-Plugins.
settings-menu-logs = Protokolle
settings-menu-logs-description = Konfiguriere die Diagnose und sieh dir aktuelle Protokolle der App an.
settings-menu-info = Info
settings-menu-info-description = Zeigt die App-Version, Lizenzen und Informationen zum Melden von Fehlern.

## General

settings-general-history-limit = Maximale Anzahl Rückgängig-Schritte
settings-general-history-entries = { $count ->
    [one] { $count } Schritt
   *[other] { $count } Schritte
}
settings-general-history-help = Niedrigere Werte brauchen weniger Speicher. Ein kleineres Limit entfernt sofort die ältesten Rückgängig- und Wiederholen-Schritte. „Deaktiviert“ leert beide Verläufe.
settings-general-auto-save = Automatisches Speichern
settings-general-auto-save-enable = Automatisches Speichern aktivieren
settings-general-auto-save-interval = Automatisch speichern alle
settings-general-auto-save-help = Das automatische Speichern schreibt eine Wiederherstellungskopie nicht gespeicherter Änderungen. Deine Projektdatei wird nie überschrieben; nach einem Absturz bietet { -app-name } beim nächsten Start an, die Kopie wiederherzustellen.
settings-general-interval-seconds = { $count ->
    [one] { $count } Sekunde
   *[other] { $count } Sekunden
}
settings-general-interval-minutes = { $count ->
    [one] { $count } Minute
   *[other] { $count } Minuten
}
settings-general-folders = Ordner
settings-general-project-folder = Standard-Projektordner
settings-general-project-folder-unset = Nicht festgelegt. Speichern- und Öffnen-Dialoge starten dort, wo das System es vorgibt.
settings-general-project-folder-choose = Standard-Projektordner wählen
settings-general-export-folder = Standard-Exportordner
settings-general-export-folder-unset = Nicht festgelegt. Wähle bei jedem Export einen Ordner.
settings-general-export-folder-choose = Standard-Exportordner wählen
settings-general-folder-missing = Dieser Ordner existiert nicht mehr und wird daher nicht verwendet.
settings-general-recent-projects = Zuletzt verwendete Projekte
settings-general-recent-projects-show = Zuletzt verwendete Projekte anzeigen
settings-general-recent-projects-help = Listet zuletzt geöffnete Projekte unter „Zuletzt geöffnet“ im Projektmenü auf. Beim Ausblenden bleibt die Liste erhalten.
settings-general-load-failed = Einstellungen konnten nicht geladen werden
settings-general-history-apply-failed = Verlaufslimit konnte nicht angewendet werden
settings-general-history-update-failed = Verlaufslimit konnte nicht aktualisiert werden
settings-general-history-not-saved = Verlaufslimit angewendet, aber nicht gespeichert
settings-general-auto-save-load-failed = Einstellungen für automatisches Speichern konnten nicht geladen werden
settings-general-auto-save-apply-failed = Einstellungen für automatisches Speichern konnten nicht angewendet werden
settings-general-auto-save-update-failed = Automatisches Speichern konnte nicht aktualisiert werden
settings-general-auto-save-not-saved = Automatisches Speichern angewendet, aber nicht gespeichert
settings-general-folder-choose-failed = Ordner konnte nicht gewählt werden
settings-general-folder-save-failed = Ordner konnte nicht gespeichert werden
settings-general-recent-projects-save-failed = Einstellung für zuletzt verwendete Projekte konnte nicht gespeichert werden

## Audio

settings-audio-description = Die DSP-Einstellungen steuern den eigenen Verarbeitungsprozess. Die Werte des Gerätestreams sind schreibgeschützt und dürfen problemlos abweichen.
settings-audio-sample-rate = DSP-Abtastrate
settings-audio-hertz = { $value } Hz
settings-audio-block-size = DSP-Blockgröße
settings-audio-frames = { $count ->
    [one] { $count } Frame
   *[other] { $count } Frames
}
settings-audio-block-latency = Ein DSP-Block entspricht etwa { $milliseconds } ms. Kleinere Blöcke senken die Verarbeitungslatenz, erhöhen aber die Last bei der CPU-Planung.
settings-audio-applying = Wird angewendet…
settings-audio-revert = Zurücksetzen
settings-audio-metronome = Metronomklang
settings-audio-metronome-default = Standard-Klick
settings-audio-metronome-choose = Klang wählen
settings-audio-metronome-use-default = Standard verwenden
settings-audio-metronome-help = Dein Klang wird auf den unbetonten Zählzeiten wie aufgenommen und auf der Eins eine Oktave höher abgespielt. Jeder Schlag schneidet den Rest des vorherigen ab.
settings-audio-device-stream = Gerätestream (schreibgeschützt)
settings-audio-device-stream-starting = Der aktive Gerätestream wird gestartet.
settings-audio-device-output = Ausgabe: { $device }
settings-audio-device-sample-rate = Abtastrate des Geräts: { $value } Hz
settings-audio-device-buffer = Callback-Puffer des Geräts: { $count } Frames
settings-audio-device-channels = Kanäle: { $count }
settings-audio-reset-title = DSP-Einstellungen zurückgesetzt
settings-audio-reset-message = Nicht unterstützte gespeicherte DSP-Werte wurden auf die Standardwerte zurückgesetzt.
settings-audio-initialize-failed = DSP-Einstellungen konnten nicht initialisiert werden
settings-audio-apply-failed = DSP-Einstellungen konnten nicht angewendet werden
settings-audio-not-saved = DSP-Einstellungen angewendet, aber nicht gespeichert

## Host & Devices

settings-host-description = Wähle, wo Audio wiedergegeben wird und von welchem Gerät Audiospuren aufnehmen.
settings-host-audio-host = Audio-Host
settings-host-system-default = Systemstandard
settings-host-output-device = Ausgabegerät
settings-host-system-default-output = Standardausgabe des Systems
settings-host-current-default = { $device } (aktueller Standard)
settings-host-audio-input = Audioeingang
settings-host-input-enable = Audioeingang aktivieren
settings-host-input-help = Ermöglicht Audiospuren, das Eingabegerät aufzunehmen und abzuhören. Eine Spur scharf zu schalten aktiviert ihn.
settings-host-input-device = Eingabegerät
settings-host-system-default-input = Standardeingang des Systems
settings-host-input-retry = Eingänge erneut suchen
settings-host-stream-summary = { $device } · { $rate } Hz · { $channels } Kanäle
settings-host-retry = Erneut suchen
settings-host-fallback-active = { $reason } Die Standardausgabe des Systems ist aktiv.
settings-host-active-stream = Aktiver Gerätestream
settings-host-active-stream-summary = { $rate } Hz · { $frames } Frames · { $channels } Kanäle
settings-host-output-load-failed = Ausgabeeinstellungen konnten nicht geladen werden
settings-host-input-load-failed = Eingangseinstellungen konnten nicht geladen werden
settings-host-discover-hosts-failed = Audio-Hosts konnten nicht gefunden werden
settings-host-saved-host-unavailable = Der gespeicherte Audio-Host ist nicht verfügbar.
settings-host-saved-output-unavailable = Das gespeicherte Ausgabegerät ist nicht verfügbar.
settings-host-output-fallback-title = Ersatz-Audioausgabe
settings-host-output-fallback-message = { $reason } Die Standardausgabe des Systems wird verwendet.
settings-host-input-enabled-not-saved = Audioeingang aktiviert, aber nicht gespeichert
settings-host-input-fallback-title = Ersatz-Audioeingang
settings-host-input-fallback-message = Das gespeicherte Eingabegerät ist nicht verfügbar. Der Standardeingang des Systems wird verwendet.
settings-host-input-change-failed = Audioeingang konnte nicht geändert werden
settings-host-input-not-saved = Audioeingang geändert, aber nicht gespeichert
settings-host-discover-outputs-failed = Ausgabegeräte konnten nicht gefunden werden
settings-host-output-change-failed = Audioausgabe konnte nicht geändert werden
settings-host-output-not-saved = Audioausgabe geändert, aber nicht gespeichert

## Project

settings-project-image-open-failed = Das Bild konnte nicht geöffnet werden
settings-project-cover-save-failed = Das Cover konnte nicht gespeichert werden
settings-project-updated = Projektinformationen aktualisiert
settings-project-title = Titel
settings-project-title-required = Titel ist erforderlich
settings-project-author = Autor
settings-project-author-help = Mehrere Künstler mit ; trennen
settings-project-genre = Genre
settings-project-version = Projektversion
settings-project-description = Beschreibung
settings-project-created-at = Erstellt am
settings-project-saving = Wird gespeichert…
settings-project-save = Projektinfos speichern
settings-project-cover = Cover
settings-project-cover-help = Quadratisches Bild, das in exportiertes Audio eingebettet wird
settings-project-cover-choose = Bild wählen…
settings-project-cover-replace = Ersetzen…
settings-project-changed-banner = Das aktuelle Projekt hat sich geändert, während dieses Formular ungespeicherte Änderungen enthält.
settings-project-keep-edits = Änderungen behalten
settings-project-reload = Projekt neu laden

## Appearance

settings-appearance-color-theme = Farbschema
settings-appearance-load-theme = JSON-Farbschema laden
settings-appearance-color-theme-help = Das gewählte Farbschema legt eigene Helligkeit und Farben fest. Wähle „Standard“, um Designmodus und Akzentpalette zu verwenden.
settings-appearance-theme-mode = Designmodus
settings-appearance-mode-system = System
settings-appearance-mode-light = Hell
settings-appearance-mode-dark = Dunkel
settings-appearance-accent = Akzentpalette
settings-appearance-background = Hintergrund des Arbeitsbereichs
settings-appearance-background-default = Standardhintergrund
settings-appearance-background-choose = Bild wählen
settings-appearance-background-fit = Bildanpassung
settings-appearance-overlay = Dunkle Überlagerung: { $percent } %
settings-appearance-font = Schrift der App
settings-appearance-font-system = Systemschrift
settings-appearance-font-choose = TTF oder OTF wählen
settings-appearance-font-use-system = Systemschrift verwenden
settings-appearance-assets-help = Eigene Dateien bleiben an ihrem ursprünglichen Speicherort. Wird eine Datei verschoben oder gelöscht, stellt { -app-name } sicher den Standard wieder her.
settings-appearance-theme = Farbschema
settings-appearance-theme-remove = Farbschema entfernen
settings-appearance-theme-remove-title = Farbschema entfernen?
settings-appearance-theme-remove-message = „{ $name }“ wird aus dem Farbschema-Menü entfernt.{ $active ->
    [yes] {" "}Es ist das aktive Farbschema, daher wechselt { -app-name } zurück zum Standard-Farbschema.
   *[no] {""}
}

    Die Datei { $file } wird nicht gelöscht. Du kannst sie mit „JSON-Farbschema laden“ erneut laden.
settings-appearance-palette-purple = Lila
settings-appearance-palette-blue = Blau
settings-appearance-palette-teal = Petrol
settings-appearance-palette-orange = Orange
settings-appearance-palette-red = Rot
settings-appearance-palette-green = Grün
settings-appearance-palette-pink = Pink
settings-appearance-palette-cyan = Cyan
settings-appearance-palette-indigo = Indigo
settings-appearance-palette-amber = Bernstein
settings-appearance-palette-lime = Limette
settings-appearance-palette-magenta = Magenta
settings-appearance-palette-graphite = Graphit
settings-appearance-fit-cover = Füllen (beschneiden)
settings-appearance-fit-contain = Einpassen
settings-appearance-fit-fill = Strecken
settings-appearance-load-failed = Darstellungseinstellungen konnten nicht geladen werden
settings-appearance-background-unavailable-title = Hintergrundbild nicht verfügbar
settings-appearance-background-unavailable-message = Das gespeicherte Hintergrundbild ist nicht verfügbar. Der Standardhintergrund wird verwendet.
settings-appearance-font-unavailable-title = Eigene Schrift nicht verfügbar
settings-appearance-font-unavailable-message = Die gespeicherte eigene Schrift ist nicht verfügbar. Die Systemschrift wird verwendet.
settings-appearance-theme-unavailable-title = Farbschema nicht verfügbar
settings-appearance-theme-unavailable-message = { $count ->
    [one] Eine gespeicherte Farbschema-Datei ist nicht verfügbar oder nicht mehr gültig. Sie wurde aus dem Farbschema-Menü entfernt.
   *[other] { $count } gespeicherte Farbschema-Dateien sind nicht verfügbar oder nicht mehr gültig. Sie wurden aus dem Farbschema-Menü entfernt.
}
settings-appearance-theme-apply-failed = Farbschema konnte nicht angewendet werden
settings-appearance-theme-choose-failed = Farbschema konnte nicht gewählt werden
settings-appearance-theme-load-failed = Farbschema konnte nicht geladen werden
settings-appearance-theme-remove-failed = Farbschema konnte nicht entfernt werden
settings-appearance-background-choose-failed = Hintergrundbild konnte nicht gewählt werden
settings-appearance-font-choose-failed = Schrift konnte nicht gewählt werden
settings-appearance-font-load-failed = Schrift konnte nicht geladen werden
settings-appearance-not-saved = Darstellung geändert, aber nicht gespeichert

## Key bindings

settings-keys-search = Befehle suchen
settings-keys-reset-all = Alle zurücksetzen
settings-keys-no-match = Keine Befehle passen zu dieser Suche.
settings-keys-capture-hint = { $hint } Escape bricht die Eingabe ab.
settings-keys-reset-all-title = Alle Tastenkürzel zurücksetzen?
settings-keys-reset-all-message = Jeder Befehl erhält wieder seine Standard-Tastenkombination.
settings-keys-default = Standard: { $chord }
settings-keys-reset = { $command } zurücksetzen
settings-keys-change = Ändern
settings-keys-change-title = { $command } ändern
settings-keys-press = Drücke das neue Tastenkürzel

## Plugins

settings-plugins-description = { -app-name } lädt beim Start den zwischengespeicherten Katalog. Scans laufen nur auf Anfrage und prüfen jedes Plugin in einem isolierten Hilfsprozess.
settings-plugins-additional-folders = Zusätzliche Scan-Ordner
settings-plugins-no-additional-folders = Keine zusätzlichen Ordner eingerichtet.
settings-plugins-add-folder = Ordner hinzufügen
settings-plugins-system-folders = System-Scan-Ordner
settings-plugins-no-system-folders = Auf dieser Plattform sind keine Standardordner verfügbar.
settings-plugins-timeout = Zeitlimit pro Plugin
settings-plugins-scanning = Wird gescannt…
settings-plugins-scan-now = Jetzt scannen
settings-plugins-cancelling = Wird abgebrochen…
settings-plugins-cancel-scan = Scan abbrechen
settings-plugins-retry-failed = Fehlgeschlagene/isolierte Plugins erneut versuchen
settings-plugins-preparing = Scan wird vorbereitet…
settings-plugins-progress = { $completed } von { $total } Modulen · { $count ->
    [one] { $count } Plugin gefunden
   *[other] { $count } Plugins gefunden
}
settings-plugins-scan-cancelled = Scan abgebrochen. { $count } Plugins wurden behalten.
settings-plugins-scan-complete = Scan abgeschlossen. { $count } Plugins gefunden.
settings-plugins-failures = { $count } fehlgeschlagene Scans
settings-plugins-external-catalog = Externer Katalog
settings-plugins-catalog-summary = { $available } verfügbar, { $unavailable } nicht verfügbar
settings-plugins-remove-folder = Ordner entfernen
settings-plugins-folder-choose = Plugin-Ordner wählen
settings-plugins-initialize-failed = Plugin-Einstellungen konnten nicht initialisiert werden
settings-plugins-folder-choose-failed = Plugin-Ordner konnte nicht gewählt werden
settings-plugins-save-failed = Plugin-Einstellungen konnten nicht gespeichert werden
settings-plugins-scan-failed = Plugin-Scan fehlgeschlagen
settings-plugins-cancel-failed = Plugin-Scan konnte nicht abgebrochen werden

## Logs

settings-logs-description = Diese Ansicht enthält Protokolle der Flutter-App und der Rust-Audio-Engine. Jeder Eintrag ist mit seiner Quelle gekennzeichnet.
settings-logs-capture-level = Erfassungsstufe
settings-logs-retained = Behaltene Einträge
settings-logs-search = Protokolle durchsuchen
settings-logs-display-level = Anzeigestufe
settings-logs-source = Quelle
settings-logs-source-all = Alle
settings-logs-resume = Anzeige fortsetzen
settings-logs-pause = Anzeige anhalten
settings-logs-copy = Gefilterte kopieren
settings-logs-export = Gefilterte exportieren
settings-logs-count = { $shown } angezeigt • { $captured }/{ $maximum } erfasst{ $paused ->
    [yes] {" "}• Anzeige angehalten
   *[no] {""}
}
settings-logs-empty = Keine passenden Protokolleinträge.
settings-logs-copy-failed = Protokolle konnten nicht kopiert werden
settings-logs-copied = Gefilterte Protokolle kopiert
settings-logs-export-failed = Protokolle konnten nicht exportiert werden
settings-logs-exported = Protokolle nach { $path } exportiert
settings-logs-export-dialog = { -app-name }-Protokolle exportieren
settings-logs-clear-title = Erfasste Protokolle löschen?
settings-logs-clear-message = Dadurch werden alle Einträge aus der Ansicht im Arbeitsspeicher entfernt.
settings-logs-clear-confirm = Protokolle löschen
settings-logs-load-failed = Protokolleinstellungen konnten nicht geladen werden
settings-logs-not-saved = Protokolleinstellung angewendet, aber nicht gespeichert

## Info

settings-info-description = { -app-name } ist eine plattformübergreifende digitale Audio-Workstation auf Basis von Flutter und Rust.
settings-info-application = Anwendung
settings-info-version-unavailable = Versionsinformationen sind nicht verfügbar.
settings-info-name = Name
settings-info-version = Version
settings-info-build = Build
settings-info-not-specified = Nicht angegeben
settings-info-report-bug = Fehler melden
settings-info-report-bug-help = Gib deine { -app-name }-Version, dein Betriebssystem, die Schritte zum Reproduzieren, das erwartete und das tatsächliche Ergebnis sowie relevante Protokolle an.
settings-info-copy-url = URL für Fehlermeldungen kopieren
settings-info-licenses = Open-Source-Lizenzen
settings-info-view-licenses = Lizenzen anzeigen
settings-info-copy-url-failed = URL konnte nicht kopiert werden
settings-info-url-copied = URL für Fehlermeldungen kopiert

## Cover art and file dialogs

settings-cover-crop-title = Cover zuschneiden
settings-cover-crop-help = Ziehen zum Verschieben, scrollen oder zusammenziehen zum Zoomen
settings-cover-crop-use = Bild verwenden
settings-project-cover-dialog = Coverbild wählen
settings-audio-metronome-dialog = Metronomklang wählen
settings-audio-metronome-setting-load-failed = Einstellung für den Metronomklang konnte nicht geladen werden
settings-audio-metronome-unavailable-title = Metronomklang nicht verfügbar
settings-audio-metronome-unavailable-message = Der gespeicherte Metronomklang ist nicht verfügbar. Der Standard-Klick wird verwendet.
settings-audio-metronome-choose-failed = Metronomklang konnte nicht gewählt werden
settings-audio-metronome-load-failed = Metronomklang konnte nicht geladen werden
settings-audio-metronome-restore-failed = Standard-Metronomklang konnte nicht wiederhergestellt werden
settings-audio-metronome-not-saved = Metronomklang geändert, aber nicht gespeichert
settings-appearance-background-dialog = Hintergrund des Arbeitsbereichs wählen
settings-appearance-font-dialog = Schrift der App wählen
settings-appearance-theme-dialog = Farbschema wählen
settings-appearance-theme-too-large = Die Farbschema-Datei ist größer als 1 MB

## Color theme files

settings-theme-invalid = Ungültiges Farbschema:
settings-theme-invalid-json = Die Datei ist kein gültiges JSON: { $reason }
settings-theme-not-object = Das Farbschema muss ein JSON-Objekt sein.
settings-theme-unknown-field = Unbekanntes Feld „{ $field }“.
settings-theme-missing-field = „{ $field }“ fehlt.
settings-theme-colors-not-object = „colors“ muss ein Objekt aus Farbrollen sein.
settings-theme-name-not-text = „name“ muss Text sein.
settings-theme-name-empty = „name“ darf nicht leer sein.
settings-theme-name-too-long = „name“ darf höchstens { $maximum } Zeichen lang sein.
settings-theme-brightness-invalid = „brightness“ muss „light“ oder „dark“ sein.
settings-theme-missing-color = Erforderliche Farbe „{ $role }“ fehlt.
settings-theme-color-invalid = Farbe „{ $role }“ muss als „#RRGGBB“ oder „#RRGGBBAA“ angegeben werden.
settings-theme-unknown-color = Unbekannte Farbe „{ $role }“.
