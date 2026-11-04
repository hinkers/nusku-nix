// Network and Bluetooth state for the bar and the panel (NetworkManager and BlueZ, natively).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

Singleton {
    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiNetwork: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property bool wifiOn: Networking.wifiEnabled
    // 0-1 (NetworkManager gives 0-100).
    readonly property real signal: wifiNetwork ? (wifiNetwork.signalStrength > 1 ? wifiNetwork.signalStrength / 100 : wifiNetwork.signalStrength) : 0
    readonly property bool online: wiredDevice !== null || wifiNetwork !== null

    readonly property string netIcon: wiredDevice ? "󰈀"
        : wifiNetwork ? ["󰤟", "󰤢", "󰤥", "󰤨"][Math.min(3, Math.floor(signal * 4))]
        : wifiOn ? "󰤯" : "󰤭"
    readonly property string netLabel: wiredDevice ? "Wired" : wifiLabel
    readonly property string wifiLabel: wifiNetwork ? wifiNetwork.name : wifiOn ? "Not connected" : "Off"

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: adapter !== null && adapter.enabled
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)
    readonly property string btIcon: !btOn ? "󰂲" : btConnected.length > 0 ? "󰂱" : "󰂯"
    // Like Wi-Fi's network name: the device when one is connected, else how many.
    readonly property string btLabel: !btOn ? "Off"
        : btConnected.length === 0 ? "On"
        : btConnected.length === 1 ? btConnected[0].name
        : `${btConnected.length} connected`
}
