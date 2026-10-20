/* C ABI over `signalsmith::stretch::SignalsmithStretch<float>`, implemented in `shim.cpp`.
 * `build.rs` generates the Rust bindings from this header.
 *
 * Only construction allocates. Every other call works in buffers sized at construction, so
 * it neither allocates nor throws. */

#ifndef KARBEAT_SIGNALSMITH_SHIM_H
#define KARBEAT_SIGNALSMITH_SHIM_H

#ifdef __cplusplus
#define KARBEAT_NOEXCEPT noexcept
extern "C" {
#else
#define KARBEAT_NOEXCEPT
#endif

/** Opaque stretcher owner. */
typedef struct KarbeatStretch KarbeatStretch;

/** Creates a stretcher with the cheaper preset and split computation; null on failure. */
KarbeatStretch *karbeat_stretch_new(int channels, float sample_rate) KARBEAT_NOEXCEPT;

void karbeat_stretch_delete(KarbeatStretch *instance) KARBEAT_NOEXCEPT;

/** Input frames the processing point trails the newest input by. */
int karbeat_stretch_input_latency(const KarbeatStretch *instance) KARBEAT_NOEXCEPT;

/** Output frames the output trails the processing point by. */
int karbeat_stretch_output_latency(const KarbeatStretch *instance) KARBEAT_NOEXCEPT;

/** Input frames a seek uses at most: one block plus one interval. */
int karbeat_stretch_seek_length(const KarbeatStretch *instance) KARBEAT_NOEXCEPT;

/** Clears all buffered audio. */
void karbeat_stretch_reset(KarbeatStretch *instance) KARBEAT_NOEXCEPT;

/** Frequency multiplier; 2 is an octave up. */
void karbeat_stretch_set_transpose_factor(KarbeatStretch *instance,
                                          float factor) KARBEAT_NOEXCEPT;

/** Non-zero keeps the spectral envelope in place when transposing. */
void karbeat_stretch_set_formant_compensation(KarbeatStretch *instance,
                                              int compensate) KARBEAT_NOEXCEPT;

/** Replaces the input history with `frames` frames per channel, producing no output. `rate`
 * is the input frames per output frame expected next. */
void karbeat_stretch_seek(KarbeatStretch *instance, const float *const *inputs, int frames,
                          double rate) KARBEAT_NOEXCEPT;

/** Consumes `input_frames` frames per channel and writes `output_frames` frames per
 * channel. */
void karbeat_stretch_process(KarbeatStretch *instance, const float *const *inputs,
                             int input_frames, float *const *outputs,
                             int output_frames) KARBEAT_NOEXCEPT;

#ifdef __cplusplus
}
#endif

#endif
