## Startup

app-settings-reset-title = Paramètres réinitialisés
app-settings-reset-message = Les paramètres de { $file } n’ont pas pu être lus ({ $reason }). Les valeurs par défaut sont utilisées ; l’ancien fichier a été conservé sous { $backup }.

## Crash recovery

app-crash-recovery-unavailable = La récupération après plantage n’est pas disponible
app-crash-discard-failed = Impossible d’abandonner le projet récupéré
app-crash-report-export-failed = Impossible d’exporter le rapport
app-crash-report-saved = Rapport enregistré
app-crash-report-exported = Rapport de plantage exporté vers { $path }
app-crash-reports-delete-failed = Impossible de supprimer les rapports de plantage

## Timeline

app-timeline-loop-set-failed = Impossible de définir la boucle
app-timeline-loop-clear-failed = Impossible d’effacer la boucle
app-timeline-cue-add-failed = Impossible d’ajouter le repère
app-timeline-cue-remove-failed = Impossible de supprimer le repère
app-timeline-cue-edit-failed = Impossible de modifier le repère
app-timeline-bounce-failed = Impossible de faire le bounce de la boucle
app-timeline-bounced-title = Bounce vers une nouvelle source
app-timeline-bounced-message = La boucle se trouve maintenant dans la liste des sources.

## Background work

app-job-cancelled = La tâche en arrière-plan { $id } a été annulée.
app-job-failed = Échec de la tâche en arrière-plan
app-blocking-timeout-title = L’opération a expiré
app-blocking-timeout-message = « { $task } » ne s’est pas terminé en { $seconds } s et a été libéré ; il se poursuit en arrière-plan.
app-blocking-cancelled = « { $task } » a été annulé avant de commencer.
app-blocking-failed = Échec de l’opération

## Recording

app-recording-arm-failed = Impossible d’armer la piste
app-recording-input-on-title = Entrée audio activée
app-recording-input-on-message = L’entrée audio était désactivée, elle a donc été activée. Changez le périphérique d’entrée dans les Paramètres.
app-recording-nothing-title = Rien à enregistrer
app-recording-nothing-message = Sélectionnez une piste audio sur laquelle enregistrer.
app-recording-save-failed = Impossible d’enregistrer la prise
app-recordings-save-failed = Impossible d’enregistrer les prises

## Project

app-project-recover-failed = Impossible de récupérer le projet
app-project-audio-load-failed = Impossible de charger l’audio
app-project-source-delete-failed = Impossible de supprimer la source audio
app-project-source-replace-failed = Impossible de remplacer la source audio
app-project-pattern-delete-failed = Impossible de supprimer le pattern
app-project-info-update-failed = Impossible de mettre à jour les informations du projet
app-project-undo-failed = Impossible d’annuler
app-project-redo-failed = Impossible de rétablir
app-project-refresh-failed = { $action } : échec de l’actualisation du projet
app-project-instrument-rename-failed = Impossible de renommer l’instrument
app-project-trim-failed = Impossible de rogner l’audio
app-project-envelope-edit-failed = Impossible de modifier l’enveloppe de la forme d’onde
app-project-saved-title = Projet enregistré
app-project-saved-message = Projet enregistré dans { $path }

## Automation targets

app-automation-missing-effect = Effet introuvable
app-automation-sampler = Sampler
app-automation-missing-instrument = Instrument introuvable
app-automation-track = Piste
app-automation-bus = Bus
app-automation-master = Master
app-automation-transport = Transport
app-automation-other-group = Autres

## Tracks

app-tracks-input-change-failed = Impossible de changer l’entrée de la piste
app-tracks-samples-audio-only = Les échantillons audio ne peuvent être déposés que sur des pistes audio
app-tracks-move-type-mismatch = Impossible de déplacer { $count ->
    [one] un clip
   *[other] des clips
} { $source ->
    [audio] audio
    [midi] MIDI
   *[automation] d’automation
} vers une piste { $target ->
    [audio] audio
    [midi] MIDI
   *[automation] d’automation
}

## Mixer channel templates

app-mixer-template-save-failed = Impossible d’enregistrer le modèle de piste
app-mixer-template-saved = Modèle de piste enregistré dans { $path }
app-mixer-template-load-failed = Impossible de charger le modèle de piste
app-mixer-template-loaded = Modèle de piste chargé
app-mixer-template-skipped = Plugins indisponibles ignorés : { $plugins }

## Menu bar

app-menu-project = Projet
app-menu-new-project = Nouveau projet
app-menu-open-project = Ouvrir un projet
app-menu-open-recent = Ouvrir un projet récent
app-menu-save-project = Enregistrer le projet
app-menu-save-as = Enregistrer sous...
app-menu-import-audio = Importer de l’audio
app-menu-export-project = Exporter le projet
app-menu-settings = Paramètres
app-menu-quit = Quitter { -app-name }
app-menu-edit = Édition
app-menu-undo = Annuler
app-menu-redo = Rétablir
app-menu-view = Affichage
app-menu-zoom-in = Zoom avant
app-menu-zoom-out = Zoom arrière
