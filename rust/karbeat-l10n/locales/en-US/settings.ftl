## Language

settings-language-title = Language
settings-language-field = App language
settings-language-system = System default ({ $language })
settings-language-help = Changes the language of menus, dialogs and messages. Plugin parameter names keep the names their plugins give them.
settings-language-change-title = Change language?
settings-language-change-warning = You are going to change your app language. Remember where the menu is so that you are not lost in translation. Are you sure you want to change your language?
settings-language-change-confirm = Change language
settings-language-change-failed = Could not change the language
settings-language-load-failed = Could not load the language settings

## Settings screen

settings-title = Settings
settings-close = Close settings
settings-page-placeholder = This settings page will be implemented in a later phase.
settings-menu-general = General
settings-menu-general-description = Configure application-wide behavior such as undo history retention.
settings-menu-host-devices = Host & Devices
settings-menu-host-devices-description = Choose the audio host and output device. Input devices are not supported yet.
settings-menu-project = Project
settings-menu-project-description = Edit metadata stored with the current project.
settings-menu-appearance = Appearance
settings-menu-appearance-description = Personalize the application theme, colors, background, and typography.
settings-menu-audio = Audio
settings-menu-audio-description = Configure DSP processing sample rate and block size.
settings-menu-key-bindings = Key Bindings
settings-menu-key-bindings-description = Review and customize application keyboard shortcuts.
settings-menu-plugins = Plugins
settings-menu-plugins-description = Third-party plugin discovery and hosting settings.
settings-menu-logs = Logs
settings-menu-logs-description = Configure diagnostics and inspect recent application logs.
settings-menu-info = Info
settings-menu-info-description = View application version, licenses, and bug-report information.

## General

settings-general-history-limit = Maximum undo history entries
settings-general-history-entries = { $count ->
    [one] { $count } entry
   *[other] { $count } entries
}
settings-general-history-help = Lower values use less memory. Reducing the limit immediately removes the oldest undo and redo entries. Choosing Disabled clears both histories.
settings-general-auto-save = Auto save
settings-general-auto-save-enable = Enable auto save
settings-general-auto-save-interval = Auto save every
settings-general-auto-save-help = Auto save writes a recovery copy of unsaved changes. It never overwrites your project file; after a crash, { -app-name } offers to restore the copy on the next launch.
settings-general-interval-seconds = { $count ->
    [one] { $count } second
   *[other] { $count } seconds
}
settings-general-interval-minutes = { $count ->
    [one] { $count } minute
   *[other] { $count } minutes
}
settings-general-folders = Folders
settings-general-project-folder = Default project folder
settings-general-project-folder-unset = Not set. Save and open dialogs start where the system chooses.
settings-general-project-folder-choose = Choose default project folder
settings-general-export-folder = Default export folder
settings-general-export-folder-unset = Not set. Choose a folder for every export.
settings-general-export-folder-choose = Choose default export folder
settings-general-folder-missing = This folder no longer exists, so it is not used.
settings-general-recent-projects = Recent projects
settings-general-recent-projects-show = Show recent projects
settings-general-recent-projects-help = Lists recently opened projects under Open recent in the Project menu. Hiding them keeps the list.
settings-general-load-failed = Could not load settings
settings-general-history-apply-failed = Could not apply history limit
settings-general-history-update-failed = Could not update history limit
settings-general-history-not-saved = History limit applied but not saved
settings-general-auto-save-load-failed = Could not load auto save settings
settings-general-auto-save-apply-failed = Could not apply auto save settings
settings-general-auto-save-update-failed = Could not update auto save
settings-general-auto-save-not-saved = Auto save applied but not saved
settings-general-folder-choose-failed = Could not choose a folder
settings-general-folder-save-failed = Could not save the folder
settings-general-recent-projects-save-failed = Could not save the recent projects setting

## Audio

settings-audio-description = DSP settings control the dedicated processing worker. Device stream values are read-only and may differ safely.
settings-audio-sample-rate = DSP sample rate
settings-audio-hertz = { $value } Hz
settings-audio-block-size = DSP block size
settings-audio-frames = { $count ->
    [one] { $count } frame
   *[other] { $count } frames
}
settings-audio-block-latency = One DSP block represents approximately { $milliseconds } ms. Smaller blocks reduce processing latency but increase CPU scheduling pressure.
settings-audio-applying = Applying…
settings-audio-revert = Revert
settings-audio-metronome = Metronome sound
settings-audio-metronome-default = Default click
settings-audio-metronome-choose = Choose sound
settings-audio-metronome-use-default = Use default
settings-audio-metronome-help = Your sound plays as recorded on offbeats and one octave higher on the downbeat. Each beat cuts off what is left of the previous one.
settings-audio-device-stream = Device stream (read-only)
settings-audio-device-stream-starting = The active device stream is starting.
settings-audio-device-output = Output: { $device }
settings-audio-device-sample-rate = Device sample rate: { $value } Hz
settings-audio-device-buffer = Device callback buffer: { $count } frames
settings-audio-device-channels = Channels: { $count }
settings-audio-reset-title = DSP settings reset
settings-audio-reset-message = Unsupported saved DSP values were reset to defaults.
settings-audio-initialize-failed = Could not initialize DSP settings
settings-audio-apply-failed = Could not apply DSP settings
settings-audio-not-saved = DSP settings applied but not saved

## Host & Devices

settings-host-description = Choose where audio plays and which device audio tracks record from.
settings-host-audio-host = Audio host
settings-host-system-default = System default
settings-host-output-device = Output device
settings-host-system-default-output = System default output
settings-host-current-default = { $device } (current default)
settings-host-audio-input = Audio input
settings-host-input-enable = Enable audio input
settings-host-input-help = Lets audio tracks record and monitor the input device. Arming a track turns it on.
settings-host-input-device = Input device
settings-host-system-default-input = System default input
settings-host-input-retry = Retry input discovery
settings-host-stream-summary = { $device } · { $rate } Hz · { $channels } channels
settings-host-retry = Retry discovery
settings-host-fallback-active = { $reason } System default output is active.
settings-host-active-stream = Active device stream
settings-host-active-stream-summary = { $rate } Hz · { $frames } frames · { $channels } channels
settings-host-output-load-failed = Could not load output settings
settings-host-input-load-failed = Could not load input settings
settings-host-discover-hosts-failed = Could not discover audio hosts
settings-host-saved-host-unavailable = The saved audio host is unavailable.
settings-host-saved-output-unavailable = The saved output device is unavailable.
settings-host-output-fallback-title = Audio output fallback
settings-host-output-fallback-message = { $reason } Using the system default output.
settings-host-input-enabled-not-saved = Audio input turned on but not saved
settings-host-input-fallback-title = Audio input fallback
settings-host-input-fallback-message = The saved input device is unavailable. Using the system default input.
settings-host-input-change-failed = Could not change audio input
settings-host-input-not-saved = Audio input changed but not saved
settings-host-discover-outputs-failed = Could not discover output devices
settings-host-output-change-failed = Could not change audio output
settings-host-output-not-saved = Audio output changed but not saved

## Project

settings-project-image-open-failed = Could not open the image
settings-project-cover-save-failed = Could not save the cover
settings-project-updated = Project information updated
settings-project-title = Title
settings-project-title-required = Title is required
settings-project-author = Author
settings-project-author-help = Separate multiple artists with ;
settings-project-genre = Genre
settings-project-version = Project version
settings-project-description = Description
settings-project-created-at = Created at
settings-project-saving = Saving…
settings-project-save = Save project info
settings-project-cover = Cover art
settings-project-cover-help = Square image embedded into exported audio
settings-project-cover-choose = Choose image…
settings-project-cover-replace = Replace…
settings-project-changed-banner = The current project changed while this form has unsaved edits.
settings-project-keep-edits = Keep edits
settings-project-reload = Reload project

## Appearance

settings-appearance-color-theme = Color theme
settings-appearance-load-theme = Load JSON theme
settings-appearance-color-theme-help = The selected color theme sets its own brightness and colors. Choose Default to use the theme mode and accent palette.
settings-appearance-theme-mode = Theme mode
settings-appearance-mode-system = System
settings-appearance-mode-light = Light
settings-appearance-mode-dark = Dark
settings-appearance-accent = Accent palette
settings-appearance-background = Workspace background
settings-appearance-background-default = Default background
settings-appearance-background-choose = Choose image
settings-appearance-background-fit = Image fit
settings-appearance-overlay = Dark overlay: { $percent }%
settings-appearance-font = Application font
settings-appearance-font-system = System font
settings-appearance-font-choose = Choose TTF or OTF
settings-appearance-font-use-system = Use system font
settings-appearance-assets-help = Custom assets stay at their original file location. If a file is moved or deleted, { -app-name } safely restores the default.
settings-appearance-theme = Theme
settings-appearance-theme-remove = Remove theme
settings-appearance-theme-remove-title = Remove color theme?
settings-appearance-theme-remove-message = “{ $name }” will be removed from the theme menu.{ $active ->
    [yes] {" "}It is the active theme, so { -app-name } switches back to the Default theme.
   *[no] {""}
}

    The file { $file } is not deleted. You can load it again with Load JSON theme.
settings-appearance-palette-purple = Purple
settings-appearance-palette-blue = Blue
settings-appearance-palette-teal = Teal
settings-appearance-palette-orange = Orange
settings-appearance-palette-red = Red
settings-appearance-palette-green = Green
settings-appearance-palette-pink = Pink
settings-appearance-palette-cyan = Cyan
settings-appearance-palette-indigo = Indigo
settings-appearance-palette-amber = Amber
settings-appearance-palette-lime = Lime
settings-appearance-palette-magenta = Magenta
settings-appearance-palette-graphite = Graphite
settings-appearance-fit-cover = Cover
settings-appearance-fit-contain = Contain
settings-appearance-fit-fill = Fill
settings-appearance-load-failed = Could not load appearance settings
settings-appearance-background-unavailable-title = Background image unavailable
settings-appearance-background-unavailable-message = The saved background image is unavailable. The default background is being used.
settings-appearance-font-unavailable-title = Custom font unavailable
settings-appearance-font-unavailable-message = The saved custom font is unavailable. The system font is being used.
settings-appearance-theme-unavailable-title = Color theme unavailable
settings-appearance-theme-unavailable-message = { $count ->
    [one] A saved color theme file is unavailable or no longer valid. It was removed from the theme menu.
   *[other] { $count } saved color theme files are unavailable or no longer valid. They were removed from the theme menu.
}
settings-appearance-theme-apply-failed = Could not apply color theme
settings-appearance-theme-choose-failed = Could not choose color theme
settings-appearance-theme-load-failed = Could not load color theme
settings-appearance-theme-remove-failed = Could not remove color theme
settings-appearance-background-choose-failed = Could not choose background image
settings-appearance-font-choose-failed = Could not choose font
settings-appearance-font-load-failed = Could not load font
settings-appearance-not-saved = Appearance changed but not saved

## Key bindings

settings-keys-search = Search commands
settings-keys-reset-all = Reset all
settings-keys-no-match = No commands match this search.
settings-keys-capture-hint = { $hint } Escape cancels capture.
settings-keys-reset-all-title = Reset all shortcuts?
settings-keys-reset-all-message = Every command will return to its default chord.
settings-keys-default = Default: { $chord }
settings-keys-reset = Reset { $command }
settings-keys-change = Change
settings-keys-change-title = Change { $command }
settings-keys-press = Press the new shortcut

## Plugins

settings-plugins-description = { -app-name } loads the cached catalog at startup. Scans run only when requested and probe each plugin in an isolated helper process.
settings-plugins-additional-folders = Additional scan folders
settings-plugins-no-additional-folders = No additional folders configured.
settings-plugins-add-folder = Add folder
settings-plugins-system-folders = System scan folders
settings-plugins-no-system-folders = No standard folders are available on this platform.
settings-plugins-timeout = Per-plugin timeout
settings-plugins-scanning = Scanning…
settings-plugins-scan-now = Scan now
settings-plugins-cancelling = Cancelling…
settings-plugins-cancel-scan = Cancel scan
settings-plugins-retry-failed = Retry failed/quarantined plugins
settings-plugins-preparing = Preparing scan…
settings-plugins-progress = { $completed } of { $total } modules · { $count ->
    [one] { $count } plugin discovered
   *[other] { $count } plugins discovered
}
settings-plugins-scan-cancelled = Scan cancelled. { $count } plugins were retained.
settings-plugins-scan-complete = Scan complete. { $count } plugins discovered.
settings-plugins-failures = { $count } scan failures
settings-plugins-external-catalog = External catalog
settings-plugins-catalog-summary = { $available } available, { $unavailable } unavailable
settings-plugins-remove-folder = Remove folder
settings-plugins-folder-choose = Choose plugin folder
settings-plugins-initialize-failed = Could not initialize plugin settings
settings-plugins-folder-choose-failed = Could not choose plugin folder
settings-plugins-save-failed = Could not save plugin settings
settings-plugins-scan-failed = Plugin scan failed
settings-plugins-cancel-failed = Could not cancel plugin scan

## Logs

settings-logs-description = This viewer contains Flutter application logs and Rust audio-engine logs. Each entry is labelled with its source.
settings-logs-capture-level = Capture level
settings-logs-retained = Retained entries
settings-logs-search = Search logs
settings-logs-display-level = Display level
settings-logs-source = Source
settings-logs-source-all = All
settings-logs-resume = Resume display
settings-logs-pause = Pause display
settings-logs-copy = Copy filtered
settings-logs-export = Export filtered
settings-logs-count = { $shown } shown • { $captured }/{ $maximum } captured{ $paused ->
    [yes] {" "}• display paused
   *[no] {""}
}
settings-logs-empty = No matching log entries.
settings-logs-copy-failed = Could not copy logs
settings-logs-copied = Filtered logs copied
settings-logs-export-failed = Could not export logs
settings-logs-exported = Logs exported to { $path }
settings-logs-export-dialog = Export { -app-name } logs
settings-logs-clear-title = Clear captured logs?
settings-logs-clear-message = This removes all entries from the in-memory viewer.
settings-logs-clear-confirm = Clear logs
settings-logs-load-failed = Could not load logging settings
settings-logs-not-saved = Logging setting applied but not saved

## Info

settings-info-description = { -app-name } is a cross-platform digital audio workstation powered by Flutter and Rust.
settings-info-application = Application
settings-info-version-unavailable = Version information is unavailable.
settings-info-name = Name
settings-info-version = Version
settings-info-build = Build
settings-info-not-specified = Not specified
settings-info-report-bug = Report a bug
settings-info-report-bug-help = Include your { -app-name } version, operating system, steps to reproduce, expected result, actual result, and relevant logs.
settings-info-copy-url = Copy bug report URL
settings-info-licenses = Open-source licenses
settings-info-view-licenses = View licenses
settings-info-copy-url-failed = Could not copy URL
settings-info-url-copied = Bug report URL copied

## Cover art and file dialogs

settings-cover-crop-title = Crop cover
settings-cover-crop-help = Drag to move, scroll or pinch to zoom
settings-cover-crop-use = Use image
settings-project-cover-dialog = Choose a cover image
settings-audio-metronome-dialog = Choose metronome sound
settings-audio-metronome-setting-load-failed = Could not load the metronome sound setting
settings-audio-metronome-unavailable-title = Metronome sound unavailable
settings-audio-metronome-unavailable-message = The saved metronome sound is unavailable. The default click is being used.
settings-audio-metronome-choose-failed = Could not choose metronome sound
settings-audio-metronome-load-failed = Could not load metronome sound
settings-audio-metronome-restore-failed = Could not restore the default metronome sound
settings-audio-metronome-not-saved = Metronome sound changed but not saved
settings-appearance-background-dialog = Choose workspace background
settings-appearance-font-dialog = Choose application font
settings-appearance-theme-dialog = Choose color theme
settings-appearance-theme-too-large = The color theme file is larger than 1 MB

## Color theme files

settings-theme-invalid = Invalid color theme:
settings-theme-invalid-json = The file is not valid JSON: { $reason }
settings-theme-not-object = The theme must be a JSON object.
settings-theme-unknown-field = Unknown field "{ $field }".
settings-theme-missing-field = Missing "{ $field }".
settings-theme-colors-not-object = "colors" must be an object of colour roles.
settings-theme-name-not-text = "name" must be text.
settings-theme-name-empty = "name" must not be empty.
settings-theme-name-too-long = "name" must be at most { $maximum } characters long.
settings-theme-brightness-invalid = "brightness" must be "light" or "dark".
settings-theme-missing-color = Missing required colour "{ $role }".
settings-theme-color-invalid = Colour "{ $role }" must be written as "#RRGGBB" or "#RRGGBBAA".
settings-theme-unknown-color = Unknown colour "{ $role }".
