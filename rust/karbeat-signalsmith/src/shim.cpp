// Implements the C ABI declared in `shim.h` over `signalsmith::stretch::SignalsmithStretch`.

#include "shim.h"

#include "signalsmith-stretch/signalsmith-stretch.h"

#include <new>

namespace {

using Stretch = signalsmith::stretch::SignalsmithStretch<float>;

// Fixed seed so renders are reproducible.
constexpr long kSeed = 0x6b617262;

// Analysis block, in seconds: the length of the library's default preset.
constexpr double kBlockSeconds = 0.12;
// Hop between blocks, in seconds: half the default preset's, so blocks overlap 8 times
// instead of 4. The denser overlap smooths phase and transients for about twice the work.
constexpr double kIntervalSeconds = 0.015;

}  // namespace

struct KarbeatStretch {
    Stretch stretch;

    KarbeatStretch() : stretch(kSeed) {}
};

extern "C" {

KarbeatStretch *karbeat_stretch_new(int channels, float sample_rate) noexcept {
    try {
        auto *instance = new KarbeatStretch();
        instance->stretch.configure(channels, static_cast<int>(sample_rate * kBlockSeconds),
                                    static_cast<int>(sample_rate * kIntervalSeconds), true);
        return instance;
    } catch (...) {
        return nullptr;
    }
}

void karbeat_stretch_delete(KarbeatStretch *instance) noexcept { delete instance; }

int karbeat_stretch_input_latency(const KarbeatStretch *instance) noexcept {
    return instance->stretch.inputLatency();
}

int karbeat_stretch_output_latency(const KarbeatStretch *instance) noexcept {
    return instance->stretch.outputLatency();
}

int karbeat_stretch_seek_length(const KarbeatStretch *instance) noexcept {
    return instance->stretch.seekLength();
}

void karbeat_stretch_reset(KarbeatStretch *instance) noexcept { instance->stretch.reset(); }

void karbeat_stretch_set_transpose_factor(KarbeatStretch *instance, float factor) noexcept {
    instance->stretch.setTransposeFactor(factor);
}

void karbeat_stretch_set_formant_compensation(KarbeatStretch *instance, int compensate) noexcept {
    instance->stretch.setFormantFactor(1.0f, compensate != 0);
}

void karbeat_stretch_seek(KarbeatStretch *instance, const float *const *inputs, int frames,
                          double rate) noexcept {
    instance->stretch.seek(inputs, frames, rate);
}

void karbeat_stretch_process(KarbeatStretch *instance, const float *const *inputs,
                             int input_frames, float *const *outputs,
                             int output_frames) noexcept {
    instance->stretch.process(inputs, input_frames, outputs, output_frames);
}

}  // extern "C"
