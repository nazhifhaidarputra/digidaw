/// Transport feedback struct sent from the audio thread to Flutter.
/// This is the single source of truth for all runtime transport state.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct TransportFeedback {
    /// Song playhead position in engine-rate samples.
    pub samples: u32,
    /// Song playhead position in pulses-per-quarter-note ticks.
    pub ticks: u32,
    /// One-based beat index in the song timeline.
    pub beat: usize,
    /// One-based bar index in the song timeline.
    pub bar: usize,
    /// Current tempo in beats per minute, allowing clients to interpolate between updates.
    pub tempo: f32,
    /// Engine sample rate used to interpret sample positions.
    pub sample_rate: u32,

    /// Whether the currently selected playback mode is running.
    pub is_playing: bool,
    /// Whether song playback loops at the configured loop boundary.
    pub is_looping: bool,
    /// Whether song recording is armed and active.
    pub is_recording: bool,
    /// Whether independent pattern playback is running.
    pub is_pattern_playing: bool,

    /// Whether pattern mode, rather than song mode, owns the active playhead.
    pub is_pattern_mode: bool,
    /// Pattern playhead position in engine-rate samples.
    pub pattern_samples: u32,
    /// Pattern playhead position in pulses-per-quarter-note ticks.
    pub pattern_ticks: u32,
    /// One-based beat index within pattern playback.
    pub pattern_beat: usize,
    /// One-based bar index within pattern playback.
    pub pattern_bar: usize,

    /// Engine output frame, counted since the engine started, at which the reported playhead
    /// sample is rendered. Matched against the output clock to show it when it is heard.
    pub render_frame: u64,
    /// When the UI should show this feedback.
    pub timing: FeedbackTiming,
}

/// When a [`TransportFeedback`] should reach the UI.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FeedbackTiming {
    /// Once the output device plays the frame it was rendered at.
    Audible,
    /// Right away, replacing feedback still waiting to be heard. Used for user actions such as
    /// seeking or stopping, which the playhead should follow at once.
    Immediate,
}

pub use karbeat_core::core::project::PluginTarget;
