## Startup

app-settings-reset-title = 설정 재설정됨
app-settings-reset-message = { $file }의 설정을 읽을 수 없습니다({ $reason }). 기본값을 사용하며, 이전 파일은 { $backup }(으)로 보관했습니다.

## Crash recovery

app-crash-recovery-unavailable = 비정상 종료 복구를 사용할 수 없습니다
app-crash-discard-failed = 복구된 프로젝트를 버릴 수 없습니다
app-crash-report-export-failed = 보고서를 내보낼 수 없습니다
app-crash-report-saved = 보고서 저장됨
app-crash-report-exported = 충돌 보고서를 { $path }(으)로 내보냈습니다
app-crash-reports-delete-failed = 충돌 보고서를 삭제할 수 없습니다

## Timeline

app-timeline-loop-set-failed = 루프 구간을 설정할 수 없습니다
app-timeline-loop-clear-failed = 루프 구간을 지울 수 없습니다
app-timeline-cue-add-failed = 큐 마커를 추가할 수 없습니다
app-timeline-cue-remove-failed = 큐 마커를 제거할 수 없습니다
app-timeline-cue-edit-failed = 큐 마커를 편집할 수 없습니다
app-timeline-bounce-failed = 루프 구간을 바운스할 수 없습니다
app-timeline-bounced-title = 새 소스로 바운스됨
app-timeline-bounced-message = 루프 구간이 이제 소스 목록에 있습니다.

## Background work

app-job-cancelled = 백그라운드 작업 { $id }이(가) 취소되었습니다.
app-job-failed = 백그라운드 작업 실패
app-blocking-timeout-title = 작업 시간 초과
app-blocking-timeout-message = “{ $task }” 작업이 { $seconds }초 안에 끝나지 않아 해제되었습니다. 작업은 백그라운드에서 계속됩니다.
app-blocking-cancelled = “{ $task }” 작업이 시작되기 전에 취소되었습니다.
app-blocking-failed = 작업 실패

## Recording

app-recording-arm-failed = 트랙을 녹음 대기 상태로 만들 수 없습니다
app-recording-input-on-title = 오디오 입력 켜짐
app-recording-input-on-message = 오디오 입력이 꺼져 있어서 켰습니다. 입력 장치는 설정에서 바꿀 수 있습니다.
app-recording-nothing-title = 녹음할 대상 없음
app-recording-nothing-message = 녹음할 오디오 트랙을 선택하세요.
app-recording-save-failed = 녹음을 저장할 수 없습니다
app-recordings-save-failed = 녹음들을 저장할 수 없습니다

## Project

app-project-recover-failed = 프로젝트를 복구할 수 없습니다
app-project-audio-load-failed = 오디오를 불러올 수 없습니다
app-project-source-delete-failed = 오디오 소스를 삭제할 수 없습니다
app-project-pattern-delete-failed = 패턴을 삭제할 수 없습니다
app-project-info-update-failed = 프로젝트 정보를 업데이트할 수 없습니다
app-project-undo-failed = 실행 취소할 수 없습니다
app-project-redo-failed = 다시 실행할 수 없습니다
app-project-refresh-failed = { $action }: 프로젝트를 새로 고치지 못했습니다
app-project-instrument-rename-failed = 악기 이름을 바꿀 수 없습니다
app-project-trim-failed = 오디오를 자를 수 없습니다
app-project-envelope-edit-failed = 파형 엔벨로프를 편집할 수 없습니다
app-project-saved-title = 프로젝트 저장됨
app-project-saved-message = 프로젝트를 { $path }에 저장했습니다

## Automation targets

app-automation-missing-effect = 없는 이펙트
app-automation-sampler = 샘플러
app-automation-missing-instrument = 없는 악기
app-automation-track = 트랙
app-automation-bus = 버스
app-automation-master = 마스터
app-automation-transport = 트랜스포트
app-automation-other-group = 기타

## Tracks

app-tracks-input-change-failed = 트랙 입력을 바꿀 수 없습니다
app-tracks-samples-audio-only = 오디오 샘플은 오디오 트랙에만 놓을 수 있습니다
app-tracks-move-type-mismatch = { $source ->
    [audio] 오디오
    [midi] MIDI
   *[automation] 오토메이션
} 클립은 { $target ->
    [audio] 오디오
    [midi] MIDI
   *[automation] 오토메이션
} 트랙으로 옮길 수 없습니다

## Mixer channel templates

app-mixer-template-save-failed = 채널 템플릿을 저장할 수 없습니다
app-mixer-template-saved = 채널 템플릿을 { $path }에 저장했습니다
app-mixer-template-load-failed = 채널 템플릿을 불러올 수 없습니다
app-mixer-template-loaded = 채널 템플릿을 불러왔습니다
app-mixer-template-skipped = 사용할 수 없는 플러그인을 건너뛰었습니다: { $plugins }

## Menu bar

app-menu-project = 프로젝트
app-menu-new-project = 새 프로젝트
app-menu-open-project = 프로젝트 열기
app-menu-open-recent = 최근 항목 열기
app-menu-save-project = 프로젝트 저장
app-menu-save-as = 다른 이름으로 저장...
app-menu-import-audio = 오디오 가져오기
app-menu-export-project = 프로젝트 내보내기
app-menu-settings = 설정
app-menu-quit = { -app-name } 종료
app-menu-edit = 편집
app-menu-undo = 실행 취소
app-menu-redo = 다시 실행
app-menu-view = 보기
app-menu-zoom-in = 확대
app-menu-zoom-out = 축소
