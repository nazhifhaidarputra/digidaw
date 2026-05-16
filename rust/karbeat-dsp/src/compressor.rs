use karbeat_macros::karbeat_plugin;

#[derive(Clone)]
#[karbeat_plugin]
pub struct Compressor {
    #[param(id = "attack", name = "Attack", default = 5, min = 1, max = 1000, step = 1)]
    pub attack_ms: i32,
    #[param(id = "release", name = "Release", default = 5, min = 1, max = 1000, step = 1)]
    pub release_ms: i32,
    #[param(id = "ratio", name = "Ratio", default = 1.0, max = 24.0, step = 0.1)]
    pub ratio: f64,
    #[param(id = "threshold", name = "Threshold", default = 0.0, max = 24.0, step = 0.1)]
    pub threshold: f64, // In dB
    #[param(id = "delay", name = "Delay", default = 5, min = 0, max = 100, step = 1)]
    pub delay_ms: i32, // Lookahead delay
    #[param(id = "knee", name = "Knee", default = 0.0, max = 24.0, step = 0.1)]
    pub knee: f64, // In dB
    #[param(id = "makeup_gain", name = "MakeUp Gain", default = 0.0, max = 24.0, step = 0.1)]
    pub makeup_gain: f64, // In dB
    #[param(id = "wetness", name = "Wetness", default = 0.0, max = 1.0, step = 0.1)]
    pub wetness: f64, // 0.0 to 1.0

    sample_rate: f64,
    envelope_db: f64,       // Tracks the smoothed gain reduction
    delay_buffer: Vec<f64>, // Ring buffer for lookahead
    delay_index: usize,
}

impl Compressor {
    pub fn prepare(&mut self, sample_rate: f64) {
        self.sample_rate = sample_rate;
        self.envelope_db = 0.0;
        self.update_delay_buffer();

    }

    /// Resizes the delay buffer gracefully if the user changes the delay time
    #[inline(always)]
    fn update_delay_buffer(&mut self) {
        let delay_samples = (self.delay_ms.get() as f64 * 0.001 * self.sample_rate).max(0.0) as usize;
        
        if self.delay_buffer.len() != delay_samples {
            // Using resize prevents completely dropping the backing allocation 
            // if the buffer is shrinking, which is safer for the audio thread.
            self.delay_buffer.resize(delay_samples, 0.0);
            if self.delay_index >= delay_samples {
                self.delay_index = 0;
            }
        }
    }

    // WE use f32 because CPAL only accepts f32 as the highest audio buffer stream
    pub fn process_sample(&mut self, input: f32) -> f32 {
        let input_f64 = input as f64;

        // Ensure lookahead buffer matches current automated delay parameter
        self.update_delay_buffer(); 

        let threshold = self.threshold.get();
        let knee = self.knee.get();
        let ratio = self.ratio.get().max(1.0);
        let attack_ms = self.attack_ms.get().max(1) as f64;
        let release_ms = self.release_ms.get().max(1) as f64;
        let makeup_gain = self.makeup_gain.get();
        let wetness = self.wetness.get();

        let input_abs = input_f64.abs();
        let input_db = if input_abs > 1e-6 {
            20.0 * input_abs.log10()
        } else {
            -120.0
        };

        let overshoot = if knee > 0.0 && input_db > (threshold - knee / 2.0) && input_db < (threshold + knee / 2.0) {
            // Inside the soft knee region (quadratic interpolation)
            (input_db - threshold + knee / 2.0).powi(2) / (2.0 * knee)
        } else if input_db > threshold {
            // Above the knee
            input_db - threshold
        } else {
            // Below the threshold
            0.0
        };

        let gain_reduction_target_db = overshoot * (1.0 - 1.0 / ratio);

        let attack_coef = (-1.0 / (attack_ms * 0.001 * self.sample_rate)).exp();
        let release_coef = (-1.0 / (release_ms * 0.001 * self.sample_rate)).exp();

        if gain_reduction_target_db > self.envelope_db {
            // Attack phase (compressing more)
            self.envelope_db = attack_coef * self.envelope_db + (1.0 - attack_coef) * gain_reduction_target_db;
        } else {
            // Release phase (compressing less)
            self.envelope_db = release_coef * self.envelope_db + (1.0 - release_coef) * gain_reduction_target_db;
        }

        let delayed_sample = if self.delay_buffer.is_empty() {
            input_f64
        } else {
            let out = self.delay_buffer[self.delay_index];
            self.delay_buffer[self.delay_index] = input_f64;
            self.delay_index = (self.delay_index + 1) % self.delay_buffer.len();
            out
        };

        let linear_gain = 10.0_f64.powf((-self.envelope_db + makeup_gain) / 20.0);
        let wet_signal = delayed_sample * linear_gain;

        let out = (1.0 - wetness) * delayed_sample + wetness * wet_signal;

        out as f32
    }
}