// The media players (MPRIS): the one the bar and the media menu show is the one picked in the
// menu, else the one playing, else the first.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root
    readonly property var players: Mpris.players.values
    // Picked in the media menu (by its D-Bus name, so it survives the player list changing).
    property string pickedName: ""
    readonly property var player: players.find(p => p.dbusName === pickedName)
        ?? players.find(p => p.isPlaying) ?? players[0] ?? null
}
