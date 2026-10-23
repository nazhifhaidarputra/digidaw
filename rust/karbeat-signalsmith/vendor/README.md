# Vendored Signalsmith sources

Header-only, MIT licensed, copied unmodified. `build.rs` compiles them through `src/shim.cpp`.

| Directory | Upstream | Version |
| --- | --- | --- |
| `signalsmith-stretch/` | https://github.com/Signalsmith-Audio/signalsmith-stretch | tag `1.4.0` (`a670068d9aeb64913331d5cc29337b19a457a7df`), `signalsmith-stretch.h` |
| `signalsmith-linear/` | https://github.com/Signalsmith-Audio/linear | tag `0.6.4` (`de55e6a50ffcf6f8f43f649692d94691c7025151`), `stft.h` and `fft.h` |

Only the files the stretcher includes are kept; the platform FFT back ends in `linear/platform`
are left out, so the portable FFT is used everywhere. To update, copy the same files from new
tags and rerun the `karbeat-signalsmith` and `karbeat-dsp` tests.
