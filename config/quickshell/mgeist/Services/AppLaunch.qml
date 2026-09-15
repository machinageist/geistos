// Applications must outlive Quickshell's service and its restarts.
pragma Singleton
import Quickshell

Singleton {
    function run(command) {
        if (!command || command.length === 0) return;
        // A detached process still inherits the shell's cgroup. A transient
        // user scope preserves the current environment but has its own lifetime.
        Quickshell.execDetached(["/usr/bin/systemd-run", "--user", "--scope",
            "--collect", "--quiet", "--", ...command]);
    }
}
