#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

def read_json_file(file_path):
    if not os.path.isfile(file_path):
        return []
    with open(file_path, 'r') as file:
        return json.load(file)

def substitute_env_vars(path):
    return os.path.expandvars(path)

def run_on_command_hook(custom_state, command):
    command_to_run = f'zsh -c "__custom_state={custom_state}; source ~/.zshrc; eval \\"{command}\\" > /dev/null 2>&1;"'
    subprocess.Popen(command_to_run, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def get_file_path(state):
    return Path.home() / "Documents/bitbar_plugins/tmp" / state

state_icons_file_path  = Path.home() / "Documents/bitbar_plugins/tmp/enabled_state_icons.txt"

def main(arg1=None, arg2=None, arg3=None):
    style = "size=13"
    config_file = Path.home() / "dotfiles/bitbar/Documents/bitbar_plugins/tmp/states.json"
    data = read_json_file(config_file)
    data = [item for item in data if not item.get('disabled', None)]

    states = [item['title'] for item in data]
    icons = {item['title']: item.get('icon', '') for item in data}
    paths = {item['title']: substitute_env_vars(item.get('paths', '')) for item in data}
    on_enabled_commands = {item['title']: item.get('on_enabled', '') for item in data}
    on_disabled_commands = {item['title']: item.get('on_disabled', '') for item in data}
    always_sourced_if_enabled = {item['title']: item.get('always_sourced_if_enabled', False) for item in data}

    if arg1 is None:
        generate_bitbar_menu(states, icons, style)
    elif arg1 == 'enabled-states':
        print(' '.join(state for state in states if get_file_path(state).exists()))
    elif arg1 == 'is-state-enabled':
        sys.exit(0 if get_file_path(arg2).exists() else 1)
    elif arg1 == 'always-sourced-if-enabled':
        sys.exit(0 if get_file_path(arg2).exists() and always_sourced_if_enabled[arg2] else 1)
    elif arg1 == 'enabled-states-paths':
        print(' '.join(paths[state] for state in states if get_file_path(state).exists()))
    elif arg1 == 'state-paths':
        print(paths.get(arg2, ""))
    elif arg1 == 'states':
        print(' '.join(states))
    elif arg1 == 'states-with-marks':
        max_len = max([len(state) for state in states])
        for state in states:
            mark = "✅" if get_file_path(state).exists() else "❌"
            print(f"{state:<{max_len}} {mark}")
    elif arg1 == 'toggle':
        toggle_state(arg2, arg3, states, icons, on_enabled_commands, on_disabled_commands)
    elif arg1 == 'run_hook':
        run_hook(arg2, arg3, on_enabled_commands, on_disabled_commands)

def generate_bitbar_menu(states, icons, style):
    print(" | font='Symbols Nerd Font' size=18")
    print("---")
    for state in states:
        file_path = get_file_path(state)
        mark = "✅" if file_path.exists() else "❌"
        icon = icons.get(state, f"___{state}")
        print(f"{icon} {state}\t{mark} | bash={sys.argv[0]} param1=toggle param2={state} terminal=false {style}")
        print(f"--Run on_enabled | bash={sys.argv[0]} param1=run_hook param2=on_enabled param3={state} refresh=false terminal=false {style}")
        print(f"--Run on_disabled | bash={sys.argv[0]} param1=run_hook param2=on_disabled param3={state} refresh=false terminal=false {style}")
        alternate_content = f"{icon} {state}\t{mark}"
        print(f"{alternate_content} | bash={sys.argv[0]} param1=toggle param2={state} param3=ignore-event alternate=true refresh=true terminal=false {style}")
    print("Refresh | refresh=true " + style)

def toggle_state(arg2, arg3, states, icons, on_enabled_commands, on_disabled_commands):
    file_path = get_file_path(arg2)
    if arg2 in states:
        if file_path.exists():
            file_path.unlink()
            command = on_disabled_commands.get(arg2, '')
        else:
            file_path.touch()
            command = on_enabled_commands.get(arg2, '')
        with open(state_icons_file_path, 'w') as f:
            f.write(' '.join(icons[state] for state in states if get_file_path(state).exists()))
        if command and arg3 != 'ignore-event':
            run_on_command_hook(arg2, command)
        subprocess.run('open -g "bitbar://refreshPlugin?name=*"', shell=True)

def run_hook(arg2, arg3, on_enabled_commands, on_disabled_commands):
    command = ''
    if arg2 == "on_enabled":
        command = on_enabled_commands.get(arg3, '')
    elif arg2 == "on_disabled":
        command = on_disabled_commands.get(arg3, '')
    if command:
        run_on_command_hook(arg3, command)

# Run the script
if __name__ == "__main__":
    main(*sys.argv[1:])

