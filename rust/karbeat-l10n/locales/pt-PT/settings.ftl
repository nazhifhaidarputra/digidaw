## Language

settings-language-title = Idioma
settings-language-field = Idioma da aplicação
settings-language-system = Predefinição do sistema ({ $language })
settings-language-help = Muda o idioma dos menus, das caixas de diálogo e das mensagens. Os nomes dos parâmetros dos plugins mantêm os nomes dados pelos plugins.
settings-language-change-title = Mudar o idioma?
settings-language-change-warning = Está prestes a mudar o idioma da aplicação. Lembre-se de onde fica este menu para não se perder na tradução. Tem a certeza de que pretende mudar o idioma?
settings-language-change-confirm = Mudar o idioma
settings-language-change-failed = Não foi possível mudar o idioma
settings-language-load-failed = Não foi possível carregar as definições de idioma

## Settings screen

settings-title = Definições
settings-close = Fechar definições
settings-page-placeholder = Esta página de definições será implementada numa fase posterior.
settings-menu-general = Geral
settings-menu-general-description = Configure o comportamento geral da aplicação, como a conservação do histórico de anulação.
settings-menu-host-devices = Anfitrião e dispositivos
settings-menu-host-devices-description = Escolha o anfitrião de áudio e o dispositivo de saída. Os dispositivos de entrada ainda não são suportados.
settings-menu-project = Projeto
settings-menu-project-description = Edite os metadados guardados com o projeto atual.
settings-menu-appearance = Aspeto
settings-menu-appearance-description = Personalize o tema, as cores, o fundo e a tipografia da aplicação.
settings-menu-audio = Áudio
settings-menu-audio-description = Configure a frequência de amostragem e o tamanho de bloco do processamento DSP.
settings-menu-key-bindings = Atalhos de teclado
settings-menu-key-bindings-description = Reveja e personalize os atalhos de teclado da aplicação.
settings-menu-plugins = Plugins
settings-menu-plugins-description = Definições de deteção e alojamento de plugins de terceiros.
settings-menu-logs = Registos
settings-menu-logs-description = Configure os diagnósticos e consulte os registos recentes da aplicação.
settings-menu-info = Informações
settings-menu-info-description = Veja a versão da aplicação, as licenças e as informações para comunicar erros.

## General

settings-general-history-limit = Número máximo de entradas de anulação
settings-general-history-entries = { $count ->
    [one] { $count } entrada
   *[other] { $count } entradas
}
settings-general-history-help = Valores mais baixos usam menos memória. Reduzir o limite remove de imediato as entradas de anular e refazer mais antigas. Escolher Desativado limpa ambos os históricos.
settings-general-auto-save = Gravação automática
settings-general-auto-save-enable = Ativar a gravação automática
settings-general-auto-save-interval = Gravar automaticamente a cada
settings-general-auto-save-help = A gravação automática escreve uma cópia de recuperação das alterações não guardadas. Nunca substitui o ficheiro do projeto; após uma falha, o { -app-name } oferece-se para restaurar a cópia no arranque seguinte.
settings-general-interval-seconds = { $count ->
    [one] { $count } segundo
   *[other] { $count } segundos
}
settings-general-interval-minutes = { $count ->
    [one] { $count } minuto
   *[other] { $count } minutos
}
settings-general-folders = Pastas
settings-general-project-folder = Pasta de projetos predefinida
settings-general-project-folder-unset = Não definida. As caixas de diálogo de guardar e abrir começam onde o sistema escolher.
settings-general-project-folder-choose = Escolher a pasta de projetos predefinida
settings-general-export-folder = Pasta de exportação predefinida
settings-general-export-folder-unset = Não definida. Escolha uma pasta em cada exportação.
settings-general-export-folder-choose = Escolher a pasta de exportação predefinida
settings-general-folder-missing = Esta pasta já não existe, por isso não é usada.
settings-general-recent-projects = Projetos recentes
settings-general-recent-projects-show = Mostrar projetos recentes
settings-general-recent-projects-help = Lista os projetos abertos recentemente em Abrir recente, no menu Projeto. Ocultá-los mantém a lista.
settings-general-load-failed = Não foi possível carregar as definições
settings-general-history-apply-failed = Não foi possível aplicar o limite do histórico
settings-general-history-update-failed = Não foi possível atualizar o limite do histórico
settings-general-history-not-saved = Limite do histórico aplicado, mas não guardado
settings-general-auto-save-load-failed = Não foi possível carregar as definições de gravação automática
settings-general-auto-save-apply-failed = Não foi possível aplicar as definições de gravação automática
settings-general-auto-save-update-failed = Não foi possível atualizar a gravação automática
settings-general-auto-save-not-saved = Gravação automática aplicada, mas não guardada
settings-general-folder-choose-failed = Não foi possível escolher uma pasta
settings-general-folder-save-failed = Não foi possível guardar a pasta
settings-general-recent-projects-save-failed = Não foi possível guardar a definição de projetos recentes

## Audio

settings-audio-description = As definições DSP controlam o processo de trabalho dedicado. Os valores do fluxo do dispositivo são só de leitura e podem ser diferentes sem problema.
settings-audio-sample-rate = Frequência de amostragem DSP
settings-audio-hertz = { $value } Hz
settings-audio-block-size = Tamanho de bloco DSP
settings-audio-frames = { $count ->
    [one] { $count } amostra
   *[other] { $count } amostras
}
settings-audio-block-latency = Um bloco DSP corresponde a cerca de { $milliseconds } ms. Blocos mais pequenos reduzem a latência de processamento, mas aumentam a carga de escalonamento do processador.
settings-audio-applying = A aplicar…
settings-audio-revert = Reverter
settings-audio-metronome = Som do metrónomo
settings-audio-metronome-default = Clique predefinido
settings-audio-metronome-choose = Escolher som
settings-audio-metronome-use-default = Usar o predefinido
settings-audio-metronome-help = O seu som toca tal como foi gravado nos contratempos e uma oitava acima no primeiro tempo. Cada tempo corta o que resta do anterior.
settings-audio-device-stream = Fluxo do dispositivo (só de leitura)
settings-audio-device-stream-starting = O fluxo do dispositivo ativo está a iniciar.
settings-audio-device-output = Saída: { $device }
settings-audio-device-sample-rate = Frequência de amostragem do dispositivo: { $value } Hz
settings-audio-device-buffer = Buffer de callback do dispositivo: { $count } amostras
settings-audio-device-channels = Canais: { $count }
settings-audio-reset-title = Definições DSP repostas
settings-audio-reset-message = Os valores DSP guardados não suportados foram repostos para os predefinidos.
settings-audio-initialize-failed = Não foi possível inicializar as definições DSP
settings-audio-apply-failed = Não foi possível aplicar as definições DSP
settings-audio-not-saved = Definições DSP aplicadas, mas não guardadas

## Host & Devices

settings-host-description = Escolha onde o áudio é reproduzido e a partir de que dispositivo as faixas de áudio gravam.
settings-host-audio-host = Anfitrião de áudio
settings-host-system-default = Predefinição do sistema
settings-host-output-device = Dispositivo de saída
settings-host-system-default-output = Saída predefinida do sistema
settings-host-current-default = { $device } (predefinição atual)
settings-host-audio-input = Entrada de áudio
settings-host-input-enable = Ativar a entrada de áudio
settings-host-input-help = Permite que as faixas de áudio gravem e monitorizem o dispositivo de entrada. Armar uma faixa ativa-a.
settings-host-input-device = Dispositivo de entrada
settings-host-system-default-input = Entrada predefinida do sistema
settings-host-input-retry = Voltar a procurar entradas
settings-host-stream-summary = { $device } · { $rate } Hz · { $channels } canais
settings-host-retry = Voltar a procurar
settings-host-fallback-active = { $reason } A saída predefinida do sistema está ativa.
settings-host-active-stream = Fluxo do dispositivo ativo
settings-host-active-stream-summary = { $rate } Hz · { $frames } amostras · { $channels } canais
settings-host-output-load-failed = Não foi possível carregar as definições de saída
settings-host-input-load-failed = Não foi possível carregar as definições de entrada
settings-host-discover-hosts-failed = Não foi possível detetar os anfitriões de áudio
settings-host-saved-host-unavailable = O anfitrião de áudio guardado não está disponível.
settings-host-saved-output-unavailable = O dispositivo de saída guardado não está disponível.
settings-host-output-fallback-title = Saída de áudio alternativa
settings-host-output-fallback-message = { $reason } A usar a saída predefinida do sistema.
settings-host-input-enabled-not-saved = Entrada de áudio ativada, mas não guardada
settings-host-input-fallback-title = Entrada de áudio alternativa
settings-host-input-fallback-message = O dispositivo de entrada guardado não está disponível. A usar a entrada predefinida do sistema.
settings-host-input-change-failed = Não foi possível alterar a entrada de áudio
settings-host-input-not-saved = Entrada de áudio alterada, mas não guardada
settings-host-discover-outputs-failed = Não foi possível detetar os dispositivos de saída
settings-host-output-change-failed = Não foi possível alterar a saída de áudio
settings-host-output-not-saved = Saída de áudio alterada, mas não guardada

## Project

settings-project-image-open-failed = Não foi possível abrir a imagem
settings-project-cover-save-failed = Não foi possível guardar a capa
settings-project-updated = Informações do projeto atualizadas
settings-project-title = Título
settings-project-title-required = O título é obrigatório
settings-project-author = Autor
settings-project-author-help = Separe vários artistas com ;
settings-project-genre = Género
settings-project-version = Versão do projeto
settings-project-description = Descrição
settings-project-created-at = Criado em
settings-project-saving = A guardar…
settings-project-save = Guardar informações do projeto
settings-project-cover = Capa
settings-project-cover-help = Imagem quadrada incorporada no áudio exportado
settings-project-cover-choose = Escolher imagem…
settings-project-cover-replace = Substituir…
settings-project-changed-banner = O projeto atual foi alterado enquanto este formulário tem alterações por guardar.
settings-project-keep-edits = Manter alterações
settings-project-reload = Recarregar projeto

## Appearance

settings-appearance-color-theme = Tema de cores
settings-appearance-load-theme = Carregar tema JSON
settings-appearance-color-theme-help = O tema de cores escolhido define o seu próprio brilho e cores. Escolha Predefinido para usar o modo de tema e a paleta de destaque.
settings-appearance-theme-mode = Modo do tema
settings-appearance-mode-system = Sistema
settings-appearance-mode-light = Claro
settings-appearance-mode-dark = Escuro
settings-appearance-accent = Paleta de destaque
settings-appearance-background = Fundo da área de trabalho
settings-appearance-background-default = Fundo predefinido
settings-appearance-background-choose = Escolher imagem
settings-appearance-background-fit = Ajuste da imagem
settings-appearance-overlay = Camada escura: { $percent }%
settings-appearance-font = Tipo de letra da aplicação
settings-appearance-font-system = Tipo de letra do sistema
settings-appearance-font-choose = Escolher TTF ou OTF
settings-appearance-font-use-system = Usar o tipo de letra do sistema
settings-appearance-assets-help = Os recursos personalizados ficam na localização original do ficheiro. Se um ficheiro for movido ou eliminado, o { -app-name } volta em segurança à predefinição.
settings-appearance-theme = Tema
settings-appearance-theme-remove = Remover tema
settings-appearance-theme-remove-title = Remover o tema de cores?
settings-appearance-theme-remove-message = «{ $name }» será removido do menu de temas.{ $active ->
    [yes] {" "}É o tema ativo, por isso o { -app-name } volta ao tema Predefinido.
   *[no] {""}
}

    O ficheiro { $file } não é eliminado. Pode voltar a carregá-lo com Carregar tema JSON.
settings-appearance-palette-purple = Roxo
settings-appearance-palette-blue = Azul
settings-appearance-palette-teal = Azul-petróleo
settings-appearance-palette-orange = Laranja
settings-appearance-palette-red = Vermelho
settings-appearance-palette-green = Verde
settings-appearance-palette-pink = Rosa
settings-appearance-palette-cyan = Ciano
settings-appearance-palette-indigo = Índigo
settings-appearance-palette-amber = Âmbar
settings-appearance-palette-lime = Lima
settings-appearance-palette-magenta = Magenta
settings-appearance-palette-graphite = Grafite
settings-appearance-fit-cover = Cobrir
settings-appearance-fit-contain = Conter
settings-appearance-fit-fill = Preencher
settings-appearance-load-failed = Não foi possível carregar as definições de aspeto
settings-appearance-background-unavailable-title = Imagem de fundo indisponível
settings-appearance-background-unavailable-message = A imagem de fundo guardada não está disponível. Está a ser usado o fundo predefinido.
settings-appearance-font-unavailable-title = Tipo de letra personalizado indisponível
settings-appearance-font-unavailable-message = O tipo de letra personalizado guardado não está disponível. Está a ser usado o tipo de letra do sistema.
settings-appearance-theme-unavailable-title = Tema de cores indisponível
settings-appearance-theme-unavailable-message = { $count ->
    [one] Um ficheiro de tema de cores guardado está indisponível ou deixou de ser válido. Foi removido do menu de temas.
   *[other] { $count } ficheiros de tema de cores guardados estão indisponíveis ou deixaram de ser válidos. Foram removidos do menu de temas.
}
settings-appearance-theme-apply-failed = Não foi possível aplicar o tema de cores
settings-appearance-theme-choose-failed = Não foi possível escolher o tema de cores
settings-appearance-theme-load-failed = Não foi possível carregar o tema de cores
settings-appearance-theme-remove-failed = Não foi possível remover o tema de cores
settings-appearance-background-choose-failed = Não foi possível escolher a imagem de fundo
settings-appearance-font-choose-failed = Não foi possível escolher o tipo de letra
settings-appearance-font-load-failed = Não foi possível carregar o tipo de letra
settings-appearance-not-saved = Aspeto alterado, mas não guardado

## Key bindings

settings-keys-search = Procurar comandos
settings-keys-reset-all = Repor tudo
settings-keys-no-match = Nenhum comando corresponde a esta pesquisa.
settings-keys-capture-hint = { $hint } Esc cancela a captura.
settings-keys-reset-all-title = Repor todos os atalhos?
settings-keys-reset-all-message = Todos os comandos voltarão à combinação de teclas predefinida.
settings-keys-default = Predefinição: { $chord }
settings-keys-reset = Repor { $command }
settings-keys-change = Alterar
settings-keys-change-title = Alterar { $command }
settings-keys-press = Prima o novo atalho

## Plugins

settings-plugins-description = O { -app-name } carrega o catálogo em cache ao arrancar. As análises só são executadas quando pedidas e testam cada plugin num processo auxiliar isolado.
settings-plugins-additional-folders = Pastas de análise adicionais
settings-plugins-no-additional-folders = Não há pastas adicionais configuradas.
settings-plugins-add-folder = Adicionar pasta
settings-plugins-system-folders = Pastas de análise do sistema
settings-plugins-no-system-folders = Não há pastas padrão disponíveis nesta plataforma.
settings-plugins-timeout = Tempo limite por plugin
settings-plugins-scanning = A analisar…
settings-plugins-scan-now = Analisar agora
settings-plugins-cancelling = A cancelar…
settings-plugins-cancel-scan = Cancelar análise
settings-plugins-retry-failed = Repetir plugins com falha ou em quarentena
settings-plugins-preparing = A preparar a análise…
settings-plugins-progress = { $completed } de { $total } módulos · { $count ->
    [one] { $count } plugin detetado
   *[other] { $count } plugins detetados
}
settings-plugins-scan-cancelled = Análise cancelada. Foram mantidos { $count } plugins.
settings-plugins-scan-complete = Análise concluída. Foram detetados { $count } plugins.
settings-plugins-failures = { $count } falhas de análise
settings-plugins-external-catalog = Catálogo externo
settings-plugins-catalog-summary = { $available } disponíveis, { $unavailable } indisponíveis
settings-plugins-remove-folder = Remover pasta
settings-plugins-folder-choose = Escolher pasta de plugins
settings-plugins-initialize-failed = Não foi possível inicializar as definições de plugins
settings-plugins-folder-choose-failed = Não foi possível escolher a pasta de plugins
settings-plugins-save-failed = Não foi possível guardar as definições de plugins
settings-plugins-scan-failed = A análise de plugins falhou
settings-plugins-cancel-failed = Não foi possível cancelar a análise de plugins

## Logs

settings-logs-description = Este visualizador contém os registos da aplicação Flutter e do motor de áudio Rust. Cada entrada indica a sua origem.
settings-logs-capture-level = Nível de captura
settings-logs-retained = Entradas mantidas
settings-logs-search = Procurar nos registos
settings-logs-display-level = Nível de apresentação
settings-logs-source = Origem
settings-logs-source-all = Todas
settings-logs-resume = Retomar apresentação
settings-logs-pause = Pausar apresentação
settings-logs-copy = Copiar filtrados
settings-logs-export = Exportar filtrados
settings-logs-count = { $shown } mostradas • { $captured }/{ $maximum } capturadas{ $paused ->
    [yes] {" "}• apresentação em pausa
   *[no] {""}
}
settings-logs-empty = Não há entradas de registo correspondentes.
settings-logs-copy-failed = Não foi possível copiar os registos
settings-logs-copied = Registos filtrados copiados
settings-logs-export-failed = Não foi possível exportar os registos
settings-logs-exported = Registos exportados para { $path }
settings-logs-export-dialog = Exportar registos do { -app-name }
settings-logs-clear-title = Limpar os registos capturados?
settings-logs-clear-message = Remove todas as entradas do visualizador em memória.
settings-logs-clear-confirm = Limpar registos
settings-logs-load-failed = Não foi possível carregar as definições de registo
settings-logs-not-saved = Definição de registo aplicada, mas não guardada

## Info

settings-info-description = O { -app-name } é uma estação de trabalho de áudio digital multiplataforma criada com Flutter e Rust.
settings-info-application = Aplicação
settings-info-version-unavailable = As informações de versão não estão disponíveis.
settings-info-name = Nome
settings-info-version = Versão
settings-info-build = Compilação
settings-info-not-specified = Não especificado
settings-info-report-bug = Comunicar um erro
settings-info-report-bug-help = Inclua a sua versão do { -app-name }, o sistema operativo, os passos para reproduzir, o resultado esperado, o resultado obtido e os registos relevantes.
settings-info-copy-url = Copiar URL para comunicar erros
settings-info-licenses = Licenças de código aberto
settings-info-view-licenses = Ver licenças
settings-info-copy-url-failed = Não foi possível copiar o URL
settings-info-url-copied = URL para comunicar erros copiado

## Cover art and file dialogs

settings-cover-crop-title = Recortar capa
settings-cover-crop-help = Arraste para mover; desloque ou aperte para ampliar
settings-cover-crop-use = Usar imagem
settings-project-cover-dialog = Escolher uma imagem de capa
settings-audio-metronome-dialog = Escolher o som do metrónomo
settings-audio-metronome-setting-load-failed = Não foi possível carregar a definição do som do metrónomo
settings-audio-metronome-unavailable-title = Som do metrónomo indisponível
settings-audio-metronome-unavailable-message = O som do metrónomo guardado não está disponível. Está a ser usado o clique predefinido.
settings-audio-metronome-choose-failed = Não foi possível escolher o som do metrónomo
settings-audio-metronome-load-failed = Não foi possível carregar o som do metrónomo
settings-audio-metronome-restore-failed = Não foi possível repor o som predefinido do metrónomo
settings-audio-metronome-not-saved = Som do metrónomo alterado, mas não guardado
settings-appearance-background-dialog = Escolher o fundo da área de trabalho
settings-appearance-font-dialog = Escolher o tipo de letra da aplicação
settings-appearance-theme-dialog = Escolher tema de cores
settings-appearance-theme-too-large = O ficheiro do tema de cores excede 1 MB

## Color theme files

settings-theme-invalid = Tema de cores inválido:
settings-theme-invalid-json = O ficheiro não é JSON válido: { $reason }
settings-theme-not-object = O tema tem de ser um objeto JSON.
settings-theme-unknown-field = Campo desconhecido "{ $field }".
settings-theme-missing-field = Falta "{ $field }".
settings-theme-colors-not-object = "colors" tem de ser um objeto de funções de cor.
settings-theme-name-not-text = "name" tem de ser texto.
settings-theme-name-empty = "name" não pode estar vazio.
settings-theme-name-too-long = "name" pode ter no máximo { $maximum } carateres.
settings-theme-brightness-invalid = "brightness" tem de ser "light" ou "dark".
settings-theme-missing-color = Falta a cor obrigatória "{ $role }".
settings-theme-color-invalid = A cor "{ $role }" tem de ser escrita como "#RRGGBB" ou "#RRGGBBAA".
settings-theme-unknown-color = Cor desconhecida "{ $role }".
