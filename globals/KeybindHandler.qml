pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Signal emitted when a keybind is triggered
    signal keybindTriggered(string action)

    // Named pipe for IPC communication (same approach as Ambxst)
    readonly property string ipcPipe: "/tmp/molten_ipc.pipe"

    // Process to create and listen to the named pipe
    Process {
        id: pipeListener
        command: ["bash", "-c", "rm -f " + root.ipcPipe + "; mkfifo " + root.ipcPipe + "; tail -f " + root.ipcPipe]
        running: true
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                const cmd = data.trim()
                if (cmd !== "") {
                    root.keybindTriggered(cmd)
                }
            }
        }
        
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (line && !line.includes("Broken pipe")) {
                    console.warn("KeybindHandler:", line)
                }
            }
        }
    }
}

