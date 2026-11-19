## Startup

app-settings-reset-title = 設定をリセットしました
app-settings-reset-message = { $file } の設定を読み込めませんでした（{ $reason }）。既定値を使用します。古いファイルは { $backup } として保存されています。

## Crash recovery

app-crash-recovery-unavailable = クラッシュからの復元を使用できません
app-crash-discard-failed = 復元したプロジェクトを破棄できませんでした
app-crash-report-export-failed = レポートを書き出せませんでした
app-crash-report-saved = レポートを保存しました
app-crash-report-exported = クラッシュレポートを { $path } に書き出しました
app-crash-reports-delete-failed = クラッシュレポートを削除できませんでした

## Timeline

app-timeline-loop-set-failed = ループ範囲を設定できませんでした
app-timeline-loop-clear-failed = ループ範囲を解除できませんでした
app-timeline-cue-add-failed = キューマーカーを追加できませんでした
app-timeline-cue-remove-failed = キューマーカーを削除できませんでした
app-timeline-cue-edit-failed = キューマーカーを編集できませんでした
app-timeline-bounce-failed = ループ範囲をバウンスできませんでした
app-timeline-bounced-title = 新しいソースにバウンスしました
app-timeline-bounced-message = ループ範囲がソース一覧に追加されました。

## Background work

app-job-cancelled = バックグラウンドジョブ { $id } はキャンセルされました。
app-job-failed = バックグラウンドタスクが失敗しました
app-blocking-timeout-title = 操作がタイムアウトしました
app-blocking-timeout-message = 「{ $task }」は { $seconds } 秒以内に終わらなかったため解除されました。処理はバックグラウンドで続行されます。
app-blocking-cancelled = 「{ $task }」は開始前にキャンセルされました。
app-blocking-failed = 操作に失敗しました

## Recording

app-recording-arm-failed = トラックを録音待機にできませんでした
app-recording-input-on-title = オーディオ入力をオンにしました
app-recording-input-on-message = オーディオ入力がオフだったのでオンにしました。入力デバイスは設定で変更できます。
app-recording-nothing-title = 録音対象がありません
app-recording-nothing-message = 録音するオーディオトラックを選択してください。
app-recording-save-failed = 録音を保存できませんでした
app-recordings-save-failed = 録音を保存できませんでした
app-project-recover-failed = プロジェクトを復元できませんでした
app-project-audio-load-failed = オーディオを読み込めませんでした
app-project-source-delete-failed = オーディオソースを削除できませんでした
app-project-source-replace-failed = オーディオソースを置き換えられませんでした
app-project-pattern-delete-failed = パターンを削除できませんでした
app-project-info-update-failed = プロジェクト情報を更新できませんでした
app-project-undo-failed = 元に戻せませんでした
app-project-redo-failed = やり直せませんでした
app-project-refresh-failed = { $action }：プロジェクトの更新に失敗しました
app-project-instrument-rename-failed = インストゥルメントの名前を変更できませんでした
app-project-trim-failed = オーディオをトリミングできませんでした
app-project-envelope-edit-failed = 波形エンベロープを編集できませんでした
app-project-saved-title = プロジェクトを保存しました
app-project-saved-message = プロジェクトを { $path } に保存しました

## Automation targets

app-automation-missing-effect = 見つからないエフェクト
app-automation-sampler = サンプラー
app-automation-missing-instrument = 見つからないインストゥルメント
app-automation-track = トラック
app-automation-bus = バス
app-automation-master = マスター
app-automation-transport = トランスポート
app-automation-other-group = その他

## Tracks

app-tracks-input-change-failed = トラックの入力を変更できませんでした
app-tracks-samples-audio-only = オーディオサンプルはオーディオトラックにのみドロップできます
app-tracks-move-type-mismatch = { $source ->
    [audio] オーディオ
    [midi] MIDI
   *[automation] オートメーション
}クリップを{ $target ->
    [audio] オーディオ
    [midi] MIDI
   *[automation] オートメーション
}トラックに移動することはできません

## Mixer channel templates

app-mixer-template-save-failed = チャンネルテンプレートを保存できませんでした
app-mixer-template-saved = チャンネルテンプレートを { $path } に保存しました
app-mixer-template-load-failed = チャンネルテンプレートを読み込めませんでした
app-mixer-template-loaded = チャンネルテンプレートを読み込みました
app-mixer-template-skipped = 使用できないプラグインをスキップしました：{ $plugins }

## Menu bar

app-menu-project = プロジェクト
app-menu-new-project = 新規プロジェクト
app-menu-open-project = プロジェクトを開く
app-menu-open-recent = 最近使ったプロジェクト
app-menu-save-project = プロジェクトを保存
app-menu-save-as = 名前を付けて保存...
app-menu-import-audio = オーディオを読み込む
app-menu-export-project = プロジェクトを書き出す
app-menu-settings = 設定
app-menu-quit = { -app-name } を終了
app-menu-edit = 編集
app-menu-undo = 元に戻す
app-menu-redo = やり直す
app-menu-view = 表示
app-menu-zoom-in = 拡大
app-menu-zoom-out = 縮小
