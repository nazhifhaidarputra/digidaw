use std::{
    path::{Path, PathBuf},
    sync::{Once, OnceLock},
};

use jiff::Timestamp;
use serde::{Deserialize, Serialize};

use super::{
    MitigationError,
    auto_save::{remove_if_exists, write_json_atomically},
    device::UserDevice,
};

/// Number of reports kept on disk; older ones are pruned after every write.
pub const MAX_STORED_CRASH_REPORTS: usize = 20;

/// Crash detected on the Rust side. Codes are documented in `docs/CODE_ERROR_GUIDE.md`.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub enum RustCrashSource {
    /// A Rust panic on any thread (code 1001).
    Panic {
        /// Name of the panicking thread, or `<unnamed>`.
        thread: String,
        /// Panic payload text.
        message: String,
        /// `file:line:column` of the panic, when known.
        location: Option<String>,
        /// Captured backtrace, when available.
        backtrace: Option<String>,
    },
    /// The previous session ended without a clean shutdown (code 1002). No hook observed it:
    /// typically a native plugin crash, a kill, or a power loss.
    UncleanShutdown,
}

impl RustCrashSource {
    /// Stable numeric code.
    pub fn code(&self) -> u16 {
        match self {
            Self::Panic { .. } => 1001,
            Self::UncleanShutdown => 1002,
        }
    }

    fn summary(&self) -> String {
        match self {
            Self::Panic {
                thread,
                message,
                location,
                ..
            } => match location {
                Some(location) => format!("Panic on thread '{thread}' at {location}: {message}"),
                None => format!("Panic on thread '{thread}': {message}"),
            },
            Self::UncleanShutdown => "The previous session did not shut down cleanly".into(),
        }
    }
}

/// Crash reported by the Flutter side. Codes are documented in `docs/CODE_ERROR_GUIDE.md`.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub enum FlutterCrashSource {
    /// An error caught by `FlutterError.onError`, such as a build or layout failure (code 2001).
    FrameworkError {
        /// Flutter library that reported the error.
        library: Option<String>,
        /// Error text.
        message: String,
        /// Dart stack trace.
        stack: Option<String>,
    },
    /// An uncaught asynchronous error caught by `PlatformDispatcher.onError` (code 2002).
    UncaughtAsync {
        /// Error text.
        message: String,
        /// Dart stack trace.
        stack: Option<String>,
    },
}

impl FlutterCrashSource {
    /// Stable numeric code.
    pub fn code(&self) -> u16 {
        match self {
            Self::FrameworkError { .. } => 2001,
            Self::UncaughtAsync { .. } => 2002,
        }
    }

    fn summary(&self) -> String {
        match self {
            Self::FrameworkError {
                library: Some(library),
                message,
                ..
            } => format!("Flutter error in {library}: {message}"),
            Self::FrameworkError { message, .. } => format!("Flutter error: {message}"),
            Self::UncaughtAsync { message, .. } => format!("Uncaught async error: {message}"),
        }
    }
}

/// Define the `CrashSource`.
///
/// Every code will have a error code:
///
/// This code will references from `CODE_ERROR_GUIDE.md` to define
/// which error code means
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub enum CrashSource {
    /// Crash raised by the Flutter UI.
    Flutter(FlutterCrashSource),
    /// Crash raised by, or detected in, the Rust engine.
    Rust(RustCrashSource),
}

impl CrashSource {
    /// Stable numeric code listed in `docs/CODE_ERROR_GUIDE.md`.
    pub fn code(&self) -> u16 {
        match self {
            Self::Flutter(source) => source.code(),
            Self::Rust(source) => source.code(),
        }
    }

    /// One-line human-readable description.
    pub fn summary(&self) -> String {
        match self {
            Self::Flutter(source) => source.summary(),
            Self::Rust(source) => source.summary(),
        }
    }
}

/// One crash, as written to disk.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct CrashReport {
    /// When the crash is happening. stored in timestamp type
    pub when: jiff::Timestamp,
    /// Stable code of `source`, duplicated for readers of the raw JSON.
    pub code: u16,
    /// What crashed.
    pub source: CrashSource,
    /// To know which device the user use, from CPU, GPU, RAM, OS, etc.
    /// Will be useful to know the crash cause
    pub device: UserDevice,
    /// Application version that produced the report.
    pub app_version: String,
}

/// A report loaded from the store, with the identifier used to remove or export it.
#[derive(Clone, Debug, PartialEq)]
pub struct StoredCrashReport {
    /// File stem of the report inside the crash directory.
    pub id: String,
    /// Decoded report.
    pub report: CrashReport,
}

/// Directory of JSON crash reports, newest [`MAX_STORED_CRASH_REPORTS`] kept.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CrashStore {
    dir: PathBuf,
}

impl CrashStore {
    const PREFIX: &'static str = "crash-";
    const EXTENSION: &'static str = "json";

    /// Creates the directory when missing.
    pub fn open(dir: impl Into<PathBuf>) -> Result<Self, MitigationError> {
        let dir = dir.into();
        std::fs::create_dir_all(&dir)?;
        Ok(Self { dir })
    }

    /// Writes `report`, prunes old reports, and returns the new report's identifier.
    pub fn write(&self, report: &CrashReport) -> Result<String, MitigationError> {
        let id = format!(
            "{}{}-{}",
            Self::PREFIX,
            report.when.as_nanosecond(),
            report.code
        );
        write_json_atomically(&self.report_path(&id)?, report)?;
        self.prune(MAX_STORED_CRASH_REPORTS)?;
        Ok(id)
    }

    /// Lists readable reports, newest first. Unreadable files are logged and skipped.
    pub fn list(&self) -> Result<Vec<StoredCrashReport>, MitigationError> {
        let mut reports = Vec::new();
        for entry in std::fs::read_dir(&self.dir)? {
            let path = entry?.path();
            let Some(id) = Self::report_id(&path) else {
                continue;
            };
            match std::fs::read(&path)
                .map_err(MitigationError::from)
                .and_then(|bytes| Ok(serde_json::from_slice::<CrashReport>(&bytes)?))
            {
                Ok(report) => reports.push(StoredCrashReport { id, report }),
                Err(error) => log::warn!(
                    "Skipping unreadable crash report {}: {error}",
                    path.display()
                ),
            }
        }
        reports.sort_by_key(|stored| std::cmp::Reverse(stored.report.when));
        Ok(reports)
    }

    /// Deletes one report.
    pub fn remove(&self, id: &str) -> Result<(), MitigationError> {
        remove_if_exists(&self.report_path(id)?)
    }

    /// Copies one report's JSON to `destination`.
    pub fn export(&self, id: &str, destination: &Path) -> Result<(), MitigationError> {
        std::fs::copy(self.report_path(id)?, destination)?;
        Ok(())
    }

    fn prune(&self, keep: usize) -> Result<(), MitigationError> {
        for stale in self.list()?.into_iter().skip(keep) {
            self.remove(&stale.id)?;
        }
        Ok(())
    }

    fn report_path(&self, id: &str) -> Result<PathBuf, MitigationError> {
        let valid = id.starts_with(Self::PREFIX)
            && id.len() > Self::PREFIX.len()
            && id.chars().all(|c| c.is_ascii_alphanumeric() || c == '-');
        if !valid {
            return Err(MitigationError::InvalidReportId(id.to_owned()));
        }
        Ok(self.dir.join(format!("{id}.{}", Self::EXTENSION)))
    }

    fn report_id(path: &Path) -> Option<String> {
        if path.extension()? != Self::EXTENSION {
            return None;
        }
        let stem = path.file_stem()?.to_str()?;
        stem.starts_with(Self::PREFIX).then(|| stem.to_owned())
    }
}

/// Writes reports with the device description and version captured at configuration time, so
/// recording from the panic hook does no hardware probing.
#[derive(Clone, Debug)]
pub struct CrashReporter {
    store: CrashStore,
    device: UserDevice,
    app_version: String,
}

impl CrashReporter {
    /// Creates a reporter that writes into `store`.
    pub fn new(store: CrashStore, device: UserDevice, app_version: impl Into<String>) -> Self {
        Self {
            store,
            device,
            app_version: app_version.into(),
        }
    }

    /// Store backing this reporter.
    pub fn store(&self) -> &CrashStore {
        &self.store
    }

    /// Writes a report for `source` stamped with the current time and returns its identifier.
    pub fn record(&self, source: CrashSource) -> Result<String, MitigationError> {
        self.store.write(&CrashReport {
            when: Timestamp::now(),
            code: source.code(),
            source,
            device: self.device.clone(),
            app_version: self.app_version.clone(),
        })
    }
}

static REPORTER: OnceLock<CrashReporter> = OnceLock::new();

/// Makes `reporter` the process-wide reporter used by the panic hook.
///
/// The first configuration wins; later calls (such as after a Flutter hot restart) return the
/// reporter already in place.
pub fn configure_reporter(reporter: CrashReporter) -> &'static CrashReporter {
    REPORTER.get_or_init(|| reporter)
}

/// Process-wide reporter, once configured.
pub fn reporter() -> Option<&'static CrashReporter> {
    REPORTER.get()
}

/// Installs a panic hook that writes a [`RustCrashSource::Panic`] report and then runs the
/// previously installed hook. Panics before [`configure_reporter`] only reach the previous hook.
///
/// The hook deliberately avoids the `log` facade: a panic raised while the logger holds a lock
/// would otherwise deadlock.
pub fn install_panic_hook() {
    static INSTALL: Once = Once::new();
    INSTALL.call_once(|| {
        let previous = std::panic::take_hook();
        std::panic::set_hook(Box::new(move |info| {
            if let Some(reporter) = reporter() {
                let _ = reporter.record(CrashSource::Rust(panic_source(info)));
            }
            previous(info);
        }));
    });
}

fn panic_source(info: &std::panic::PanicHookInfo<'_>) -> RustCrashSource {
    let payload = info.payload();
    let message = payload
        .downcast_ref::<&str>()
        .map(|message| (*message).to_owned())
        .or_else(|| payload.downcast_ref::<String>().cloned())
        .unwrap_or_else(|| "non-string panic payload".to_owned());
    RustCrashSource::Panic {
        thread: std::thread::current()
            .name()
            .unwrap_or("<unnamed>")
            .to_owned(),
        message,
        location: info.location().map(ToString::to_string),
        backtrace: Some(std::backtrace::Backtrace::force_capture().to_string()),
    }
}

#[cfg(test)]
#[allow(
    clippy::expect_used,
    clippy::panic,
    reason = "crash store tests fail immediately when temporary files cannot be used"
)]
mod tests {
    use super::*;

    fn report(seconds: i64, source: CrashSource) -> CrashReport {
        CrashReport {
            when: Timestamp::from_second(seconds).expect("valid timestamp"),
            code: source.code(),
            source,
            device: UserDevice::default(),
            app_version: "1.0.0".into(),
        }
    }

    #[test]
    fn reports_round_trip_newest_first() {
        let dir = tempfile::tempdir().expect("temporary directory");
        let store = CrashStore::open(dir.path()).expect("open store");
        let panic = CrashSource::Rust(RustCrashSource::Panic {
            thread: "audio".into(),
            message: "boom".into(),
            location: Some("src/lib.rs:1:1".into()),
            backtrace: None,
        });
        let flutter = CrashSource::Flutter(FlutterCrashSource::UncaughtAsync {
            message: "bad state".into(),
            stack: None,
        });

        store
            .write(&report(10, panic.clone()))
            .expect("write panic");
        let newest = store
            .write(&report(20, flutter.clone()))
            .expect("write flutter");

        let listed = store.list().expect("list");
        let [latest, oldest] = listed.as_slice() else {
            panic!("expected two reports, got {listed:?}");
        };
        assert_eq!(latest.id, newest);
        assert_eq!(latest.report.source, flutter);
        assert_eq!(latest.report.code, 2002);
        assert_eq!(oldest.report.source, panic);

        store.remove(&newest).expect("remove");
        assert_eq!(store.list().expect("list").len(), 1);
    }

    #[test]
    fn prune_keeps_only_the_newest_reports() {
        let dir = tempfile::tempdir().expect("temporary directory");
        let store = CrashStore::open(dir.path()).expect("open store");
        let kept = i64::try_from(MAX_STORED_CRASH_REPORTS).expect("small constant");
        for second in 0..kept + 5 {
            store
                .write(&report(
                    second,
                    CrashSource::Rust(RustCrashSource::UncleanShutdown),
                ))
                .expect("write");
        }

        let listed = store.list().expect("list");
        assert_eq!(listed.len(), MAX_STORED_CRASH_REPORTS);
        assert_eq!(
            listed.last().expect("oldest kept").report.when.as_second(),
            5
        );
    }

    #[test]
    fn report_ids_cannot_escape_the_store() {
        let dir = tempfile::tempdir().expect("temporary directory");
        let store = CrashStore::open(dir.path()).expect("open store");

        for id in [
            "../secret",
            "crash-../../x",
            "other-1",
            "crash-",
            "crash-1/2",
        ] {
            assert!(matches!(
                store.remove(id),
                Err(MitigationError::InvalidReportId(_))
            ));
        }
    }

    #[test]
    fn codes_are_stable() {
        assert_eq!(RustCrashSource::UncleanShutdown.code(), 1002);
        assert_eq!(
            FlutterCrashSource::FrameworkError {
                library: None,
                message: String::new(),
                stack: None,
            }
            .code(),
            2001
        );
    }
}
