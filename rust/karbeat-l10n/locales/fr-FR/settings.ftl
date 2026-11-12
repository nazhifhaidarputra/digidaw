## Language

settings-language-title = Langue
settings-language-field = Langue de l’application
settings-language-system = Langue du système ({ $language })
settings-language-help = Change la langue des menus, des boîtes de dialogue et des messages. Les noms des paramètres des plugins restent ceux que leur donnent les plugins.
settings-language-change-title = Changer de langue ?
settings-language-change-warning = Vous êtes sur le point de changer la langue de l’application. Retenez où se trouve ce menu pour ne pas vous perdre dans la traduction. Voulez-vous vraiment changer de langue ?
settings-language-change-confirm = Changer de langue
settings-language-change-failed = Impossible de changer de langue
settings-language-load-failed = Impossible de charger les paramètres de langue

## Settings screen

settings-title = Paramètres
settings-close = Fermer les paramètres
settings-page-placeholder = Cette page de paramètres sera disponible dans une prochaine phase.
settings-menu-general = Général
settings-menu-general-description = Configurez le comportement général de l’application, comme la conservation de l’historique d’annulation.
settings-menu-host-devices = Hôte et périphériques
settings-menu-host-devices-description = Choisissez l’hôte audio et le périphérique de sortie. Les périphériques d’entrée ne sont pas encore pris en charge.
settings-menu-project = Projet
settings-menu-project-description = Modifiez les métadonnées enregistrées avec le projet actuel.
settings-menu-appearance = Apparence
settings-menu-appearance-description = Personnalisez le thème, les couleurs, l’arrière-plan et la typographie de l’application.
settings-menu-audio = Audio
settings-menu-audio-description = Configurez la fréquence d’échantillonnage et la taille de bloc du traitement DSP.
settings-menu-key-bindings = Raccourcis clavier
settings-menu-key-bindings-description = Consultez et personnalisez les raccourcis clavier de l’application.
settings-menu-plugins = Plugins
settings-menu-plugins-description = Paramètres de détection et d’hébergement des plugins tiers.
settings-menu-logs = Journaux
settings-menu-logs-description = Configurez les diagnostics et consultez les journaux récents de l’application.
settings-menu-info = Infos
settings-menu-info-description = Consultez la version de l’application, les licences et les informations pour signaler un bug.

## General

settings-general-history-limit = Nombre maximal d’entrées d’annulation
settings-general-history-entries = { $count ->
    [one] { $count } entrée
   *[other] { $count } entrées
}
settings-general-history-help = Des valeurs plus faibles utilisent moins de mémoire. Réduire la limite supprime immédiatement les entrées d’annulation et de rétablissement les plus anciennes. Choisir Désactivé efface les deux historiques.
settings-general-auto-save = Enregistrement automatique
settings-general-auto-save-enable = Activer l’enregistrement automatique
settings-general-auto-save-interval = Enregistrer automatiquement toutes les
settings-general-auto-save-help = L’enregistrement automatique écrit une copie de récupération des modifications non enregistrées. Il n’écrase jamais votre fichier de projet ; après un plantage, { -app-name } propose de restaurer la copie au prochain lancement.
settings-general-interval-seconds = { $count ->
    [one] { $count } seconde
   *[other] { $count } secondes
}
settings-general-interval-minutes = { $count ->
    [one] { $count } minute
   *[other] { $count } minutes
}
settings-general-folders = Dossiers
settings-general-project-folder = Dossier de projet par défaut
settings-general-project-folder-unset = Non défini. Les boîtes de dialogue d’enregistrement et d’ouverture démarrent là où le système le choisit.
settings-general-project-folder-choose = Choisir le dossier de projet par défaut
settings-general-export-folder = Dossier d’export par défaut
settings-general-export-folder-unset = Non défini. Choisissez un dossier à chaque export.
settings-general-export-folder-choose = Choisir le dossier d’export par défaut
settings-general-folder-missing = Ce dossier n’existe plus, il n’est donc pas utilisé.
settings-general-recent-projects = Projets récents
settings-general-recent-projects-show = Afficher les projets récents
settings-general-recent-projects-help = Liste les projets ouverts récemment sous Ouvrir un projet récent dans le menu Projet. Les masquer conserve la liste.
settings-general-load-failed = Impossible de charger les paramètres
settings-general-history-apply-failed = Impossible d’appliquer la limite d’historique
settings-general-history-update-failed = Impossible de modifier la limite d’historique
settings-general-history-not-saved = Limite d’historique appliquée mais non enregistrée
settings-general-auto-save-load-failed = Impossible de charger les paramètres d’enregistrement automatique
settings-general-auto-save-apply-failed = Impossible d’appliquer les paramètres d’enregistrement automatique
settings-general-auto-save-update-failed = Impossible de modifier l’enregistrement automatique
settings-general-auto-save-not-saved = Enregistrement automatique appliqué mais non enregistré
settings-general-folder-choose-failed = Impossible de choisir un dossier
settings-general-folder-save-failed = Impossible d’enregistrer le dossier
settings-general-recent-projects-save-failed = Impossible d’enregistrer le paramètre des projets récents

## Audio

settings-audio-description = Les paramètres DSP contrôlent le processus de traitement dédié. Les valeurs du flux du périphérique sont en lecture seule et peuvent différer sans problème.
settings-audio-sample-rate = Fréquence d’échantillonnage DSP
settings-audio-hertz = { $value } Hz
settings-audio-block-size = Taille de bloc DSP
settings-audio-frames = { $count ->
    [one] { $count } échantillon
   *[other] { $count } échantillons
}
settings-audio-block-latency = Un bloc DSP représente environ { $milliseconds } ms. Des blocs plus petits réduisent la latence de traitement mais augmentent la pression sur l’ordonnancement du processeur.
settings-audio-applying = Application…
settings-audio-revert = Rétablir
settings-audio-metronome = Son du métronome
settings-audio-metronome-default = Clic par défaut
settings-audio-metronome-choose = Choisir un son
settings-audio-metronome-use-default = Utiliser le défaut
settings-audio-metronome-help = Votre son est joué tel quel sur les contretemps et une octave plus haut sur le premier temps. Chaque temps coupe ce qui reste du précédent.
settings-audio-device-stream = Flux du périphérique (lecture seule)
settings-audio-device-stream-starting = Le flux du périphérique actif démarre.
settings-audio-device-output = Sortie : { $device }
settings-audio-device-sample-rate = Fréquence du périphérique : { $value } Hz
settings-audio-device-buffer = Tampon de rappel du périphérique : { $count } échantillons
settings-audio-device-channels = Canaux : { $count }
settings-audio-reset-title = Paramètres DSP réinitialisés
settings-audio-reset-message = Les valeurs DSP enregistrées non prises en charge ont été remises par défaut.
settings-audio-initialize-failed = Impossible d’initialiser les paramètres DSP
settings-audio-apply-failed = Impossible d’appliquer les paramètres DSP
settings-audio-not-saved = Paramètres DSP appliqués mais non enregistrés

## Host & Devices

settings-host-description = Choisissez où l’audio est lu et depuis quel périphérique les pistes audio enregistrent.
settings-host-audio-host = Hôte audio
settings-host-system-default = Par défaut du système
settings-host-output-device = Périphérique de sortie
settings-host-system-default-output = Sortie par défaut du système
settings-host-current-default = { $device } (défaut actuel)
settings-host-audio-input = Entrée audio
settings-host-input-enable = Activer l’entrée audio
settings-host-input-help = Permet aux pistes audio d’enregistrer et d’écouter le périphérique d’entrée. Armer une piste l’active.
settings-host-input-device = Périphérique d’entrée
settings-host-system-default-input = Entrée par défaut du système
settings-host-input-retry = Relancer la détection des entrées
settings-host-stream-summary = { $device } · { $rate } Hz · { $channels } canaux
settings-host-retry = Relancer la détection
settings-host-fallback-active = { $reason } La sortie par défaut du système est active.
settings-host-active-stream = Flux du périphérique actif
settings-host-active-stream-summary = { $rate } Hz · { $frames } échantillons · { $channels } canaux
settings-host-output-load-failed = Impossible de charger les paramètres de sortie
settings-host-input-load-failed = Impossible de charger les paramètres d’entrée
settings-host-discover-hosts-failed = Impossible de détecter les hôtes audio
settings-host-saved-host-unavailable = L’hôte audio enregistré n’est pas disponible.
settings-host-saved-output-unavailable = Le périphérique de sortie enregistré n’est pas disponible.
settings-host-output-fallback-title = Sortie audio de secours
settings-host-output-fallback-message = { $reason } La sortie par défaut du système est utilisée.
settings-host-input-enabled-not-saved = Entrée audio activée mais non enregistrée
settings-host-input-fallback-title = Entrée audio de secours
settings-host-input-fallback-message = Le périphérique d’entrée enregistré n’est pas disponible. L’entrée par défaut du système est utilisée.
settings-host-input-change-failed = Impossible de changer l’entrée audio
settings-host-input-not-saved = Entrée audio changée mais non enregistrée
settings-host-discover-outputs-failed = Impossible de détecter les périphériques de sortie
settings-host-output-change-failed = Impossible de changer la sortie audio
settings-host-output-not-saved = Sortie audio changée mais non enregistrée

## Project

settings-project-image-open-failed = Impossible d’ouvrir l’image
settings-project-cover-save-failed = Impossible d’enregistrer la pochette
settings-project-updated = Informations du projet mises à jour
settings-project-title = Titre
settings-project-title-required = Le titre est obligatoire
settings-project-author = Auteur
settings-project-author-help = Séparez plusieurs artistes par ;
settings-project-genre = Genre
settings-project-version = Version du projet
settings-project-description = Description
settings-project-created-at = Créé le
settings-project-saving = Enregistrement…
settings-project-save = Enregistrer les infos du projet
settings-project-cover = Pochette
settings-project-cover-help = Image carrée intégrée à l’audio exporté
settings-project-cover-choose = Choisir une image…
settings-project-cover-replace = Remplacer…
settings-project-changed-banner = Le projet actuel a changé alors que ce formulaire contient des modifications non enregistrées.
settings-project-keep-edits = Garder les modifications
settings-project-reload = Recharger le projet

## Appearance

settings-appearance-color-theme = Thème de couleurs
settings-appearance-load-theme = Charger un thème JSON
settings-appearance-color-theme-help = Le thème de couleurs choisi définit sa propre luminosité et ses couleurs. Choisissez Par défaut pour utiliser le mode de thème et la palette d’accent.
settings-appearance-theme-mode = Mode du thème
settings-appearance-mode-system = Système
settings-appearance-mode-light = Clair
settings-appearance-mode-dark = Sombre
settings-appearance-accent = Palette d’accent
settings-appearance-background = Arrière-plan de l’espace de travail
settings-appearance-background-default = Arrière-plan par défaut
settings-appearance-background-choose = Choisir une image
settings-appearance-background-fit = Ajustement de l’image
settings-appearance-overlay = Voile sombre : { $percent } %
settings-appearance-font = Police de l’application
settings-appearance-font-system = Police du système
settings-appearance-font-choose = Choisir un fichier TTF ou OTF
settings-appearance-font-use-system = Utiliser la police du système
settings-appearance-assets-help = Les ressources personnalisées restent à leur emplacement d’origine. Si un fichier est déplacé ou supprimé, { -app-name } revient sans risque au réglage par défaut.
settings-appearance-theme = Thème
settings-appearance-theme-remove = Retirer le thème
settings-appearance-theme-remove-title = Retirer le thème de couleurs ?
settings-appearance-theme-remove-message = « { $name } » sera retiré du menu des thèmes.{ $active ->
    [yes] {" "}C’est le thème actif, { -app-name } revient donc au thème Par défaut.
   *[no] {""}
}

    Le fichier { $file } n’est pas supprimé. Vous pouvez le recharger avec Charger un thème JSON.
settings-appearance-palette-purple = Violet
settings-appearance-palette-blue = Bleu
settings-appearance-palette-teal = Sarcelle
settings-appearance-palette-orange = Orange
settings-appearance-palette-red = Rouge
settings-appearance-palette-green = Vert
settings-appearance-palette-pink = Rose
settings-appearance-palette-cyan = Cyan
settings-appearance-palette-indigo = Indigo
settings-appearance-palette-amber = Ambre
settings-appearance-palette-lime = Citron vert
settings-appearance-palette-magenta = Magenta
settings-appearance-palette-graphite = Graphite
settings-appearance-fit-cover = Couvrir
settings-appearance-fit-contain = Contenir
settings-appearance-fit-fill = Remplir
settings-appearance-load-failed = Impossible de charger les paramètres d’apparence
settings-appearance-background-unavailable-title = Image d’arrière-plan indisponible
settings-appearance-background-unavailable-message = L’image d’arrière-plan enregistrée n’est pas disponible. L’arrière-plan par défaut est utilisé.
settings-appearance-font-unavailable-title = Police personnalisée indisponible
settings-appearance-font-unavailable-message = La police personnalisée enregistrée n’est pas disponible. La police du système est utilisée.
settings-appearance-theme-unavailable-title = Thème de couleurs indisponible
settings-appearance-theme-unavailable-message = { $count ->
    [one] Un fichier de thème de couleurs enregistré est indisponible ou n’est plus valide. Il a été retiré du menu des thèmes.
   *[other] { $count } fichiers de thème de couleurs enregistrés sont indisponibles ou ne sont plus valides. Ils ont été retirés du menu des thèmes.
}
settings-appearance-theme-apply-failed = Impossible d’appliquer le thème de couleurs
settings-appearance-theme-choose-failed = Impossible de choisir le thème de couleurs
settings-appearance-theme-load-failed = Impossible de charger le thème de couleurs
settings-appearance-theme-remove-failed = Impossible de retirer le thème de couleurs
settings-appearance-background-choose-failed = Impossible de choisir l’image d’arrière-plan
settings-appearance-font-choose-failed = Impossible de choisir la police
settings-appearance-font-load-failed = Impossible de charger la police
settings-appearance-not-saved = Apparence modifiée mais non enregistrée

## Key bindings

settings-keys-search = Rechercher des commandes
settings-keys-reset-all = Tout réinitialiser
settings-keys-no-match = Aucune commande ne correspond à cette recherche.
settings-keys-capture-hint = { $hint } Échap annule la saisie.
settings-keys-reset-all-title = Réinitialiser tous les raccourcis ?
settings-keys-reset-all-message = Chaque commande retrouvera sa combinaison de touches par défaut.
settings-keys-default = Par défaut : { $chord }
settings-keys-reset = Réinitialiser { $command }
settings-keys-change = Modifier
settings-keys-change-title = Modifier { $command }
settings-keys-press = Appuyez sur le nouveau raccourci

## Plugins

settings-plugins-description = { -app-name } charge le catalogue en cache au démarrage. Les analyses ne s’exécutent que sur demande et testent chaque plugin dans un processus auxiliaire isolé.
settings-plugins-additional-folders = Dossiers d’analyse supplémentaires
settings-plugins-no-additional-folders = Aucun dossier supplémentaire configuré.
settings-plugins-add-folder = Ajouter un dossier
settings-plugins-system-folders = Dossiers d’analyse du système
settings-plugins-no-system-folders = Aucun dossier standard n’est disponible sur cette plateforme.
settings-plugins-timeout = Délai par plugin
settings-plugins-scanning = Analyse…
settings-plugins-scan-now = Analyser maintenant
settings-plugins-cancelling = Annulation…
settings-plugins-cancel-scan = Annuler l’analyse
settings-plugins-retry-failed = Réessayer les plugins en échec ou en quarantaine
settings-plugins-preparing = Préparation de l’analyse…
settings-plugins-progress = { $completed } modules sur { $total } · { $count ->
    [one] { $count } plugin détecté
   *[other] { $count } plugins détectés
}
settings-plugins-scan-cancelled = Analyse annulée. { $count } plugins ont été conservés.
settings-plugins-scan-complete = Analyse terminée. { $count } plugins détectés.
settings-plugins-failures = { $count } échecs d’analyse
settings-plugins-external-catalog = Catalogue externe
settings-plugins-catalog-summary = { $available } disponibles, { $unavailable } indisponibles
settings-plugins-remove-folder = Retirer le dossier
settings-plugins-folder-choose = Choisir un dossier de plugins
settings-plugins-initialize-failed = Impossible d’initialiser les paramètres des plugins
settings-plugins-folder-choose-failed = Impossible de choisir le dossier de plugins
settings-plugins-save-failed = Impossible d’enregistrer les paramètres des plugins
settings-plugins-scan-failed = Échec de l’analyse des plugins
settings-plugins-cancel-failed = Impossible d’annuler l’analyse des plugins

## Logs

settings-logs-description = Cette visionneuse contient les journaux de l’application Flutter et ceux du moteur audio Rust. Chaque entrée indique sa source.
settings-logs-capture-level = Niveau de capture
settings-logs-retained = Entrées conservées
settings-logs-search = Rechercher dans les journaux
settings-logs-display-level = Niveau d’affichage
settings-logs-source = Source
settings-logs-source-all = Toutes
settings-logs-resume = Reprendre l’affichage
settings-logs-pause = Suspendre l’affichage
settings-logs-copy = Copier la sélection filtrée
settings-logs-export = Exporter la sélection filtrée
settings-logs-count = { $shown } affichées • { $captured }/{ $maximum } capturées{ $paused ->
    [yes] {" "}• affichage suspendu
   *[no] {""}
}
settings-logs-empty = Aucune entrée de journal correspondante.
settings-logs-copy-failed = Impossible de copier les journaux
settings-logs-copied = Journaux filtrés copiés
settings-logs-export-failed = Impossible d’exporter les journaux
settings-logs-exported = Journaux exportés vers { $path }
settings-logs-export-dialog = Exporter les journaux de { -app-name }
settings-logs-clear-title = Effacer les journaux capturés ?
settings-logs-clear-message = Toutes les entrées seront supprimées de la visionneuse en mémoire.
settings-logs-clear-confirm = Effacer les journaux
settings-logs-load-failed = Impossible de charger les paramètres de journalisation
settings-logs-not-saved = Paramètre de journalisation appliqué mais non enregistré

## Info

settings-info-description = { -app-name } est une station audionumérique multiplateforme propulsée par Flutter et Rust.
settings-info-application = Application
settings-info-version-unavailable = Les informations de version ne sont pas disponibles.
settings-info-name = Nom
settings-info-version = Version
settings-info-build = Build
settings-info-not-specified = Non précisé
settings-info-report-bug = Signaler un bug
settings-info-report-bug-help = Indiquez votre version de { -app-name }, votre système d’exploitation, les étapes pour reproduire, le résultat attendu, le résultat obtenu et les journaux utiles.
settings-info-copy-url = Copier l’URL de signalement
settings-info-licenses = Licences open source
settings-info-view-licenses = Voir les licences
settings-info-copy-url-failed = Impossible de copier l’URL
settings-info-url-copied = URL de signalement copiée

## Cover art and file dialogs

settings-cover-crop-title = Recadrer la pochette
settings-cover-crop-help = Faites glisser pour déplacer, faites défiler ou pincez pour zoomer
settings-cover-crop-use = Utiliser l’image
settings-project-cover-dialog = Choisir une image de pochette
settings-audio-metronome-dialog = Choisir le son du métronome
settings-audio-metronome-setting-load-failed = Impossible de charger le paramètre du son du métronome
settings-audio-metronome-unavailable-title = Son du métronome indisponible
settings-audio-metronome-unavailable-message = Le son du métronome enregistré n’est pas disponible. Le clic par défaut est utilisé.
settings-audio-metronome-choose-failed = Impossible de choisir le son du métronome
settings-audio-metronome-load-failed = Impossible de charger le son du métronome
settings-audio-metronome-restore-failed = Impossible de rétablir le son du métronome par défaut
settings-audio-metronome-not-saved = Son du métronome modifié mais non enregistré
settings-appearance-background-dialog = Choisir l’arrière-plan de l’espace de travail
settings-appearance-font-dialog = Choisir la police de l’application
settings-appearance-theme-dialog = Choisir un thème de couleurs
settings-appearance-theme-too-large = Le fichier du thème de couleurs dépasse 1 Mo

## Color theme files

settings-theme-invalid = Thème de couleurs non valide :
settings-theme-invalid-json = Le fichier n’est pas un JSON valide : { $reason }
settings-theme-not-object = Le thème doit être un objet JSON.
settings-theme-unknown-field = Champ inconnu « { $field } ».
settings-theme-missing-field = « { $field } » manquant.
settings-theme-colors-not-object = « colors » doit être un objet de rôles de couleur.
settings-theme-name-not-text = « name » doit être du texte.
settings-theme-name-empty = « name » ne doit pas être vide.
settings-theme-name-too-long = « name » doit contenir au plus { $maximum } caractères.
settings-theme-brightness-invalid = « brightness » doit valoir « light » ou « dark ».
settings-theme-missing-color = Couleur obligatoire « { $role } » manquante.
settings-theme-color-invalid = La couleur « { $role } » doit être écrite sous la forme « #RRGGBB » ou « #RRGGBBAA ».
settings-theme-unknown-color = Couleur inconnue « { $role } ».
