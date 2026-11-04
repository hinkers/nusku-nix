// Audio from PipeWire, for the bar's speaker and its menu: the outputs and inputs (with the
// default of each) and the apps playing sound, all tracked so their volume and mute are live.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // By node type, which is known at once (a node's properties only arrive once it's tracked).
    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: nodes.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var sources: nodes.filter(n => n.type === PwNodeType.AudioSource)
    // Apps playing sound (PipeWire's own internal streams aren't audio out streams).
    readonly property var streams: nodes.filter(n => n.type === PwNodeType.AudioOutStream)

    PwObjectTracker { objects: [...root.sinks, ...root.sources, ...root.streams] }

    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property string icon: !sink ? "󰝟" : muted ? "󰝟" : volume < 0.34 ? "󰕿" : volume < 0.67 ? "󰖀" : "󰕾"

    function setVolume(node, v) { if (node && node.audio) node.audio.volume = Math.min(1, Math.max(0, v)); }
    function toggleMute(node) { if (node && node.audio) node.audio.muted = !node.audio.muted; }
    function nudge(step) { setVolume(sink, volume + step); }

    // What to call a node: an app's name, or a device's description without the sound card's
    // name in front ("Alder Lake … Audio Controller Speaker" -> "Speaker") or "(Stereo)" after.
    function label(n) {
        const p = n.properties ?? {};
        if (p["application.name"]) return p["application.name"];
        const d = (n.description || n.nickname || n.name)
            .replace(/^.*\b(Audio Controller|Audio Device|Audio)\s+(?=\S)/, "")
            .replace(/\s+Output \((Stereo|Mono|Surround[^)]*)\)$/, "")
            .replace(/\s+\((Stereo|Mono)\)$/, "");
        return d !== "" ? d : n.name;
    }
}
