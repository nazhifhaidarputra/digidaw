## Startup

app-settings-reset-title = Ajustes restablecidos
app-settings-reset-message = No se han podido leer los ajustes de { $file } ({ $reason }). Se usan los valores predeterminados; el archivo anterior se ha conservado como { $backup }.

## Crash recovery

app-crash-recovery-unavailable = La recuperación tras un cierre inesperado no está disponible
app-crash-discard-failed = No se ha podido descartar el proyecto recuperado
app-crash-report-export-failed = No se ha podido exportar el informe
app-crash-report-saved = Informe guardado
app-crash-report-exported = Informe de error exportado a { $path }
app-crash-reports-delete-failed = No se han podido eliminar los informes de error

## Timeline

app-timeline-loop-set-failed = No se ha podido establecer la región de bucle
app-timeline-loop-clear-failed = No se ha podido borrar la región de bucle
app-timeline-cue-add-failed = No se ha podido añadir el marcador
app-timeline-cue-remove-failed = No se ha podido quitar el marcador
app-timeline-cue-edit-failed = No se ha podido editar el marcador
app-timeline-bounce-failed = No se ha podido renderizar la región de bucle
app-timeline-bounced-title = Renderizado en una nueva fuente
app-timeline-bounced-message = La región de bucle está ahora en la lista de fuentes.

## Background work

app-job-cancelled = Se ha cancelado la tarea en segundo plano { $id }.
app-job-failed = Ha fallado una tarea en segundo plano
app-blocking-timeout-title = La operación ha superado el tiempo de espera
app-blocking-timeout-message = «{ $task }» no ha terminado en { $seconds } s y se ha liberado; sigue ejecutándose en segundo plano.
app-blocking-cancelled = «{ $task }» se ha cancelado antes de empezar.
app-blocking-failed = Ha fallado la operación

## Recording

app-recording-arm-failed = No se ha podido armar la pista
app-recording-input-on-title = Entrada de audio activada
app-recording-input-on-message = La entrada de audio estaba desactivada, así que se ha activado. Cambia el dispositivo de entrada en Ajustes.
app-recording-nothing-title = No hay nada que grabar
app-recording-nothing-message = Selecciona una pista de audio en la que grabar.
app-recording-save-failed = No se ha podido guardar la grabación
app-recordings-save-failed = No se han podido guardar las grabaciones

## Project

app-project-recover-failed = No se ha podido recuperar el proyecto
app-project-audio-load-failed = No se ha podido cargar el audio
app-project-source-delete-failed = No se ha podido eliminar la fuente de audio
app-project-pattern-delete-failed = No se ha podido eliminar el patrón
app-project-info-update-failed = No se ha podido actualizar la información del proyecto
app-project-undo-failed = No se ha podido deshacer
app-project-redo-failed = No se ha podido rehacer
app-project-refresh-failed = { $action }: no se ha podido actualizar el proyecto
app-project-instrument-rename-failed = No se ha podido cambiar el nombre del instrumento
app-project-trim-failed = No se ha podido recortar el audio
app-project-envelope-edit-failed = No se ha podido editar la envolvente de la forma de onda
app-project-saved-title = Proyecto guardado
app-project-saved-message = Proyecto guardado en { $path }

## Automation targets

app-automation-missing-effect = Efecto no encontrado
app-automation-sampler = Sampler
app-automation-missing-instrument = Instrumento no encontrado
app-automation-track = Pista
app-automation-bus = Bus
app-automation-master = Máster
app-automation-transport = Transporte
app-automation-other-group = Otros

## Tracks

app-tracks-input-change-failed = No se ha podido cambiar la entrada de la pista
app-tracks-samples-audio-only = Las muestras de audio solo se pueden soltar en pistas de audio
app-tracks-move-type-mismatch = No se { $count ->
    [one] puede mover un clip
   *[other] pueden mover clips
} de { $source ->
    [audio] audio
    [midi] MIDI
   *[automation] automatización
} a una pista de { $target ->
    [audio] audio
    [midi] MIDI
   *[automation] automatización
}

## Mixer channel templates

app-mixer-template-save-failed = No se ha podido guardar la plantilla de canal
app-mixer-template-saved = Plantilla de canal guardada en { $path }
app-mixer-template-load-failed = No se ha podido cargar la plantilla de canal
app-mixer-template-loaded = Plantilla de canal cargada
app-mixer-template-skipped = Plugins no disponibles omitidos: { $plugins }

## Menu bar

app-menu-project = Proyecto
app-menu-new-project = Nuevo proyecto
app-menu-open-project = Abrir proyecto
app-menu-open-recent = Abrir reciente
app-menu-save-project = Guardar proyecto
app-menu-save-as = Guardar como...
app-menu-import-audio = Importar audio
app-menu-export-project = Exportar proyecto
app-menu-settings = Ajustes
app-menu-quit = Salir de { -app-name }
app-menu-edit = Edición
app-menu-undo = Deshacer
app-menu-redo = Rehacer
app-menu-view = Ver
app-menu-zoom-in = Acercar
app-menu-zoom-out = Alejar
