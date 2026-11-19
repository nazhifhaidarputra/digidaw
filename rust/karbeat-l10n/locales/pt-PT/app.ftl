## Startup

app-settings-reset-title = Definições repostas
app-settings-reset-message = Não foi possível ler as definições em { $file } ({ $reason }). São usados os valores predefinidos; o ficheiro antigo foi mantido como { $backup }.

## Crash recovery

app-crash-recovery-unavailable = A recuperação após falha não está disponível
app-crash-discard-failed = Não foi possível descartar o projeto recuperado
app-crash-report-export-failed = Não foi possível exportar o relatório
app-crash-report-saved = Relatório guardado
app-crash-report-exported = Relatório de falha exportado para { $path }
app-crash-reports-delete-failed = Não foi possível eliminar os relatórios de falha

## Timeline

app-timeline-loop-set-failed = Não foi possível definir a região de ciclo
app-timeline-loop-clear-failed = Não foi possível limpar a região de ciclo
app-timeline-cue-add-failed = Não foi possível adicionar o marcador
app-timeline-cue-remove-failed = Não foi possível remover o marcador
app-timeline-cue-edit-failed = Não foi possível editar o marcador
app-timeline-bounce-failed = Não foi possível renderizar a região de ciclo
app-timeline-bounced-title = Renderizado para uma nova fonte
app-timeline-bounced-message = A região de ciclo está agora na lista de fontes.

## Background work

app-job-cancelled = A tarefa em segundo plano { $id } foi cancelada.
app-job-failed = A tarefa em segundo plano falhou
app-blocking-timeout-title = A operação excedeu o tempo limite
app-blocking-timeout-message = «{ $task }» não terminou em { $seconds } s e foi libertado; continua em segundo plano.
app-blocking-cancelled = «{ $task }» foi cancelado antes de começar.
app-blocking-failed = A operação falhou

## Recording

app-recording-arm-failed = Não foi possível armar a faixa
app-recording-input-on-title = Entrada de áudio ligada
app-recording-input-on-message = A entrada de áudio estava desligada, por isso foi ligada. Altere o dispositivo de entrada nas Definições.
app-recording-nothing-title = Nada para gravar
app-recording-nothing-message = Selecione uma faixa de áudio onde gravar.
app-recording-save-failed = Não foi possível guardar a gravação
app-recordings-save-failed = Não foi possível guardar as gravações

## Project

app-project-recover-failed = Não foi possível recuperar o projeto
app-project-audio-load-failed = Não foi possível carregar o áudio
app-project-source-delete-failed = Não foi possível eliminar a fonte de áudio
app-project-source-replace-failed = Não foi possível substituir a fonte de áudio
app-project-pattern-delete-failed = Não foi possível eliminar o padrão
app-project-info-update-failed = Não foi possível atualizar as informações do projeto
app-project-undo-failed = Não foi possível anular
app-project-redo-failed = Não foi possível refazer
app-project-refresh-failed = { $action }: falha ao atualizar o projeto
app-project-instrument-rename-failed = Não foi possível mudar o nome do instrumento
app-project-trim-failed = Não foi possível aparar o áudio
app-project-envelope-edit-failed = Não foi possível editar o envelope da forma de onda
app-project-saved-title = Projeto guardado
app-project-saved-message = Projeto guardado em { $path }

## Automation targets

app-automation-missing-effect = Efeito em falta
app-automation-sampler = Sampler
app-automation-missing-instrument = Instrumento em falta
app-automation-track = Faixa
app-automation-bus = Bus
app-automation-master = Master
app-automation-transport = Transporte
app-automation-other-group = Outros

## Tracks

app-tracks-input-change-failed = Não foi possível alterar a entrada da faixa
app-tracks-samples-audio-only = As amostras de áudio só podem ser largadas em faixas de áudio
app-tracks-move-type-mismatch = Não é possível mover { $count ->
    [one] um clip
   *[other] clips
} de { $source ->
    [audio] áudio
    [midi] MIDI
   *[automation] automação
} para uma faixa de { $target ->
    [audio] áudio
    [midi] MIDI
   *[automation] automação
}

## Mixer channel templates

app-mixer-template-save-failed = Não foi possível guardar o modelo de canal
app-mixer-template-saved = Modelo de canal guardado em { $path }
app-mixer-template-load-failed = Não foi possível carregar o modelo de canal
app-mixer-template-loaded = Modelo de canal carregado
app-mixer-template-skipped = Plugins indisponíveis ignorados: { $plugins }

## Menu bar

app-menu-project = Projeto
app-menu-new-project = Novo projeto
app-menu-open-project = Abrir projeto
app-menu-open-recent = Abrir recente
app-menu-save-project = Guardar projeto
app-menu-save-as = Guardar como...
app-menu-import-audio = Importar áudio
app-menu-export-project = Exportar projeto
app-menu-settings = Definições
app-menu-quit = Sair do { -app-name }
app-menu-edit = Editar
app-menu-undo = Anular
app-menu-redo = Refazer
app-menu-view = Ver
app-menu-zoom-in = Ampliar
app-menu-zoom-out = Reduzir
