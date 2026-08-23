import Quickshell

import "plugins/bar"
import "plugins/lock"
import "plugins/launcher"

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
}
