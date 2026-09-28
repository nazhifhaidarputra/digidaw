import 'package:karbeat/shared/models/export_audio.dart';
import 'package:karbeat/src/rust/api/project.dart';

const bitPerSampleOptions = [
    BitDepthDTO.bitPerSample(8),
    BitDepthDTO.bitPerSample(16),
    BitDepthDTO.bitPerSample(24),
    BitDepthDTO.bitPerSample(32),
  ];

/// FLAC stores integer samples only, up to 24-bit
const flacBitPerSampleOptions = [
    BitDepthDTO.bitPerSample(8),
    BitDepthDTO.bitPerSample(16),
    BitDepthDTO.bitPerSample(24),
  ];

/// Opus encodes fullband audio at 48 kHz only
const oggSampleRateOptions = [SampleRate.hz48000];

const bitPerSecondOptions = [
    BitDepthDTO.bitPerSecond(128),
    BitDepthDTO.bitPerSecond(192),
    BitDepthDTO.bitPerSecond(256),
    BitDepthDTO.bitPerSecond(320),
];