#[macro_export]
macro_rules! apply_mix_param {
    ($mix_target:expr, $final_value:expr, $channel:expr, $effects:expr) => {
        match $mix_target {
            MixerChannelParamTarget::Volume => {
                if let Some(ch) = $channel {
                    ch.volume.apply_automation($final_value);
                }
            }
            MixerChannelParamTarget::Pan => {
                if let Some(ch) = $channel {
                    ch.pan.apply_automation($final_value);
                }
            }
            MixerChannelParamTarget::Plugin { effect_id, target } => match target {
                EffectAutomationTarget::Mix => todo!(),
                EffectAutomationTarget::PluginParam { param_id } => {
                    if let Some(effects) = $effects {
                        if let Some(e) = effects.iter_mut().find(|e| e.id == *effect_id) {
                            // log::debug!("Received final value for automation: {}", $final_value);
                            e.plugin.apply_automation(*param_id, $final_value);
                        }
                    }
                }
            },
        }
    };
}
