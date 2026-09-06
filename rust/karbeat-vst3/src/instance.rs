//! VST-3 Plugin instance definition

use std::cell::{Cell, RefCell};

use karbeat_plugin_api::traits::HashMap;
use vst3::{
    ComPtr, ComWrapper,
    Steinberg::{
        IPluginBaseTrait, TUID,
        Vst::{
            IAudioProcessor, IAudioProcessorTrait, IComponent, IComponentTrait, IConnectionPoint,
            IConnectionPointTrait, IEditController,
        },
    },
};

use crate::{
    api::Vst3PluginInfo,
    context::{Vst3EventContext, Vst3HostContext},
};

/// Shared, refcounted plugin state. `Vst3Wrapper` is a cheap `Rc` handle around this; cloning the
/// wrapper does NOT create a second plugin instance, it shares this one. Real VST3 teardown
/// (`setProcessing`/`setActive`/`terminate`) happens exactly once, in `Drop for Vst3Instance`,
/// when the last handle goes away.
pub struct Vst3Instance {
    pub class_id: TUID,
    pub plugin_info: Vst3PluginInfo,
    pub component: ComPtr<IComponent>,
    pub processor: ComPtr<IAudioProcessor>,

    /// `None` only in the (spec-violating) case where a plugin implements neither
    /// `IEditController` on itself nor reports a separate controller class id.
    pub edit_ctrl: Option<ComPtr<IEditController>>,

    pub separate_controller: bool,
    pub component_cp: Option<ComPtr<IConnectionPoint>>,
    pub controller_cp: Option<ComPtr<IConnectionPoint>>,

    pub bypass_param_id: Option<u32>,

    /// Parameter updates from `set_parameter`/`apply_automation` land here and get drained into
    /// an `IParameterChanges` block at the top of the next `process()` call, which is the only
    /// path that actually affects the audio thread (`setParamNormalized` alone only updates the
    /// controller/GUI side).
    pub pending_changes: RefCell<HashMap<u32, f64>>,

    pub is_active: Cell<bool>,
    pub is_processing: Cell<bool>,
    pub last_pdc_latency: Cell<f64>,

    pub _host_context: ComWrapper<Vst3HostContext>,
    pub _event_context: ComWrapper<Vst3EventContext>,
}

impl Drop for Vst3Instance {
    fn drop(&mut self) {
        // SAFETY: `self` is pinned till after dropped.
        if self.is_processing.get() {
            unsafe { self.processor.setProcessing(0) };
        }

        if self.is_active.get() {
            unsafe { self.component.setActive(0) };
        }

        if let (Some(a), Some(b)) = (&self.component_cp, &self.controller_cp) {
            unsafe {
                a.disconnect(b.as_com_ref().as_ptr().cast());
                b.disconnect(a.as_com_ref().as_ptr().cast());
            }
        }

        if self.separate_controller {
            if let Some(ctrl) = &self.edit_ctrl {
                unsafe { ctrl.terminate() };
            }
        }

        unsafe { self.component.terminate() };
    }
}
