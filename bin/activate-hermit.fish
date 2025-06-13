#!/usr/bin/env fish

# This file must be sourced with "source bin/activate-hermit.fish" from Fish shell.
# You cannot run it directly.
#
# THIS FILE IS GENERATED; DO NOT MODIFY

if status is-interactive
    set BIN_DIR (dirname (status --current-filename))

    if "$BIN_DIR/hermit" noop > /dev/null
        # Source the activation script generated by Hermit
        "$BIN_DIR/hermit" activate "$BIN_DIR/.." | source

        # Clear the command cache if applicable
        functions -c > /dev/null 2>&1

        # Display activation message
        echo "Hermit environment $($HERMIT_ENV/bin/hermit env HERMIT_ENV) activated"
    end
else
    echo "You must source this script: source $argv[0]" >&2
    exit 33
end
