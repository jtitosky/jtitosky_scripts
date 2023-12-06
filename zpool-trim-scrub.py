#!/usr/bin/env python3

import subprocess
import argparse
import re

def run_command_check(command_list):
    try:
        subprocess.run(command_list, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except subprocess.CalledProcessError:
        return False

def zfs_pool_maintenance_in_progress(pool_name):
    command = "zpool status -t"
    output = subprocess.check_output(command, shell=True, text=True)

    match = re.search(r'(trimming|scrubbing|resilvering)', output)
    if match:
        return True
    else:
        return False

def zfs_pool_scrub(pool_name):
    run_command_check(['zpool', 'wait', '-t', 'trim,scrub,resilver', pool_name])
    return run_command_check(['zpool', 'scrub', pool_name])

def zfs_pool_disk_trim(pool_name,disk):
    run_command_check(['zpool', 'wait', '-t', 'trim,scrub,resilver', pool_name])
    return run_command_check(['zpool', 'trim', pool_name, disk])

def zfs_pool_exists(pool_name):
   return run_command_check(['zpool', 'list', pool_name])

def zfs_pool_disks(pool_name):
    # Run the command and capture its output
    command = "zpool list -v -H -P"
    output = subprocess.check_output(command, shell=True, text=True)

    # Initialize a list to store the block devices
    disks = []

    # Use regular expressions to find lines with /dev/sd* and extract the device names
    patterns = [r'(\/dev\/disk\/by-id\/\w+-\w+)',r'(/dev/sd\w+)']

    for pattern in patterns:
        pattern = re.compile(pattern)
        matches = pattern.findall(output)
        # Add the matched device names to the block_devices list
        disks.extend(matches)

    return disks

def main():
    parser = argparse.ArgumentParser(description="Sequentially perform a trim on each disk in a zpool followed by a scrub.")
    parser.add_argument("pool_name", help="Name of the zpool to act on.")
    args = parser.parse_args()

    if not zfs_pool_exists(args.pool_name):
        print(f"The Zpool '{args.pool_name}' cannot be found.")
    else:
        disks = zfs_pool_disks(args.pool_name)
        if not disks:
            print(f"Unable to find any disks in Zpool '{args.pool_name}'.")
        else:
            for disk in disks:
                if zfs_pool_disk_trim(args.pool_name,disk):
                    print(f"Trim succeeded on '{disk}'.")
                else:
                    print(f"Trim failed on '{disk}'")
        if zfs_pool_scrub(args.pool_name):
            print(f"Scrub succeeded on Zpool '{args.pool_name}'.")
        else:
            print(f"Scrub failed on Zpool '{args.pool_name}'.")

if __name__ == "__main__":
    main()
