#[derive(Debug, Clone, Copy, PartialEq)]
pub enum MetronomeSound {
    SineClick,
}

impl MetronomeSound {
    /// Generates a single sample of the metronome tick.
    pub fn generate_sample(&self, time_sec: f32, is_downbeat: bool) -> f32 {
        match self {
            MetronomeSound::SineClick => {
                // Professional DAW clicks use much higher frequencies 
                // to cut through dense mixes.
                let freq = if is_downbeat { 2000.0 } else { 1000.0 };
                
                // Increase the decay rate significantly (from 50.0 to 150.0).
                // This ensures the envelope is completely silent (0.0005) by the 50ms cutoff.
                let envelope = (-time_sec * 150.0).exp(); 
                
                // let osc = (time_sec * std::f32::consts::TAU * freq).sin();
                
                // Add a tiny bit of pitch drop (FM) for a percussive "thwack" instead of a "beep"
                let pitch_drop = (-time_sec * 200.0).exp();
                let fm_osc = (time_sec * std::f32::consts::TAU * (freq + (freq * pitch_drop))).sin();
                
                fm_osc * envelope * 0.5
            }
        }
    }
}