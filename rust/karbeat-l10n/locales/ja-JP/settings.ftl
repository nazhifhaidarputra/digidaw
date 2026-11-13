## Language

settings-language-title = 言語
settings-language-field = アプリの言語
settings-language-system = システムのデフォルト（{ $language }）
settings-language-help = メニュー、ダイアログ、メッセージの言語を変更します。プラグインのパラメーター名はプラグインが付けた名前のままです。
settings-language-change-title = 言語を変更しますか？
settings-language-change-warning = アプリの言語を変更しようとしています。翻訳の中で迷子にならないよう、このメニューの場所を覚えておいてください。本当に言語を変更しますか？
settings-language-change-confirm = 言語を変更
settings-language-change-failed = 言語を変更できませんでした
settings-language-load-failed = 言語設定を読み込めませんでした

## Settings screen

settings-title = 設定
settings-close = 設定を閉じる
settings-page-placeholder = この設定ページは今後のフェーズで実装されます。
settings-menu-general = 一般
settings-menu-general-description = 取り消し履歴の保持など、アプリ全体の動作を設定します。
settings-menu-host-devices = ホストとデバイス
settings-menu-host-devices-description = オーディオホストと出力デバイスを選択します。入力デバイスにはまだ対応していません。
settings-menu-project = プロジェクト
settings-menu-project-description = 現在のプロジェクトに保存されるメタデータを編集します。
settings-menu-appearance = 外観
settings-menu-appearance-description = アプリのテーマ、色、背景、フォントをカスタマイズします。
settings-menu-audio = オーディオ
settings-menu-audio-description = DSP 処理のサンプルレートとブロックサイズを設定します。
settings-menu-key-bindings = キー割り当て
settings-menu-key-bindings-description = アプリのキーボードショートカットを確認・変更します。
settings-menu-plugins = プラグイン
settings-menu-plugins-description = サードパーティ製プラグインの検出とホストの設定です。
settings-menu-logs = ログ
settings-menu-logs-description = 診断を設定し、最近のアプリのログを確認します。
settings-menu-info = 情報
settings-menu-info-description = アプリのバージョン、ライセンス、不具合報告の情報を表示します。

## General

settings-general-history-limit = 取り消し履歴の最大件数
settings-general-history-entries = { $count } 件
settings-general-history-help = 値を小さくするとメモリの使用量が減ります。上限を下げると、最も古い取り消し・やり直しの履歴がすぐに削除されます。「無効」を選ぶと両方の履歴が消去されます。
settings-general-auto-save = 自動保存
settings-general-auto-save-enable = 自動保存を有効にする
settings-general-auto-save-interval = 自動保存の間隔
settings-general-auto-save-help = 自動保存は未保存の変更の復元用コピーを書き出します。プロジェクトファイルを上書きすることはありません。クラッシュした場合、次回の起動時に { -app-name } がコピーの復元を提案します。
settings-general-interval-seconds = { $count } 秒
settings-general-interval-minutes = { $count } 分
settings-general-folders = フォルダー
settings-general-project-folder = 既定のプロジェクトフォルダー
settings-general-project-folder-unset = 未設定です。保存と開くダイアログはシステムが選んだ場所から始まります。
settings-general-project-folder-choose = 既定のプロジェクトフォルダーを選択
settings-general-export-folder = 既定の書き出しフォルダー
settings-general-export-folder-unset = 未設定です。書き出しのたびにフォルダーを選択します。
settings-general-export-folder-choose = 既定の書き出しフォルダーを選択
settings-general-folder-missing = このフォルダーは存在しないため使用されません。
settings-general-recent-projects = 最近のプロジェクト
settings-general-recent-projects-show = 最近のプロジェクトを表示
settings-general-recent-projects-help = プロジェクトメニューの「最近使ったプロジェクト」に最近開いたプロジェクトを表示します。非表示にしても一覧は保持されます。
settings-general-load-failed = 設定を読み込めませんでした
settings-general-history-apply-failed = 履歴の上限を適用できませんでした
settings-general-history-update-failed = 履歴の上限を更新できませんでした
settings-general-history-not-saved = 履歴の上限は適用されましたが保存されていません
settings-general-auto-save-load-failed = 自動保存の設定を読み込めませんでした
settings-general-auto-save-apply-failed = 自動保存の設定を適用できませんでした
settings-general-auto-save-update-failed = 自動保存を更新できませんでした
settings-general-auto-save-not-saved = 自動保存は適用されましたが保存されていません
settings-general-folder-choose-failed = フォルダーを選択できませんでした
settings-general-folder-save-failed = フォルダーを保存できませんでした
settings-general-recent-projects-save-failed = 最近のプロジェクトの設定を保存できませんでした

## Audio

settings-audio-description = DSP の設定は専用の処理ワーカーを制御します。デバイスストリームの値は読み取り専用で、異なっていても問題ありません。
settings-audio-sample-rate = DSP サンプルレート
settings-audio-hertz = { $value } Hz
settings-audio-block-size = DSP ブロックサイズ
settings-audio-frames = { $count } フレーム
settings-audio-block-latency = DSP の 1 ブロックは約 { $milliseconds } ms に相当します。ブロックを小さくすると処理のレイテンシーは下がりますが、CPU のスケジューリング負荷が増えます。
settings-audio-applying = 適用中…
settings-audio-revert = 元に戻す
settings-audio-metronome = メトロノームの音
settings-audio-metronome-default = 既定のクリック
settings-audio-metronome-choose = 音を選択
settings-audio-metronome-use-default = 既定に戻す
settings-audio-metronome-help = 選んだ音は裏拍では録音されたまま、小節の頭では 1 オクターブ高く再生されます。各拍は前の拍の残りを止めます。
settings-audio-device-stream = デバイスストリーム（読み取り専用）
settings-audio-device-stream-starting = デバイスストリームを開始しています。
settings-audio-device-output = 出力：{ $device }
settings-audio-device-sample-rate = デバイスのサンプルレート：{ $value } Hz
settings-audio-device-buffer = デバイスのコールバックバッファー：{ $count } フレーム
settings-audio-device-channels = チャンネル数：{ $count }
settings-audio-reset-title = DSP 設定をリセットしました
settings-audio-reset-message = 対応していない保存済みの DSP 値を既定値に戻しました。
settings-audio-initialize-failed = DSP 設定を初期化できませんでした
settings-audio-apply-failed = DSP 設定を適用できませんでした
settings-audio-not-saved = DSP 設定は適用されましたが保存されていません

## Host & Devices

settings-host-description = オーディオの再生先と、オーディオトラックの録音に使うデバイスを選択します。
settings-host-audio-host = オーディオホスト
settings-host-system-default = システムの既定
settings-host-output-device = 出力デバイス
settings-host-system-default-output = システムの既定の出力
settings-host-current-default = { $device }（現在の既定）
settings-host-audio-input = オーディオ入力
settings-host-input-enable = オーディオ入力を有効にする
settings-host-input-help = オーディオトラックで入力デバイスを録音・モニターできるようにします。トラックを録音待機にするとオンになります。
settings-host-input-device = 入力デバイス
settings-host-system-default-input = システムの既定の入力
settings-host-input-retry = 入力デバイスを再検索
settings-host-stream-summary = { $device } · { $rate } Hz · { $channels } チャンネル
settings-host-retry = 再検索
settings-host-fallback-active = { $reason } システムの既定の出力を使用しています。
settings-host-active-stream = 使用中のデバイスストリーム
settings-host-active-stream-summary = { $rate } Hz · { $frames } フレーム · { $channels } チャンネル
settings-host-output-load-failed = 出力の設定を読み込めませんでした
settings-host-input-load-failed = 入力の設定を読み込めませんでした
settings-host-discover-hosts-failed = オーディオホストを検出できませんでした
settings-host-saved-host-unavailable = 保存されたオーディオホストを使用できません。
settings-host-saved-output-unavailable = 保存された出力デバイスを使用できません。
settings-host-output-fallback-title = オーディオ出力の代替
settings-host-output-fallback-message = { $reason } システムの既定の出力を使用します。
settings-host-input-enabled-not-saved = オーディオ入力はオンになりましたが保存されていません
settings-host-input-fallback-title = オーディオ入力の代替
settings-host-input-fallback-message = 保存された入力デバイスを使用できません。システムの既定の入力を使用します。
settings-host-input-change-failed = オーディオ入力を変更できませんでした
settings-host-input-not-saved = オーディオ入力は変更されましたが保存されていません
settings-host-discover-outputs-failed = 出力デバイスを検出できませんでした
settings-host-output-change-failed = オーディオ出力を変更できませんでした
settings-host-output-not-saved = オーディオ出力は変更されましたが保存されていません

## Project

settings-project-image-open-failed = 画像を開けませんでした
settings-project-cover-save-failed = カバーを保存できませんでした
settings-project-updated = プロジェクト情報を更新しました
settings-project-title = タイトル
settings-project-title-required = タイトルは必須です
settings-project-author = 作者
settings-project-author-help = 複数のアーティストは ; で区切ります
settings-project-genre = ジャンル
settings-project-version = プロジェクトのバージョン
settings-project-description = 説明
settings-project-created-at = 作成日時
settings-project-saving = 保存中…
settings-project-save = プロジェクト情報を保存
settings-project-cover = カバーアート
settings-project-cover-help = 書き出したオーディオに埋め込む正方形の画像
settings-project-cover-choose = 画像を選択…
settings-project-cover-replace = 置き換え…
settings-project-changed-banner = このフォームに未保存の編集があるうちに、現在のプロジェクトが変更されました。
settings-project-keep-edits = 編集を残す
settings-project-reload = プロジェクトを再読み込み

## Appearance

settings-appearance-color-theme = カラーテーマ
settings-appearance-load-theme = JSON テーマを読み込む
settings-appearance-color-theme-help = 選択したカラーテーマは独自の明るさと色を設定します。テーマモードとアクセントパレットを使うには「デフォルト」を選んでください。
settings-appearance-theme-mode = テーマモード
settings-appearance-mode-system = システム
settings-appearance-mode-light = ライト
settings-appearance-mode-dark = ダーク
settings-appearance-accent = アクセントパレット
settings-appearance-background = ワークスペースの背景
settings-appearance-background-default = 既定の背景
settings-appearance-background-choose = 画像を選択
settings-appearance-background-fit = 画像の配置
settings-appearance-overlay = 暗いオーバーレイ：{ $percent }%
settings-appearance-font = アプリのフォント
settings-appearance-font-system = システムフォント
settings-appearance-font-choose = TTF または OTF を選択
settings-appearance-font-use-system = システムフォントを使用
settings-appearance-assets-help = カスタムアセットは元のファイルの場所に置かれたままです。ファイルが移動または削除された場合、{ -app-name } は安全に既定に戻します。
settings-appearance-theme = テーマ
settings-appearance-theme-remove = テーマを削除
settings-appearance-theme-remove-title = カラーテーマを削除しますか？
settings-appearance-theme-remove-message = 「{ $name }」をテーマメニューから削除します。{ $active ->
    [yes] 使用中のテーマのため、{ -app-name } はデフォルトのテーマに戻ります。
   *[no] {""}
}

    ファイル { $file } は削除されません。「JSON テーマを読み込む」で再度読み込めます。
settings-appearance-palette-purple = パープル
settings-appearance-palette-blue = ブルー
settings-appearance-palette-teal = ティール
settings-appearance-palette-orange = オレンジ
settings-appearance-palette-red = レッド
settings-appearance-palette-green = グリーン
settings-appearance-palette-pink = ピンク
settings-appearance-palette-cyan = シアン
settings-appearance-palette-indigo = インディゴ
settings-appearance-palette-amber = アンバー
settings-appearance-palette-lime = ライム
settings-appearance-palette-magenta = マゼンタ
settings-appearance-palette-graphite = グラファイト
settings-appearance-fit-cover = カバー
settings-appearance-fit-contain = 全体を表示
settings-appearance-fit-fill = 引き伸ばし
settings-appearance-load-failed = 外観の設定を読み込めませんでした
settings-appearance-background-unavailable-title = 背景画像を使用できません
settings-appearance-background-unavailable-message = 保存された背景画像を使用できません。既定の背景を使用しています。
settings-appearance-font-unavailable-title = カスタムフォントを使用できません
settings-appearance-font-unavailable-message = 保存されたカスタムフォントを使用できません。システムフォントを使用しています。
settings-appearance-theme-unavailable-title = カラーテーマを使用できません
settings-appearance-theme-unavailable-message = 保存されたカラーテーマファイル { $count } 件が見つからないか無効になったため、テーマメニューから削除しました。
settings-appearance-theme-apply-failed = カラーテーマを適用できませんでした
settings-appearance-theme-choose-failed = カラーテーマを選択できませんでした
settings-appearance-theme-load-failed = カラーテーマを読み込めませんでした
settings-appearance-theme-remove-failed = カラーテーマを削除できませんでした
settings-appearance-background-choose-failed = 背景画像を選択できませんでした
settings-appearance-font-choose-failed = フォントを選択できませんでした
settings-appearance-font-load-failed = フォントを読み込めませんでした
settings-appearance-not-saved = 外観は変更されましたが保存されていません

## Key bindings

settings-keys-search = コマンドを検索
settings-keys-reset-all = すべてリセット
settings-keys-no-match = 検索に一致するコマンドはありません。
settings-keys-capture-hint = { $hint } Escape で入力をキャンセルします。
settings-keys-reset-all-title = すべてのショートカットをリセットしますか？
settings-keys-reset-all-message = すべてのコマンドが既定のキーの組み合わせに戻ります。
settings-keys-default = 既定：{ $chord }
settings-keys-reset = { $command } をリセット
settings-keys-change = 変更
settings-keys-change-title = { $command } を変更
settings-keys-press = 新しいショートカットを押してください

## Plugins

settings-plugins-description = { -app-name } は起動時にキャッシュ済みのカタログを読み込みます。スキャンは要求したときだけ実行され、各プラグインを分離したヘルパープロセスで調べます。
settings-plugins-additional-folders = 追加のスキャンフォルダー
settings-plugins-no-additional-folders = 追加のフォルダーは設定されていません。
settings-plugins-add-folder = フォルダーを追加
settings-plugins-system-folders = システムのスキャンフォルダー
settings-plugins-no-system-folders = このプラットフォームには標準のフォルダーがありません。
settings-plugins-timeout = プラグインごとのタイムアウト
settings-plugins-scanning = スキャン中…
settings-plugins-scan-now = 今すぐスキャン
settings-plugins-cancelling = キャンセル中…
settings-plugins-cancel-scan = スキャンをキャンセル
settings-plugins-retry-failed = 失敗・隔離されたプラグインを再試行
settings-plugins-preparing = スキャンを準備中…
settings-plugins-progress = { $total } 個中 { $completed } 個のモジュール · { $count } 個のプラグインを検出
settings-plugins-scan-cancelled = スキャンをキャンセルしました。{ $count } 個のプラグインを保持しました。
settings-plugins-scan-complete = スキャンが完了しました。{ $count } 個のプラグインを検出しました。
settings-plugins-failures = スキャンの失敗 { $count } 件
settings-plugins-external-catalog = 外部カタログ
settings-plugins-catalog-summary = 使用可能 { $available } 個、使用不可 { $unavailable } 個
settings-plugins-remove-folder = フォルダーを削除
settings-plugins-folder-choose = プラグインフォルダーを選択
settings-plugins-initialize-failed = プラグインの設定を初期化できませんでした
settings-plugins-folder-choose-failed = プラグインフォルダーを選択できませんでした
settings-plugins-save-failed = プラグインの設定を保存できませんでした
settings-plugins-scan-failed = プラグインのスキャンに失敗しました
settings-plugins-cancel-failed = プラグインのスキャンをキャンセルできませんでした

## Logs

settings-logs-description = このビューアーには Flutter アプリのログと Rust オーディオエンジンのログが表示されます。各エントリには出力元のラベルが付いています。
settings-logs-capture-level = 記録レベル
settings-logs-retained = 保持するエントリ数
settings-logs-search = ログを検索
settings-logs-display-level = 表示レベル
settings-logs-source = 出力元
settings-logs-source-all = すべて
settings-logs-resume = 表示を再開
settings-logs-pause = 表示を一時停止
settings-logs-copy = 絞り込み結果をコピー
settings-logs-export = 絞り込み結果を書き出し
settings-logs-count = { $shown } 件を表示 • { $captured }/{ $maximum } 件を記録{ $paused ->
    [yes] {" "}• 表示を一時停止中
   *[no] {""}
}
settings-logs-empty = 一致するログはありません。
settings-logs-copy-failed = ログをコピーできませんでした
settings-logs-copied = 絞り込んだログをコピーしました
settings-logs-export-failed = ログを書き出せませんでした
settings-logs-exported = ログを { $path } に書き出しました
settings-logs-export-dialog = { -app-name } のログを書き出す
settings-logs-clear-title = 記録したログを消去しますか？
settings-logs-clear-message = メモリ上のビューアーからすべてのエントリを削除します。
settings-logs-clear-confirm = ログを消去
settings-logs-load-failed = ログの設定を読み込めませんでした
settings-logs-not-saved = ログの設定は適用されましたが保存されていません

## Info

settings-info-description = { -app-name } は Flutter と Rust で作られたクロスプラットフォームのデジタルオーディオワークステーションです。
settings-info-application = アプリケーション
settings-info-version-unavailable = バージョン情報を取得できません。
settings-info-name = 名前
settings-info-version = バージョン
settings-info-report-bug = 不具合を報告
settings-info-report-bug-help = { -app-name } のバージョン、OS、再現手順、期待した結果、実際の結果、関連するログを含めてください。
settings-info-copy-url = 不具合報告の URL をコピー
settings-info-copy-url-failed = URL をコピーできませんでした
settings-info-url-copied = 不具合報告の URL をコピーしました

## Cover art and file dialogs

settings-cover-crop-title = カバーを切り抜く
settings-cover-crop-help = ドラッグで移動、スクロールまたはピンチで拡大縮小
settings-cover-crop-use = この画像を使う
settings-project-cover-dialog = カバー画像を選択
settings-audio-metronome-dialog = メトロノームの音を選択
settings-audio-metronome-setting-load-failed = メトロノームの音の設定を読み込めませんでした
settings-audio-metronome-unavailable-title = メトロノームの音を使用できません
settings-audio-metronome-unavailable-message = 保存されたメトロノームの音を使用できません。既定のクリックを使用しています。
settings-audio-metronome-choose-failed = メトロノームの音を選択できませんでした
settings-audio-metronome-load-failed = メトロノームの音を読み込めませんでした
settings-audio-metronome-restore-failed = 既定のメトロノームの音に戻せませんでした
settings-audio-metronome-not-saved = メトロノームの音は変更されましたが保存されていません
settings-appearance-background-dialog = ワークスペースの背景を選択
settings-appearance-font-dialog = アプリのフォントを選択
settings-appearance-theme-dialog = カラーテーマを選択
settings-appearance-theme-too-large = カラーテーマファイルが 1 MB を超えています

## Color theme files

settings-theme-invalid = 無効なカラーテーマ：
settings-theme-invalid-json = このファイルは有効な JSON ではありません：{ $reason }
settings-theme-not-object = テーマは JSON オブジェクトである必要があります。
settings-theme-unknown-field = 不明なフィールド "{ $field }" があります。
settings-theme-missing-field = "{ $field }" がありません。
settings-theme-colors-not-object = "colors" はカラーロールのオブジェクトである必要があります。
settings-theme-name-not-text = "name" はテキストである必要があります。
settings-theme-name-empty = "name" を空にすることはできません。
settings-theme-name-too-long = "name" は { $maximum } 文字以内にしてください。
settings-theme-brightness-invalid = "brightness" は "light" または "dark" である必要があります。
settings-theme-missing-color = 必須の色 "{ $role }" がありません。
settings-theme-color-invalid = 色 "{ $role }" は "#RRGGBB" または "#RRGGBBAA" の形式で書いてください。
settings-theme-unknown-color = 不明な色 "{ $role }" があります。
