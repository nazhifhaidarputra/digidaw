## Language

settings-language-title = Idioma
settings-language-field = Idioma de la aplicación
settings-language-system = Predeterminado del sistema ({ $language })
settings-language-help = Cambia el idioma de los menús, los cuadros de diálogo y los mensajes. Los nombres de los parámetros de los plugins se mantienen tal como los definen sus plugins.
settings-language-change-title = ¿Cambiar el idioma?
settings-language-change-warning = Vas a cambiar el idioma de la aplicación. Recuerda dónde está este menú para no perderte en la traducción. ¿Seguro que quieres cambiar el idioma?
settings-language-change-confirm = Cambiar idioma
settings-language-change-failed = No se ha podido cambiar el idioma
settings-language-load-failed = No se han podido cargar los ajustes de idioma

## Settings screen

settings-title = Ajustes
settings-close = Cerrar ajustes
settings-page-placeholder = Esta página de ajustes se implementará en una fase posterior.
settings-menu-general = General
settings-menu-general-description = Configura el comportamiento general de la aplicación, como la conservación del historial de deshacer.
settings-menu-host-devices = Host y dispositivos
settings-menu-host-devices-description = Elige el host de audio y el dispositivo de salida. Los dispositivos de entrada aún no son compatibles.
settings-menu-project = Proyecto
settings-menu-project-description = Edita los metadatos guardados con el proyecto actual.
settings-menu-appearance = Apariencia
settings-menu-appearance-description = Personaliza el tema, los colores, el fondo y la tipografía de la aplicación.
settings-menu-audio = Audio
settings-menu-audio-description = Configura la frecuencia de muestreo y el tamaño de bloque del procesamiento DSP.
settings-menu-key-bindings = Atajos de teclado
settings-menu-key-bindings-description = Revisa y personaliza los atajos de teclado de la aplicación.
settings-menu-plugins = Plugins
settings-menu-plugins-description = Ajustes de detección y alojamiento de plugins de terceros.
settings-menu-logs = Registros
settings-menu-logs-description = Configura los diagnósticos y consulta los registros recientes de la aplicación.
settings-menu-info = Información
settings-menu-info-description = Consulta la versión de la aplicación, las licencias y la información para informar de errores.

## General

settings-general-history-limit = Número máximo de entradas para deshacer
settings-general-history-entries = { $count ->
    [one] { $count } entrada
   *[other] { $count } entradas
}
settings-general-history-help = Los valores más bajos usan menos memoria. Reducir el límite elimina al instante las entradas más antiguas de deshacer y rehacer. Elegir Desactivado vacía ambos historiales.
settings-general-auto-save = Guardado automático
settings-general-auto-save-enable = Activar el guardado automático
settings-general-auto-save-interval = Guardar automáticamente cada
settings-general-auto-save-help = El guardado automático escribe una copia de recuperación de los cambios sin guardar. Nunca sobrescribe el archivo del proyecto; tras un cierre inesperado, { -app-name } ofrece restaurar la copia en el siguiente inicio.
settings-general-interval-seconds = { $count ->
    [one] { $count } segundo
   *[other] { $count } segundos
}
settings-general-interval-minutes = { $count ->
    [one] { $count } minuto
   *[other] { $count } minutos
}
settings-general-folders = Carpetas
settings-general-project-folder = Carpeta de proyectos predeterminada
settings-general-project-folder-unset = Sin definir. Los diálogos de guardar y abrir empiezan donde elija el sistema.
settings-general-project-folder-choose = Elegir la carpeta de proyectos predeterminada
settings-general-export-folder = Carpeta de exportación predeterminada
settings-general-export-folder-unset = Sin definir. Elige una carpeta en cada exportación.
settings-general-export-folder-choose = Elegir la carpeta de exportación predeterminada
settings-general-folder-missing = Esta carpeta ya no existe, así que no se usa.
settings-general-recent-projects = Proyectos recientes
settings-general-recent-projects-show = Mostrar proyectos recientes
settings-general-recent-projects-help = Muestra los proyectos abiertos recientemente en Abrir reciente, dentro del menú Proyecto. Ocultarlos conserva la lista.
settings-general-load-failed = No se han podido cargar los ajustes
settings-general-history-apply-failed = No se ha podido aplicar el límite del historial
settings-general-history-update-failed = No se ha podido actualizar el límite del historial
settings-general-history-not-saved = Límite del historial aplicado pero no guardado
settings-general-auto-save-load-failed = No se han podido cargar los ajustes de guardado automático
settings-general-auto-save-apply-failed = No se han podido aplicar los ajustes de guardado automático
settings-general-auto-save-update-failed = No se ha podido actualizar el guardado automático
settings-general-auto-save-not-saved = Guardado automático aplicado pero no guardado
settings-general-folder-choose-failed = No se ha podido elegir una carpeta
settings-general-folder-save-failed = No se ha podido guardar la carpeta
settings-general-recent-projects-save-failed = No se ha podido guardar el ajuste de proyectos recientes

## Audio

settings-audio-description = Los ajustes DSP controlan el proceso de trabajo dedicado. Los valores del flujo del dispositivo son de solo lectura y pueden diferir sin problemas.
settings-audio-sample-rate = Frecuencia de muestreo DSP
settings-audio-hertz = { $value } Hz
settings-audio-block-size = Tamaño de bloque DSP
settings-audio-frames = { $count ->
    [one] { $count } muestra
   *[other] { $count } muestras
}
settings-audio-block-latency = Un bloque DSP equivale aproximadamente a { $milliseconds } ms. Los bloques más pequeños reducen la latencia de procesamiento, pero aumentan la carga de planificación de la CPU.
settings-audio-applying = Aplicando…
settings-audio-revert = Revertir
settings-audio-metronome = Sonido del metrónomo
settings-audio-metronome-default = Clic predeterminado
settings-audio-metronome-choose = Elegir sonido
settings-audio-metronome-use-default = Usar el predeterminado
settings-audio-metronome-help = Tu sonido suena tal como se grabó en los tiempos débiles y una octava más alto en el primer tiempo. Cada tiempo corta lo que queda del anterior.
settings-audio-device-stream = Flujo del dispositivo (solo lectura)
settings-audio-device-stream-starting = El flujo del dispositivo activo se está iniciando.
settings-audio-device-output = Salida: { $device }
settings-audio-device-sample-rate = Frecuencia de muestreo del dispositivo: { $value } Hz
settings-audio-device-buffer = Búfer de llamada del dispositivo: { $count } muestras
settings-audio-device-channels = Canales: { $count }
settings-audio-reset-title = Ajustes DSP restablecidos
settings-audio-reset-message = Los valores DSP guardados no compatibles se han restablecido a los predeterminados.
settings-audio-initialize-failed = No se han podido inicializar los ajustes DSP
settings-audio-apply-failed = No se han podido aplicar los ajustes DSP
settings-audio-not-saved = Ajustes DSP aplicados pero no guardados

## Host & Devices

settings-host-description = Elige dónde se reproduce el audio y desde qué dispositivo graban las pistas de audio.
settings-host-audio-host = Host de audio
settings-host-system-default = Predeterminado del sistema
settings-host-output-device = Dispositivo de salida
settings-host-system-default-output = Salida predeterminada del sistema
settings-host-current-default = { $device } (predeterminado actual)
settings-host-audio-input = Entrada de audio
settings-host-input-enable = Activar la entrada de audio
settings-host-input-help = Permite que las pistas de audio graben y monitoricen el dispositivo de entrada. Armar una pista la activa.
settings-host-input-device = Dispositivo de entrada
settings-host-system-default-input = Entrada predeterminada del sistema
settings-host-input-retry = Volver a buscar entradas
settings-host-stream-summary = { $device } · { $rate } Hz · { $channels } canales
settings-host-retry = Volver a buscar
settings-host-fallback-active = { $reason } La salida predeterminada del sistema está activa.
settings-host-active-stream = Flujo del dispositivo activo
settings-host-active-stream-summary = { $rate } Hz · { $frames } muestras · { $channels } canales
settings-host-output-load-failed = No se han podido cargar los ajustes de salida
settings-host-input-load-failed = No se han podido cargar los ajustes de entrada
settings-host-discover-hosts-failed = No se han podido detectar los hosts de audio
settings-host-saved-host-unavailable = El host de audio guardado no está disponible.
settings-host-saved-output-unavailable = El dispositivo de salida guardado no está disponible.
settings-host-output-fallback-title = Salida de audio alternativa
settings-host-output-fallback-message = { $reason } Se usa la salida predeterminada del sistema.
settings-host-input-enabled-not-saved = Entrada de audio activada pero no guardada
settings-host-input-fallback-title = Entrada de audio alternativa
settings-host-input-fallback-message = El dispositivo de entrada guardado no está disponible. Se usa la entrada predeterminada del sistema.
settings-host-input-change-failed = No se ha podido cambiar la entrada de audio
settings-host-input-not-saved = Entrada de audio cambiada pero no guardada
settings-host-discover-outputs-failed = No se han podido detectar los dispositivos de salida
settings-host-output-change-failed = No se ha podido cambiar la salida de audio
settings-host-output-not-saved = Salida de audio cambiada pero no guardada

## Project

settings-project-image-open-failed = No se ha podido abrir la imagen
settings-project-cover-save-failed = No se ha podido guardar la portada
settings-project-updated = Información del proyecto actualizada
settings-project-title = Título
settings-project-title-required = El título es obligatorio
settings-project-author = Autor
settings-project-author-help = Separa varios artistas con ;
settings-project-genre = Género
settings-project-version = Versión del proyecto
settings-project-description = Descripción
settings-project-created-at = Creado el
settings-project-saving = Guardando…
settings-project-save = Guardar la información del proyecto
settings-project-cover = Portada
settings-project-cover-help = Imagen cuadrada incrustada en el audio exportado
settings-project-cover-choose = Elegir imagen…
settings-project-cover-replace = Sustituir…
settings-project-changed-banner = El proyecto actual ha cambiado mientras este formulario tiene cambios sin guardar.
settings-project-keep-edits = Conservar cambios
settings-project-reload = Recargar proyecto

## Appearance

settings-appearance-color-theme = Tema de color
settings-appearance-load-theme = Cargar tema JSON
settings-appearance-color-theme-help = El tema de color elegido define su propio brillo y colores. Elige Predeterminado para usar el modo de tema y la paleta de acento.
settings-appearance-theme-mode = Modo del tema
settings-appearance-mode-system = Sistema
settings-appearance-mode-light = Claro
settings-appearance-mode-dark = Oscuro
settings-appearance-accent = Paleta de acento
settings-appearance-background = Fondo del espacio de trabajo
settings-appearance-background-default = Fondo predeterminado
settings-appearance-background-choose = Elegir imagen
settings-appearance-background-fit = Ajuste de la imagen
settings-appearance-overlay = Capa oscura: { $percent } %
settings-appearance-font = Fuente de la aplicación
settings-appearance-font-system = Fuente del sistema
settings-appearance-font-choose = Elegir TTF u OTF
settings-appearance-font-use-system = Usar la fuente del sistema
settings-appearance-assets-help = Los recursos personalizados se quedan en su ubicación original. Si un archivo se mueve o se elimina, { -app-name } vuelve de forma segura al predeterminado.
settings-appearance-theme = Tema
settings-appearance-theme-remove = Quitar tema
settings-appearance-theme-remove-title = ¿Quitar el tema de color?
settings-appearance-theme-remove-message = «{ $name }» se quitará del menú de temas.{ $active ->
    [yes] {" "}Es el tema activo, así que { -app-name } vuelve al tema Predeterminado.
   *[no] {""}
}

    El archivo { $file } no se elimina. Puedes volver a cargarlo con Cargar tema JSON.
settings-appearance-palette-purple = Morado
settings-appearance-palette-blue = Azul
settings-appearance-palette-teal = Verde azulado
settings-appearance-palette-orange = Naranja
settings-appearance-palette-red = Rojo
settings-appearance-palette-green = Verde
settings-appearance-palette-pink = Rosa
settings-appearance-palette-cyan = Cian
settings-appearance-palette-indigo = Índigo
settings-appearance-palette-amber = Ámbar
settings-appearance-palette-lime = Lima
settings-appearance-palette-magenta = Magenta
settings-appearance-palette-graphite = Grafito
settings-appearance-fit-cover = Cubrir
settings-appearance-fit-contain = Ajustar
settings-appearance-fit-fill = Rellenar
settings-appearance-load-failed = No se han podido cargar los ajustes de apariencia
settings-appearance-background-unavailable-title = Imagen de fondo no disponible
settings-appearance-background-unavailable-message = La imagen de fondo guardada no está disponible. Se está usando el fondo predeterminado.
settings-appearance-font-unavailable-title = Fuente personalizada no disponible
settings-appearance-font-unavailable-message = La fuente personalizada guardada no está disponible. Se está usando la fuente del sistema.
settings-appearance-theme-unavailable-title = Tema de color no disponible
settings-appearance-theme-unavailable-message = { $count ->
    [one] Un archivo de tema de color guardado no está disponible o ya no es válido. Se ha quitado del menú de temas.
   *[other] { $count } archivos de tema de color guardados no están disponibles o ya no son válidos. Se han quitado del menú de temas.
}
settings-appearance-theme-apply-failed = No se ha podido aplicar el tema de color
settings-appearance-theme-choose-failed = No se ha podido elegir el tema de color
settings-appearance-theme-load-failed = No se ha podido cargar el tema de color
settings-appearance-theme-remove-failed = No se ha podido quitar el tema de color
settings-appearance-background-choose-failed = No se ha podido elegir la imagen de fondo
settings-appearance-font-choose-failed = No se ha podido elegir la fuente
settings-appearance-font-load-failed = No se ha podido cargar la fuente
settings-appearance-not-saved = Apariencia cambiada pero no guardada

## Key bindings

settings-keys-search = Buscar comandos
settings-keys-reset-all = Restablecer todo
settings-keys-no-match = Ningún comando coincide con esta búsqueda.
settings-keys-capture-hint = { $hint } Esc cancela la captura.
settings-keys-reset-all-title = ¿Restablecer todos los atajos?
settings-keys-reset-all-message = Todos los comandos volverán a su combinación de teclas predeterminada.
settings-keys-default = Predeterminado: { $chord }
settings-keys-reset = Restablecer { $command }
settings-keys-change = Cambiar
settings-keys-change-title = Cambiar { $command }
settings-keys-press = Pulsa el nuevo atajo

## Plugins

settings-plugins-description = { -app-name } carga el catálogo en caché al iniciarse. Los análisis solo se ejecutan cuando se piden y prueban cada plugin en un proceso auxiliar aislado.
settings-plugins-additional-folders = Carpetas de análisis adicionales
settings-plugins-no-additional-folders = No hay carpetas adicionales configuradas.
settings-plugins-add-folder = Añadir carpeta
settings-plugins-system-folders = Carpetas de análisis del sistema
settings-plugins-no-system-folders = No hay carpetas estándar disponibles en esta plataforma.
settings-plugins-timeout = Tiempo límite por plugin
settings-plugins-scanning = Analizando…
settings-plugins-scan-now = Analizar ahora
settings-plugins-cancelling = Cancelando…
settings-plugins-cancel-scan = Cancelar análisis
settings-plugins-retry-failed = Reintentar plugins fallidos o en cuarentena
settings-plugins-preparing = Preparando el análisis…
settings-plugins-progress = { $completed } de { $total } módulos · { $count ->
    [one] { $count } plugin detectado
   *[other] { $count } plugins detectados
}
settings-plugins-scan-cancelled = Análisis cancelado. Se han conservado { $count } plugins.
settings-plugins-scan-complete = Análisis completado. Se han detectado { $count } plugins.
settings-plugins-failures = { $count } fallos de análisis
settings-plugins-external-catalog = Catálogo externo
settings-plugins-catalog-summary = { $available } disponibles, { $unavailable } no disponibles
settings-plugins-remove-folder = Quitar carpeta
settings-plugins-folder-choose = Elegir carpeta de plugins
settings-plugins-initialize-failed = No se han podido inicializar los ajustes de plugins
settings-plugins-folder-choose-failed = No se ha podido elegir la carpeta de plugins
settings-plugins-save-failed = No se han podido guardar los ajustes de plugins
settings-plugins-scan-failed = Error en el análisis de plugins
settings-plugins-cancel-failed = No se ha podido cancelar el análisis de plugins

## Logs

settings-logs-description = Este visor contiene los registros de la aplicación Flutter y del motor de audio Rust. Cada entrada indica su origen.
settings-logs-capture-level = Nivel de captura
settings-logs-retained = Entradas conservadas
settings-logs-search = Buscar en los registros
settings-logs-display-level = Nivel de visualización
settings-logs-source = Origen
settings-logs-source-all = Todos
settings-logs-resume = Reanudar visualización
settings-logs-pause = Pausar visualización
settings-logs-copy = Copiar filtrados
settings-logs-export = Exportar filtrados
settings-logs-count = { $shown } mostradas • { $captured }/{ $maximum } capturadas{ $paused ->
    [yes] {" "}• visualización en pausa
   *[no] {""}
}
settings-logs-empty = No hay entradas de registro que coincidan.
settings-logs-copy-failed = No se han podido copiar los registros
settings-logs-copied = Registros filtrados copiados
settings-logs-export-failed = No se han podido exportar los registros
settings-logs-exported = Registros exportados a { $path }
settings-logs-export-dialog = Exportar registros de { -app-name }
settings-logs-clear-title = ¿Borrar los registros capturados?
settings-logs-clear-message = Se eliminarán todas las entradas del visor en memoria.
settings-logs-clear-confirm = Borrar registros
settings-logs-load-failed = No se han podido cargar los ajustes de registro
settings-logs-not-saved = Ajuste de registro aplicado pero no guardado

## Info

settings-info-description = { -app-name } es una estación de trabajo de audio digital multiplataforma creada con Flutter y Rust.
settings-info-application = Aplicación
settings-info-version-unavailable = La información de versión no está disponible.
settings-info-name = Nombre
settings-info-version = Versión
settings-info-report-bug = Informar de un error
settings-info-report-bug-help = Incluye tu versión de { -app-name }, el sistema operativo, los pasos para reproducirlo, el resultado esperado, el resultado real y los registros relevantes.
settings-info-copy-url = Copiar la URL para informar de errores
settings-info-copy-url-failed = No se ha podido copiar la URL
settings-info-url-copied = URL para informar de errores copiada

## Cover art and file dialogs

settings-cover-crop-title = Recortar portada
settings-cover-crop-help = Arrastra para mover; desplaza o pellizca para hacer zoom
settings-cover-crop-use = Usar imagen
settings-project-cover-dialog = Elegir una imagen de portada
settings-audio-metronome-dialog = Elegir el sonido del metrónomo
settings-audio-metronome-setting-load-failed = No se ha podido cargar el ajuste del sonido del metrónomo
settings-audio-metronome-unavailable-title = Sonido del metrónomo no disponible
settings-audio-metronome-unavailable-message = El sonido del metrónomo guardado no está disponible. Se está usando el clic predeterminado.
settings-audio-metronome-choose-failed = No se ha podido elegir el sonido del metrónomo
settings-audio-metronome-load-failed = No se ha podido cargar el sonido del metrónomo
settings-audio-metronome-restore-failed = No se ha podido restablecer el sonido predeterminado del metrónomo
settings-audio-metronome-not-saved = Sonido del metrónomo cambiado pero no guardado
settings-appearance-background-dialog = Elegir el fondo del espacio de trabajo
settings-appearance-font-dialog = Elegir la fuente de la aplicación
settings-appearance-theme-dialog = Elegir tema de color
settings-appearance-theme-too-large = El archivo del tema de color supera 1 MB

## Color theme files

settings-theme-invalid = Tema de color no válido:
settings-theme-invalid-json = El archivo no es un JSON válido: { $reason }
settings-theme-not-object = El tema debe ser un objeto JSON.
settings-theme-unknown-field = Campo desconocido "{ $field }".
settings-theme-missing-field = Falta "{ $field }".
settings-theme-colors-not-object = "colors" debe ser un objeto de funciones de color.
settings-theme-name-not-text = "name" debe ser texto.
settings-theme-name-empty = "name" no puede estar vacío.
settings-theme-name-too-long = "name" debe tener como máximo { $maximum } caracteres.
settings-theme-brightness-invalid = "brightness" debe ser "light" o "dark".
settings-theme-missing-color = Falta el color obligatorio "{ $role }".
settings-theme-color-invalid = El color "{ $role }" debe escribirse como "#RRGGBB" o "#RRGGBBAA".
settings-theme-unknown-color = Color desconocido "{ $role }".
