

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/material.dart';

enum SettingMenu {
  /// General settings (Max number of latest history stored)
  general,
  /// Configure settings for device host (Choosing ASIO or Pipewire, etc) and Input and output devices
  /// Currently input devices are not handled. Only output devices configuration are available
  hostAndDevices,
  /// Set information about the project (Title, Description, Author, Genre, etc)
  project,
  /// Set theme or appearance (Like background image, theme color pallete, Font family used, Dark vs Light mode, etc)
  appearance,
  /// Configure DSP Audio engine buffer size, DSP thread sample rate. DSP thread sample rate is different 
  /// from the CPAL sample rate which based on audio device sample rate. The more sample rate of DSP thread is,
  /// the better DSP result is, with the trade-off of performance
  /// (CPAL audio thread never be responsible during DSP processing)
  audio,
  /// Configure key binding
  keyBinding,
  /// Configure plugin scanning and other plugin settings.
  plugins,
  /// Configure and see logging
  log,
  /// Display Info about the app and how to ask and report bug to developers
  info,
}

@freezed
abstract class SettingState with _$SettingState {
  const factory SettingState({
    @Default(SettingMenu.general) 
  }) = _SettingState;

}


