## Startup

app-settings-reset-title = 设置已重置
app-settings-reset-message = 无法读取 { $file } 中的设置（{ $reason }）。将使用默认值；旧文件已保留为 { $backup }。

## Crash recovery

app-crash-recovery-unavailable = 崩溃恢复不可用
app-crash-discard-failed = 无法丢弃恢复的项目
app-crash-report-export-failed = 无法导出报告
app-crash-report-saved = 报告已保存
app-crash-report-exported = 崩溃报告已导出到 { $path }
app-crash-reports-delete-failed = 无法删除崩溃报告

## Timeline

app-timeline-loop-set-failed = 无法设置循环区域
app-timeline-loop-clear-failed = 无法清除循环区域
app-timeline-cue-add-failed = 无法添加提示标记
app-timeline-cue-remove-failed = 无法移除提示标记
app-timeline-cue-edit-failed = 无法编辑提示标记
app-timeline-bounce-failed = 无法渲染循环区域
app-timeline-bounced-title = 已渲染为新音源
app-timeline-bounced-message = 循环区域现已加入音源列表。

## Background work

app-job-cancelled = 后台任务 { $id } 已取消。
app-job-failed = 后台任务失败
app-blocking-timeout-title = 操作超时
app-blocking-timeout-message = “{ $task }”未在 { $seconds } 秒内完成，已被释放；它会在后台继续运行。
app-blocking-cancelled = “{ $task }”在开始前已被取消。
app-blocking-failed = 操作失败

## Recording

app-recording-arm-failed = 无法将轨道设为录音准备
app-recording-input-on-title = 音频输入已开启
app-recording-input-on-message = 音频输入原本是关闭的，现已开启。可在设置中更改输入设备。
app-recording-nothing-title = 没有可录制的轨道
app-recording-nothing-message = 请选择一条音频轨道进行录音。
app-recording-save-failed = 无法保存录音
app-recordings-save-failed = 无法保存这些录音

## Project

app-project-recover-failed = 无法恢复项目
app-project-audio-load-failed = 无法加载音频
app-project-source-delete-failed = 无法删除音频源
app-project-source-replace-failed = 无法替换音频源
app-project-pattern-delete-failed = 无法删除样式
app-project-info-update-failed = 无法更新项目信息
app-project-undo-failed = 无法撤销
app-project-redo-failed = 无法重做
app-project-refresh-failed = { $action }：刷新项目失败
app-project-instrument-rename-failed = 无法重命名乐器
app-project-trim-failed = 无法修剪音频
app-project-envelope-edit-failed = 无法编辑波形包络
app-project-saved-title = 项目已保存
app-project-saved-message = 项目已保存到 { $path }

## Automation targets

app-automation-missing-effect = 缺失的效果器
app-automation-sampler = 采样器
app-automation-missing-instrument = 缺失的乐器
app-automation-track = 轨道
app-automation-bus = 总线
app-automation-master = 主输出
app-automation-transport = 走带
app-automation-other-group = 其他

## Tracks

app-tracks-input-change-failed = 无法更改轨道输入
app-tracks-samples-audio-only = 音频采样只能拖放到音频轨道上
app-tracks-move-type-mismatch = 无法将{ $source ->
    [audio] 音频
    [midi] MIDI
   *[automation] 自动化
}片段移动到{ $target ->
    [audio] 音频
    [midi] MIDI
   *[automation] 自动化
}轨道

## Mixer channel templates

app-mixer-template-save-failed = 无法保存通道模板
app-mixer-template-saved = 通道模板已保存到 { $path }
app-mixer-template-load-failed = 无法加载通道模板
app-mixer-template-loaded = 已加载通道模板
app-mixer-template-skipped = 已跳过不可用的插件：{ $plugins }

## Menu bar

app-menu-project = 项目
app-menu-new-project = 新建项目
app-menu-open-project = 打开项目
app-menu-open-recent = 打开最近的项目
app-menu-save-project = 保存项目
app-menu-save-as = 另存为...
app-menu-import-audio = 导入音频
app-menu-export-project = 导出项目
app-menu-settings = 设置
app-menu-quit = 退出 { -app-name }
app-menu-edit = 编辑
app-menu-undo = 撤销
app-menu-redo = 重做
app-menu-view = 视图
app-menu-zoom-in = 放大
app-menu-zoom-out = 缩小
