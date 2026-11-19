## Language

settings-language-title = 언어
settings-language-field = 앱 언어
settings-language-system = 시스템 기본값 ({ $language })
settings-language-help = 메뉴, 대화 상자, 메시지의 언어를 바꿉니다. 플러그인 매개변수 이름은 플러그인이 정한 이름을 그대로 사용합니다.
settings-language-change-title = 언어를 바꾸시겠습니까?
settings-language-change-warning = 앱 언어를 바꾸려고 합니다. 번역 속에서 길을 잃지 않도록 이 메뉴의 위치를 기억해 두세요. 정말 언어를 바꾸시겠습니까?
settings-language-change-confirm = 언어 바꾸기
settings-language-change-failed = 언어를 바꿀 수 없습니다
settings-language-load-failed = 언어 설정을 불러올 수 없습니다

## Settings screen

settings-title = 설정
settings-close = 설정 닫기
settings-page-placeholder = 이 설정 페이지는 이후 단계에서 구현될 예정입니다.
settings-menu-general = 일반
settings-menu-general-description = 실행 취소 기록 보관 등 앱 전체 동작을 설정합니다.
settings-menu-host-devices = 호스트 및 장치
settings-menu-host-devices-description = 오디오 호스트와 출력 장치를 선택합니다. 입력 장치는 아직 지원되지 않습니다.
settings-menu-project = 프로젝트
settings-menu-project-description = 현재 프로젝트와 함께 저장되는 메타데이터를 편집합니다.
settings-menu-appearance = 모양
settings-menu-appearance-description = 앱의 테마, 색상, 배경, 글꼴을 원하는 대로 바꿉니다.
settings-menu-audio = 오디오
settings-menu-audio-description = DSP 처리의 샘플 레이트와 블록 크기를 설정합니다.
settings-menu-key-bindings = 단축키
settings-menu-key-bindings-description = 앱의 키보드 단축키를 확인하고 변경합니다.
settings-menu-plugins = 플러그인
settings-menu-plugins-description = 서드파티 플러그인 검색 및 호스팅 설정입니다.
settings-menu-logs = 로그
settings-menu-logs-description = 진단을 설정하고 최근 앱 로그를 살펴봅니다.
settings-menu-info = 정보
settings-menu-info-description = 앱 버전, 라이선스, 버그 신고 정보를 확인합니다.

## General

settings-general-history-limit = 최대 실행 취소 기록 수
settings-general-history-entries = { $count }개
settings-general-history-help = 값이 낮을수록 메모리를 적게 사용합니다. 한도를 줄이면 가장 오래된 실행 취소 및 다시 실행 기록이 즉시 삭제됩니다. 사용 안 함을 선택하면 두 기록이 모두 지워집니다.
settings-general-auto-save = 자동 저장
settings-general-auto-save-enable = 자동 저장 사용
settings-general-auto-save-interval = 자동 저장 간격
settings-general-auto-save-help = 자동 저장은 저장하지 않은 변경 사항의 복구용 사본을 기록합니다. 프로젝트 파일을 덮어쓰지 않으며, 비정상 종료 후에는 다음 실행 시 { -app-name }이(가) 사본 복원을 제안합니다.
settings-general-interval-seconds = { $count }초
settings-general-interval-minutes = { $count }분
settings-general-folders = 폴더
settings-general-project-folder = 기본 프로젝트 폴더
settings-general-project-folder-unset = 설정되지 않았습니다. 저장 및 열기 대화 상자는 시스템이 정한 위치에서 시작합니다.
settings-general-project-folder-choose = 기본 프로젝트 폴더 선택
settings-general-export-folder = 기본 내보내기 폴더
settings-general-export-folder-unset = 설정되지 않았습니다. 내보낼 때마다 폴더를 선택합니다.
settings-general-export-folder-choose = 기본 내보내기 폴더 선택
settings-general-folder-missing = 이 폴더가 더 이상 없으므로 사용되지 않습니다.
settings-general-recent-projects = 최근 프로젝트
settings-general-recent-projects-show = 최근 프로젝트 표시
settings-general-recent-projects-help = 프로젝트 메뉴의 최근 항목 열기에 최근에 연 프로젝트를 표시합니다. 숨겨도 목록은 유지됩니다.
settings-general-load-failed = 설정을 불러올 수 없습니다
settings-general-history-apply-failed = 기록 한도를 적용할 수 없습니다
settings-general-history-update-failed = 기록 한도를 업데이트할 수 없습니다
settings-general-history-not-saved = 기록 한도가 적용되었지만 저장되지 않았습니다
settings-general-auto-save-load-failed = 자동 저장 설정을 불러올 수 없습니다
settings-general-auto-save-apply-failed = 자동 저장 설정을 적용할 수 없습니다
settings-general-auto-save-update-failed = 자동 저장을 업데이트할 수 없습니다
settings-general-auto-save-not-saved = 자동 저장이 적용되었지만 저장되지 않았습니다
settings-general-folder-choose-failed = 폴더를 선택할 수 없습니다
settings-general-folder-save-failed = 폴더를 저장할 수 없습니다
settings-general-recent-projects-save-failed = 최근 프로젝트 설정을 저장할 수 없습니다

## Audio

settings-audio-description = DSP 설정은 전용 처리 워커를 제어합니다. 장치 스트림 값은 읽기 전용이며 달라도 문제없습니다.
settings-audio-sample-rate = DSP 샘플 레이트
settings-audio-hertz = { $value } Hz
settings-audio-block-size = DSP 블록 크기
settings-audio-frames = { $count } 프레임
settings-audio-block-latency = DSP 블록 하나는 약 { $milliseconds } ms에 해당합니다. 블록이 작을수록 처리 지연은 줄지만 CPU 스케줄링 부담은 커집니다.
settings-audio-applying = 적용 중…
settings-audio-revert = 되돌리기
settings-audio-metronome = 메트로놈 소리
settings-audio-metronome-default = 기본 클릭
settings-audio-metronome-choose = 소리 선택
settings-audio-metronome-use-default = 기본값 사용
settings-audio-metronome-help = 선택한 소리는 약박에서는 녹음된 그대로, 첫 박에서는 한 옥타브 높게 재생됩니다. 각 박은 이전 박의 남은 소리를 끊습니다.
settings-audio-device-stream = 장치 스트림 (읽기 전용)
settings-audio-device-stream-starting = 활성 장치 스트림을 시작하는 중입니다.
settings-audio-device-output = 출력: { $device }
settings-audio-device-sample-rate = 장치 샘플 레이트: { $value } Hz
settings-audio-device-buffer = 장치 콜백 버퍼: { $count } 프레임
settings-audio-device-channels = 채널: { $count }
settings-audio-reset-title = DSP 설정 재설정됨
settings-audio-reset-message = 지원되지 않는 저장된 DSP 값을 기본값으로 되돌렸습니다.
settings-audio-initialize-failed = DSP 설정을 초기화할 수 없습니다
settings-audio-apply-failed = DSP 설정을 적용할 수 없습니다
settings-audio-not-saved = DSP 설정이 적용되었지만 저장되지 않았습니다

## Host & Devices

settings-host-description = 오디오를 재생할 곳과 오디오 트랙이 녹음할 장치를 선택합니다.
settings-host-audio-host = 오디오 호스트
settings-host-system-default = 시스템 기본값
settings-host-output-device = 출력 장치
settings-host-system-default-output = 시스템 기본 출력
settings-host-current-default = { $device } (현재 기본값)
settings-host-audio-input = 오디오 입력
settings-host-input-enable = 오디오 입력 사용
settings-host-input-help = 오디오 트랙이 입력 장치를 녹음하고 모니터링할 수 있게 합니다. 트랙을 녹음 대기 상태로 만들면 켜집니다.
settings-host-input-device = 입력 장치
settings-host-system-default-input = 시스템 기본 입력
settings-host-input-retry = 입력 장치 다시 찾기
settings-host-stream-summary = { $device } · { $rate } Hz · { $channels }채널
settings-host-retry = 다시 찾기
settings-host-fallback-active = { $reason } 시스템 기본 출력을 사용 중입니다.
settings-host-active-stream = 활성 장치 스트림
settings-host-active-stream-summary = { $rate } Hz · { $frames } 프레임 · { $channels }채널
settings-host-output-load-failed = 출력 설정을 불러올 수 없습니다
settings-host-input-load-failed = 입력 설정을 불러올 수 없습니다
settings-host-discover-hosts-failed = 오디오 호스트를 찾을 수 없습니다
settings-host-saved-host-unavailable = 저장된 오디오 호스트를 사용할 수 없습니다.
settings-host-saved-output-unavailable = 저장된 출력 장치를 사용할 수 없습니다.
settings-host-output-fallback-title = 대체 오디오 출력
settings-host-output-fallback-message = { $reason } 시스템 기본 출력을 사용합니다.
settings-host-input-enabled-not-saved = 오디오 입력이 켜졌지만 저장되지 않았습니다
settings-host-input-fallback-title = 대체 오디오 입력
settings-host-input-fallback-message = 저장된 입력 장치를 사용할 수 없습니다. 시스템 기본 입력을 사용합니다.
settings-host-input-change-failed = 오디오 입력을 변경할 수 없습니다
settings-host-input-not-saved = 오디오 입력이 변경되었지만 저장되지 않았습니다
settings-host-discover-outputs-failed = 출력 장치를 찾을 수 없습니다
settings-host-output-change-failed = 오디오 출력을 변경할 수 없습니다
settings-host-output-not-saved = 오디오 출력이 변경되었지만 저장되지 않았습니다

## Project

settings-project-image-open-failed = 이미지를 열 수 없습니다
settings-project-cover-save-failed = 커버를 저장할 수 없습니다
settings-project-updated = 프로젝트 정보가 업데이트되었습니다
settings-project-title = 제목
settings-project-title-required = 제목은 필수입니다
settings-project-author = 작성자
settings-project-author-help = 여러 아티스트는 ;로 구분하세요
settings-project-genre = 장르
settings-project-version = 프로젝트 버전
settings-project-description = 설명
settings-project-created-at = 생성 일시
settings-project-saving = 저장 중…
settings-project-save = 프로젝트 정보 저장
settings-project-cover = 커버 아트
settings-project-cover-help = 내보낸 오디오에 포함되는 정사각형 이미지
settings-project-cover-choose = 이미지 선택…
settings-project-cover-replace = 바꾸기…
settings-project-changed-banner = 이 양식에 저장하지 않은 수정 사항이 있는 동안 현재 프로젝트가 변경되었습니다.
settings-project-keep-edits = 수정 사항 유지
settings-project-reload = 프로젝트 다시 불러오기

## Appearance

settings-appearance-color-theme = 색상 테마
settings-appearance-load-theme = JSON 테마 불러오기
settings-appearance-color-theme-help = 선택한 색상 테마는 자체 밝기와 색상을 정합니다. 테마 모드와 강조 팔레트를 사용하려면 기본값을 선택하세요.
settings-appearance-theme-mode = 테마 모드
settings-appearance-mode-system = 시스템
settings-appearance-mode-light = 밝게
settings-appearance-mode-dark = 어둡게
settings-appearance-accent = 강조 팔레트
settings-appearance-background = 작업 공간 배경
settings-appearance-background-default = 기본 배경
settings-appearance-background-choose = 이미지 선택
settings-appearance-background-fit = 이미지 맞춤
settings-appearance-overlay = 어두운 오버레이: { $percent }%
settings-appearance-font = 앱 글꼴
settings-appearance-font-system = 시스템 글꼴
settings-appearance-font-choose = TTF 또는 OTF 선택
settings-appearance-font-use-system = 시스템 글꼴 사용
settings-appearance-assets-help = 사용자 지정 파일은 원래 위치에 그대로 있습니다. 파일이 이동되거나 삭제되면 { -app-name }이(가) 안전하게 기본값으로 되돌립니다.
settings-appearance-theme = 테마
settings-appearance-theme-remove = 테마 제거
settings-appearance-theme-remove-title = 색상 테마를 제거하시겠습니까?
settings-appearance-theme-remove-message = “{ $name }” 테마가 테마 메뉴에서 제거됩니다.{ $active ->
    [yes] {" "}현재 사용 중인 테마이므로 { -app-name }은(는) 기본 테마로 돌아갑니다.
   *[no] {""}
}

    파일 { $file }은(는) 삭제되지 않습니다. JSON 테마 불러오기로 다시 불러올 수 있습니다.
settings-appearance-palette-purple = 보라
settings-appearance-palette-blue = 파랑
settings-appearance-palette-teal = 청록
settings-appearance-palette-orange = 주황
settings-appearance-palette-red = 빨강
settings-appearance-palette-green = 초록
settings-appearance-palette-pink = 분홍
settings-appearance-palette-cyan = 시안
settings-appearance-palette-indigo = 남색
settings-appearance-palette-amber = 호박색
settings-appearance-palette-lime = 라임
settings-appearance-palette-magenta = 마젠타
settings-appearance-palette-graphite = 그래파이트
settings-appearance-fit-cover = 채우기(잘림)
settings-appearance-fit-contain = 맞추기
settings-appearance-fit-fill = 늘이기
settings-appearance-load-failed = 모양 설정을 불러올 수 없습니다
settings-appearance-background-unavailable-title = 배경 이미지를 사용할 수 없음
settings-appearance-background-unavailable-message = 저장된 배경 이미지를 사용할 수 없습니다. 기본 배경을 사용합니다.
settings-appearance-font-unavailable-title = 사용자 지정 글꼴을 사용할 수 없음
settings-appearance-font-unavailable-message = 저장된 사용자 지정 글꼴을 사용할 수 없습니다. 시스템 글꼴을 사용합니다.
settings-appearance-theme-unavailable-title = 색상 테마를 사용할 수 없음
settings-appearance-theme-unavailable-message = 저장된 색상 테마 파일 { $count }개를 사용할 수 없거나 더 이상 유효하지 않아 테마 메뉴에서 제거했습니다.
settings-appearance-theme-apply-failed = 색상 테마를 적용할 수 없습니다
settings-appearance-theme-choose-failed = 색상 테마를 선택할 수 없습니다
settings-appearance-theme-load-failed = 색상 테마를 불러올 수 없습니다
settings-appearance-theme-remove-failed = 색상 테마를 제거할 수 없습니다
settings-appearance-background-choose-failed = 배경 이미지를 선택할 수 없습니다
settings-appearance-font-choose-failed = 글꼴을 선택할 수 없습니다
settings-appearance-font-load-failed = 글꼴을 불러올 수 없습니다
settings-appearance-not-saved = 모양이 변경되었지만 저장되지 않았습니다

## Key bindings

settings-keys-search = 명령 검색
settings-keys-reset-all = 모두 재설정
settings-keys-no-match = 검색과 일치하는 명령이 없습니다.
settings-keys-capture-hint = { $hint } Esc를 누르면 입력이 취소됩니다.
settings-keys-reset-all-title = 모든 단축키를 재설정하시겠습니까?
settings-keys-reset-all-message = 모든 명령이 기본 키 조합으로 돌아갑니다.
settings-keys-default = 기본값: { $chord }
settings-keys-reset = { $command } 재설정
settings-keys-change = 변경
settings-keys-change-title = { $command } 변경
settings-keys-press = 새 단축키를 누르세요

## Plugins

settings-plugins-description = { -app-name }은(는) 시작할 때 캐시된 카탈로그를 불러옵니다. 검사는 요청할 때만 실행되며 각 플러그인을 격리된 도우미 프로세스에서 확인합니다.
settings-plugins-additional-folders = 추가 검사 폴더
settings-plugins-no-additional-folders = 설정된 추가 폴더가 없습니다.
settings-plugins-add-folder = 폴더 추가
settings-plugins-system-folders = 시스템 검사 폴더
settings-plugins-no-system-folders = 이 플랫폼에는 사용할 수 있는 표준 폴더가 없습니다.
settings-plugins-timeout = 플러그인별 제한 시간
settings-plugins-scanning = 검사 중…
settings-plugins-scan-now = 지금 검사
settings-plugins-cancelling = 취소 중…
settings-plugins-cancel-scan = 검사 취소
settings-plugins-retry-failed = 실패/격리된 플러그인 다시 시도
settings-plugins-preparing = 검사 준비 중…
settings-plugins-progress = 모듈 { $total }개 중 { $completed }개 · 플러그인 { $count }개 발견
settings-plugins-scan-cancelled = 검사를 취소했습니다. 플러그인 { $count }개를 유지했습니다.
settings-plugins-scan-complete = 검사를 완료했습니다. 플러그인 { $count }개를 찾았습니다.
settings-plugins-failures = 검사 실패 { $count }건
settings-plugins-external-catalog = 외부 카탈로그
settings-plugins-catalog-summary = 사용 가능 { $available }개, 사용 불가 { $unavailable }개
settings-plugins-remove-folder = 폴더 제거
settings-plugins-folder-choose = 플러그인 폴더 선택
settings-plugins-initialize-failed = 플러그인 설정을 초기화할 수 없습니다
settings-plugins-folder-choose-failed = 플러그인 폴더를 선택할 수 없습니다
settings-plugins-save-failed = 플러그인 설정을 저장할 수 없습니다
settings-plugins-scan-failed = 플러그인 검사 실패
settings-plugins-cancel-failed = 플러그인 검사를 취소할 수 없습니다

## Logs

settings-logs-description = 이 뷰어에는 Flutter 앱 로그와 Rust 오디오 엔진 로그가 표시됩니다. 각 항목에는 출처가 표시됩니다.
settings-logs-capture-level = 기록 수준
settings-logs-retained = 보관 항목 수
settings-logs-search = 로그 검색
settings-logs-display-level = 표시 수준
settings-logs-source = 출처
settings-logs-source-all = 전체
settings-logs-resume = 표시 다시 시작
settings-logs-pause = 표시 일시 중지
settings-logs-copy = 필터 결과 복사
settings-logs-export = 필터 결과 내보내기
settings-logs-count = { $shown }개 표시 • { $captured }/{ $maximum }개 기록{ $paused ->
    [yes] {" "}• 표시 일시 중지됨
   *[no] {""}
}
settings-logs-empty = 일치하는 로그 항목이 없습니다.
settings-logs-copy-failed = 로그를 복사할 수 없습니다
settings-logs-copied = 필터링된 로그를 복사했습니다
settings-logs-export-failed = 로그를 내보낼 수 없습니다
settings-logs-exported = 로그를 { $path }(으)로 내보냈습니다
settings-logs-export-dialog = { -app-name } 로그 내보내기
settings-logs-clear-title = 기록된 로그를 지우시겠습니까?
settings-logs-clear-message = 메모리의 뷰어에서 모든 항목이 제거됩니다.
settings-logs-clear-confirm = 로그 지우기
settings-logs-load-failed = 로그 설정을 불러올 수 없습니다
settings-logs-not-saved = 로그 설정이 적용되었지만 저장되지 않았습니다

## Info

settings-info-description = { -app-name }은(는) Flutter와 Rust로 만든 크로스 플랫폼 디지털 오디오 워크스테이션입니다.
settings-info-application = 애플리케이션
settings-info-version-unavailable = 버전 정보를 사용할 수 없습니다.
settings-info-name = 이름
settings-info-version = 버전
settings-info-report-bug = 버그 신고
settings-info-report-bug-help = { -app-name } 버전, 운영 체제, 재현 단계, 기대한 결과, 실제 결과, 관련 로그를 포함해 주세요.
settings-info-copy-url = 버그 신고 URL 복사
settings-info-copy-url-failed = URL을 복사할 수 없습니다
settings-info-url-copied = 버그 신고 URL을 복사했습니다

## Cover art and file dialogs

settings-cover-crop-title = 커버 자르기
settings-cover-crop-help = 드래그해 이동하고, 스크롤하거나 손가락을 오므려 확대/축소하세요
settings-cover-crop-use = 이미지 사용
settings-project-cover-dialog = 커버 이미지 선택
settings-audio-metronome-dialog = 메트로놈 소리 선택
settings-audio-metronome-setting-load-failed = 메트로놈 소리 설정을 불러올 수 없습니다
settings-audio-metronome-unavailable-title = 메트로놈 소리를 사용할 수 없음
settings-audio-metronome-unavailable-message = 저장된 메트로놈 소리를 사용할 수 없습니다. 기본 클릭을 사용합니다.
settings-audio-metronome-choose-failed = 메트로놈 소리를 선택할 수 없습니다
settings-audio-metronome-load-failed = 메트로놈 소리를 불러올 수 없습니다
settings-audio-metronome-restore-failed = 기본 메트로놈 소리로 되돌릴 수 없습니다
settings-audio-metronome-not-saved = 메트로놈 소리가 변경되었지만 저장되지 않았습니다
settings-appearance-background-dialog = 작업 공간 배경 선택
settings-appearance-font-dialog = 앱 글꼴 선택
settings-appearance-theme-dialog = 색상 테마 선택
settings-appearance-theme-too-large = 색상 테마 파일이 1 MB보다 큽니다

## Color theme files

settings-theme-invalid = 잘못된 색상 테마:
settings-theme-invalid-json = 이 파일은 올바른 JSON이 아닙니다: { $reason }
settings-theme-not-object = 테마는 JSON 객체여야 합니다.
settings-theme-unknown-field = 알 수 없는 필드 "{ $field }"입니다.
settings-theme-missing-field = "{ $field }"이(가) 없습니다.
settings-theme-colors-not-object = "colors"는 색상 역할 객체여야 합니다.
settings-theme-name-not-text = "name"은 텍스트여야 합니다.
settings-theme-name-empty = "name"은 비워 둘 수 없습니다.
settings-theme-name-too-long = "name"은 최대 { $maximum }자까지 가능합니다.
settings-theme-brightness-invalid = "brightness"는 "light" 또는 "dark"여야 합니다.
settings-theme-missing-color = 필수 색상 "{ $role }"이(가) 없습니다.
settings-theme-color-invalid = 색상 "{ $role }"은(는) "#RRGGBB" 또는 "#RRGGBBAA" 형식으로 작성해야 합니다.
settings-theme-unknown-color = 알 수 없는 색상 "{ $role }"입니다.
