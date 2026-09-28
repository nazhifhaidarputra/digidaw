/// Bus-owned parameter groups that can be addressed by automation.
pub enum BusAutomationTarget {
    /// Bus fader gain.
    Volume,
    /// Bus stereo pan.
    Pan,
    /// Parameter belonging to an effect in the bus chain.
    BusEffect,
}
