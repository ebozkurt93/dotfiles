import Quickshell

import "plugins/bar"
import "plugins/lock"
import "plugins/launcher"
import "plugins/clipboard"

ShellRoot {
    id: shell

    Bar {
        shell: shell
    }

    Lock {
        shell: shell
    }

    Launcher {
        shell: shell
    }

    Clipboard {
        shell: shell
    }
}
