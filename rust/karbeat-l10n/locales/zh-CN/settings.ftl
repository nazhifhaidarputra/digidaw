## Language

settings-language-title = 语言
settings-language-field = 应用语言
settings-language-system = 系统默认（{ $language }）
settings-language-help = 更改菜单、对话框和消息的语言。插件参数名称保持插件自身提供的名称。
settings-language-change-title = 更改语言？
settings-language-change-warning = 你即将更改应用语言。请记住此菜单的位置，以免迷失在翻译中。确定要更改语言吗？
settings-language-change-confirm = 更改语言
settings-language-change-failed = 无法更改语言
settings-language-load-failed = 无法加载语言设置

## Settings screen

settings-title = 设置
settings-close = 关闭设置
settings-page-placeholder = 此设置页面将在后续阶段实现。
settings-menu-general = 常规
settings-menu-general-description = 配置应用的全局行为，例如撤销历史的保留数量。
settings-menu-host-devices = 主机与设备
settings-menu-host-devices-description = 选择音频主机和输出设备。暂不支持输入设备。
settings-menu-project = 项目
settings-menu-project-description = 编辑随当前项目保存的元数据。
settings-menu-appearance = 外观
settings-menu-appearance-description = 自定义应用的主题、颜色、背景和字体。
settings-menu-audio = 音频
settings-menu-audio-description = 配置 DSP 处理的采样率和块大小。
settings-menu-key-bindings = 快捷键
settings-menu-key-bindings-description = 查看并自定义应用的键盘快捷键。
settings-menu-plugins = 插件
settings-menu-plugins-description = 第三方插件的发现与托管设置。
settings-menu-logs = 日志
settings-menu-logs-description = 配置诊断并查看最近的应用日志。
settings-menu-info = 关于
settings-menu-info-description = 查看应用版本、许可证和错误报告信息。

## General

settings-general-history-limit = 最大撤销历史条数
settings-general-history-entries = { $count } 条
settings-general-history-help = 数值越小，占用内存越少。降低上限会立即删除最旧的撤销和重做记录。选择“已禁用”会清空两种历史。
settings-general-auto-save = 自动保存
settings-general-auto-save-enable = 启用自动保存
settings-general-auto-save-interval = 自动保存间隔
settings-general-auto-save-help = 自动保存会为未保存的更改写入一份恢复副本。它不会覆盖你的项目文件；如果程序崩溃，{ -app-name } 会在下次启动时提示恢复该副本。
settings-general-interval-seconds = { $count } 秒
settings-general-interval-minutes = { $count } 分钟
settings-general-folders = 文件夹
settings-general-project-folder = 默认项目文件夹
settings-general-project-folder-unset = 未设置。保存和打开对话框从系统选择的位置开始。
settings-general-project-folder-choose = 选择默认项目文件夹
settings-general-export-folder = 默认导出文件夹
settings-general-export-folder-unset = 未设置。每次导出时选择文件夹。
settings-general-export-folder-choose = 选择默认导出文件夹
settings-general-folder-missing = 此文件夹已不存在，因此不会使用。
settings-general-recent-projects = 最近的项目
settings-general-recent-projects-show = 显示最近的项目
settings-general-recent-projects-help = 在“项目”菜单的“打开最近的项目”下列出最近打开的项目。隐藏后列表仍会保留。
settings-general-load-failed = 无法加载设置
settings-general-history-apply-failed = 无法应用历史上限
settings-general-history-update-failed = 无法更新历史上限
settings-general-history-not-saved = 历史上限已应用但未保存
settings-general-auto-save-load-failed = 无法加载自动保存设置
settings-general-auto-save-apply-failed = 无法应用自动保存设置
settings-general-auto-save-update-failed = 无法更新自动保存
settings-general-auto-save-not-saved = 自动保存已应用但未保存
settings-general-folder-choose-failed = 无法选择文件夹
settings-general-folder-save-failed = 无法保存文件夹
settings-general-recent-projects-save-failed = 无法保存最近项目设置

## Audio

settings-audio-description = DSP 设置控制专用的处理线程。设备流的值为只读，与之不同也没有关系。
settings-audio-sample-rate = DSP 采样率
settings-audio-hertz = { $value } Hz
settings-audio-block-size = DSP 块大小
settings-audio-frames = { $count } 帧
settings-audio-block-latency = 一个 DSP 块约为 { $milliseconds } 毫秒。块越小，处理延迟越低，但 CPU 调度压力越大。
settings-audio-applying = 正在应用…
settings-audio-revert = 还原
settings-audio-metronome = 节拍器声音
settings-audio-metronome-default = 默认咔嗒声
settings-audio-metronome-choose = 选择声音
settings-audio-metronome-use-default = 使用默认
settings-audio-metronome-help = 你的声音在弱拍按原样播放，在强拍高一个八度播放。每一拍都会切断上一拍剩余的声音。
settings-audio-device-stream = 设备流（只读）
settings-audio-device-stream-starting = 正在启动当前设备流。
settings-audio-device-output = 输出：{ $device }
settings-audio-device-sample-rate = 设备采样率：{ $value } Hz
settings-audio-device-buffer = 设备回调缓冲区：{ $count } 帧
settings-audio-device-channels = 声道数：{ $count }
settings-audio-reset-title = DSP 设置已重置
settings-audio-reset-message = 不受支持的已保存 DSP 值已恢复为默认值。
settings-audio-initialize-failed = 无法初始化 DSP 设置
settings-audio-apply-failed = 无法应用 DSP 设置
settings-audio-not-saved = DSP 设置已应用但未保存

## Host & Devices

settings-host-description = 选择音频播放的位置以及音频轨道录音所用的设备。
settings-host-audio-host = 音频主机
settings-host-system-default = 系统默认
settings-host-output-device = 输出设备
settings-host-system-default-output = 系统默认输出
settings-host-current-default = { $device }（当前默认）
settings-host-audio-input = 音频输入
settings-host-input-enable = 启用音频输入
settings-host-input-help = 允许音频轨道录制并监听输入设备。将轨道设为录音准备时会自动开启。
settings-host-input-device = 输入设备
settings-host-system-default-input = 系统默认输入
settings-host-input-retry = 重新查找输入设备
settings-host-stream-summary = { $device } · { $rate } Hz · { $channels } 声道
settings-host-retry = 重新查找
settings-host-fallback-active = { $reason } 正在使用系统默认输出。
settings-host-active-stream = 当前设备流
settings-host-active-stream-summary = { $rate } Hz · { $frames } 帧 · { $channels } 声道
settings-host-output-load-failed = 无法加载输出设置
settings-host-input-load-failed = 无法加载输入设置
settings-host-discover-hosts-failed = 无法发现音频主机
settings-host-saved-host-unavailable = 已保存的音频主机不可用。
settings-host-saved-output-unavailable = 已保存的输出设备不可用。
settings-host-output-fallback-title = 备用音频输出
settings-host-output-fallback-message = { $reason } 将使用系统默认输出。
settings-host-input-enabled-not-saved = 音频输入已开启但未保存
settings-host-input-fallback-title = 备用音频输入
settings-host-input-fallback-message = 已保存的输入设备不可用。将使用系统默认输入。
settings-host-input-change-failed = 无法更改音频输入
settings-host-input-not-saved = 音频输入已更改但未保存
settings-host-discover-outputs-failed = 无法发现输出设备
settings-host-output-change-failed = 无法更改音频输出
settings-host-output-not-saved = 音频输出已更改但未保存

## Project

settings-project-image-open-failed = 无法打开图片
settings-project-cover-save-failed = 无法保存封面
settings-project-updated = 项目信息已更新
settings-project-title = 标题
settings-project-title-required = 标题为必填项
settings-project-author = 作者
settings-project-author-help = 多位艺术家之间用 ; 分隔
settings-project-genre = 流派
settings-project-version = 项目版本
settings-project-description = 描述
settings-project-created-at = 创建时间
settings-project-saving = 正在保存…
settings-project-save = 保存项目信息
settings-project-cover = 封面图片
settings-project-cover-help = 嵌入导出音频的正方形图片
settings-project-cover-choose = 选择图片…
settings-project-cover-replace = 替换…
settings-project-changed-banner = 此表单有未保存的修改时，当前项目发生了变化。
settings-project-keep-edits = 保留修改
settings-project-reload = 重新加载项目

## Appearance

settings-appearance-color-theme = 配色主题
settings-appearance-load-theme = 加载 JSON 主题
settings-appearance-color-theme-help = 所选配色主题会使用自己的亮度和颜色。选择“默认”可使用主题模式和强调色板。
settings-appearance-theme-mode = 主题模式
settings-appearance-mode-system = 跟随系统
settings-appearance-mode-light = 浅色
settings-appearance-mode-dark = 深色
settings-appearance-accent = 强调色板
settings-appearance-background = 工作区背景
settings-appearance-background-default = 默认背景
settings-appearance-background-choose = 选择图片
settings-appearance-background-fit = 图片适配
settings-appearance-overlay = 暗色遮罩：{ $percent }%
settings-appearance-font = 应用字体
settings-appearance-font-system = 系统字体
settings-appearance-font-choose = 选择 TTF 或 OTF
settings-appearance-font-use-system = 使用系统字体
settings-appearance-assets-help = 自定义素材保留在原始文件位置。如果文件被移动或删除，{ -app-name } 会安全地恢复为默认设置。
settings-appearance-theme = 主题
settings-appearance-theme-remove = 移除主题
settings-appearance-theme-remove-title = 移除配色主题？
settings-appearance-theme-remove-message = “{ $name }”将从主题菜单中移除。{ $active ->
    [yes] 它是当前使用的主题，因此 { -app-name } 会切换回默认主题。
   *[no] {""}
}

    文件 { $file } 不会被删除。你可以通过“加载 JSON 主题”再次加载它。
settings-appearance-palette-purple = 紫色
settings-appearance-palette-blue = 蓝色
settings-appearance-palette-teal = 蓝绿色
settings-appearance-palette-orange = 橙色
settings-appearance-palette-red = 红色
settings-appearance-palette-green = 绿色
settings-appearance-palette-pink = 粉色
settings-appearance-palette-cyan = 青色
settings-appearance-palette-indigo = 靛蓝
settings-appearance-palette-amber = 琥珀色
settings-appearance-palette-lime = 青柠色
settings-appearance-palette-magenta = 品红
settings-appearance-palette-graphite = 石墨色
settings-appearance-fit-cover = 覆盖
settings-appearance-fit-contain = 完整显示
settings-appearance-fit-fill = 拉伸填充
settings-appearance-load-failed = 无法加载外观设置
settings-appearance-background-unavailable-title = 背景图片不可用
settings-appearance-background-unavailable-message = 已保存的背景图片不可用，正在使用默认背景。
settings-appearance-font-unavailable-title = 自定义字体不可用
settings-appearance-font-unavailable-message = 已保存的自定义字体不可用，正在使用系统字体。
settings-appearance-theme-unavailable-title = 配色主题不可用
settings-appearance-theme-unavailable-message = { $count } 个已保存的配色主题文件不可用或已失效，已从主题菜单中移除。
settings-appearance-theme-apply-failed = 无法应用配色主题
settings-appearance-theme-choose-failed = 无法选择配色主题
settings-appearance-theme-load-failed = 无法加载配色主题
settings-appearance-theme-remove-failed = 无法移除配色主题
settings-appearance-background-choose-failed = 无法选择背景图片
settings-appearance-font-choose-failed = 无法选择字体
settings-appearance-font-load-failed = 无法加载字体
settings-appearance-not-saved = 外观已更改但未保存

## Key bindings

settings-keys-search = 搜索命令
settings-keys-reset-all = 全部重置
settings-keys-no-match = 没有与此搜索匹配的命令。
settings-keys-capture-hint = { $hint } 按 Esc 取消录入。
settings-keys-reset-all-title = 重置所有快捷键？
settings-keys-reset-all-message = 所有命令都将恢复为默认按键组合。
settings-keys-default = 默认：{ $chord }
settings-keys-reset = 重置 { $command }
settings-keys-change = 更改
settings-keys-change-title = 更改 { $command }
settings-keys-press = 请按下新的快捷键

## Plugins

settings-plugins-description = { -app-name } 在启动时加载缓存的插件目录。扫描只在你请求时运行，并在隔离的辅助进程中逐个检测插件。
settings-plugins-additional-folders = 额外扫描文件夹
settings-plugins-no-additional-folders = 未配置额外文件夹。
settings-plugins-add-folder = 添加文件夹
settings-plugins-system-folders = 系统扫描文件夹
settings-plugins-no-system-folders = 此平台没有可用的标准文件夹。
settings-plugins-timeout = 单个插件超时
settings-plugins-scanning = 正在扫描…
settings-plugins-scan-now = 立即扫描
settings-plugins-cancelling = 正在取消…
settings-plugins-cancel-scan = 取消扫描
settings-plugins-retry-failed = 重试失败或被隔离的插件
settings-plugins-preparing = 正在准备扫描…
settings-plugins-progress = 已完成 { $completed }/{ $total } 个模块 · 发现 { $count } 个插件
settings-plugins-scan-cancelled = 扫描已取消。已保留 { $count } 个插件。
settings-plugins-scan-complete = 扫描完成。发现 { $count } 个插件。
settings-plugins-failures = { $count } 个扫描失败
settings-plugins-external-catalog = 外部插件目录
settings-plugins-catalog-summary = { $available } 个可用，{ $unavailable } 个不可用
settings-plugins-remove-folder = 移除文件夹
settings-plugins-folder-choose = 选择插件文件夹
settings-plugins-initialize-failed = 无法初始化插件设置
settings-plugins-folder-choose-failed = 无法选择插件文件夹
settings-plugins-save-failed = 无法保存插件设置
settings-plugins-scan-failed = 插件扫描失败
settings-plugins-cancel-failed = 无法取消插件扫描

## Logs

settings-logs-description = 此查看器包含 Flutter 应用日志和 Rust 音频引擎日志。每条记录都标有来源。
settings-logs-capture-level = 记录级别
settings-logs-retained = 保留条数
settings-logs-search = 搜索日志
settings-logs-display-level = 显示级别
settings-logs-source = 来源
settings-logs-source-all = 全部
settings-logs-resume = 恢复显示
settings-logs-pause = 暂停显示
settings-logs-copy = 复制筛选结果
settings-logs-export = 导出筛选结果
settings-logs-count = 显示 { $shown } 条 • 已记录 { $captured }/{ $maximum } 条{ $paused ->
    [yes] {" "}• 显示已暂停
   *[no] {""}
}
settings-logs-empty = 没有匹配的日志记录。
settings-logs-copy-failed = 无法复制日志
settings-logs-copied = 已复制筛选后的日志
settings-logs-export-failed = 无法导出日志
settings-logs-exported = 日志已导出到 { $path }
settings-logs-export-dialog = 导出 { -app-name } 日志
settings-logs-clear-title = 清除已记录的日志？
settings-logs-clear-message = 这会从内存中的查看器移除所有记录。
settings-logs-clear-confirm = 清除日志
settings-logs-load-failed = 无法加载日志设置
settings-logs-not-saved = 日志设置已应用但未保存

## Info

settings-info-description = { -app-name } 是一款基于 Flutter 和 Rust 的跨平台数字音频工作站。
settings-info-application = 应用
settings-info-version-unavailable = 版本信息不可用。
settings-info-name = 名称
settings-info-version = 版本
settings-info-build = 构建号
settings-info-not-specified = 未指定
settings-info-report-bug = 报告错误
settings-info-report-bug-help = 请附上你的 { -app-name } 版本、操作系统、复现步骤、预期结果、实际结果和相关日志。
settings-info-copy-url = 复制错误报告网址
settings-info-licenses = 开源许可证
settings-info-view-licenses = 查看许可证
settings-info-copy-url-failed = 无法复制网址
settings-info-url-copied = 已复制错误报告网址

## Cover art and file dialogs

settings-cover-crop-title = 裁剪封面
settings-cover-crop-help = 拖动以移动，滚动或双指缩放以调整大小
settings-cover-crop-use = 使用图片
settings-project-cover-dialog = 选择封面图片
settings-audio-metronome-dialog = 选择节拍器声音
settings-audio-metronome-setting-load-failed = 无法加载节拍器声音设置
settings-audio-metronome-unavailable-title = 节拍器声音不可用
settings-audio-metronome-unavailable-message = 已保存的节拍器声音不可用，正在使用默认咔嗒声。
settings-audio-metronome-choose-failed = 无法选择节拍器声音
settings-audio-metronome-load-failed = 无法加载节拍器声音
settings-audio-metronome-restore-failed = 无法恢复默认节拍器声音
settings-audio-metronome-not-saved = 节拍器声音已更改但未保存
settings-appearance-background-dialog = 选择工作区背景
settings-appearance-font-dialog = 选择应用字体
settings-appearance-theme-dialog = 选择配色主题
settings-appearance-theme-too-large = 配色主题文件超过 1 MB

## Color theme files

settings-theme-invalid = 无效的配色主题：
settings-theme-invalid-json = 该文件不是有效的 JSON：{ $reason }
settings-theme-not-object = 主题必须是一个 JSON 对象。
settings-theme-unknown-field = 未知字段“{ $field }”。
settings-theme-missing-field = 缺少“{ $field }”。
settings-theme-colors-not-object = “colors”必须是由颜色角色组成的对象。
settings-theme-name-not-text = “name”必须是文本。
settings-theme-name-empty = “name”不能为空。
settings-theme-name-too-long = “name”最多 { $maximum } 个字符。
settings-theme-brightness-invalid = “brightness”必须是“light”或“dark”。
settings-theme-missing-color = 缺少必需的颜色“{ $role }”。
settings-theme-color-invalid = 颜色“{ $role }”必须写成“#RRGGBB”或“#RRGGBBAA”。
settings-theme-unknown-color = 未知颜色“{ $role }”。
