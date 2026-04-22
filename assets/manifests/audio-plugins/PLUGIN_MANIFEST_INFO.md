# Audio Plugin Manifest Info

## Detail of parameters

- `id`: Integer; id of the plugin
- `name` : String: name of the plugin
- `author`: Author of the plugin. can be a person or organization
- `is_synth`: Whether this plugin is synth or not (the other is effect)
- `host`: The host API where this plugin compatible is. "native" means that it run directly with Karbeat Ecosytem without host API or adapter interface. for VST3 plugins, write it as `vst3`, LV2 as `lv2`, CLAP as `clap`, Audio Unit as `au`, etc.
- `parameters` : The parameter specs of the plugin