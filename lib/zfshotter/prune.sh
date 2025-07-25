# Copyright (C) 2025 Mojtaba Moaddab
#
# This file is part of ZFShotter.
#
# ZFShotter is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ZFShotter is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZFShotter. If not, see <http://www.gnu.org/licenses/>.

load_module dataset_config
load_module logging

load_module ./prune_policy


zfshotter::__list_snapshots() {
    zfs list -H -p -o creation,name -s creation -t snapshot "$1"
}

zfshotter::__multi_purne_policy_pipe() {
    local snapshots="$(cat)"

    local prune_policy
    for prune_policy in "$@"
    do
        echo "$snapshots" | zfshotter::prune_policy::pipe "$prune_policy"
    done | sort | uniq
}

# zfshotter::destroy_snapshots
#
# Destroys snapshots read from standard input (timestamp snapshot).
zfshotter::destroy_snapshots() {
    local line timestamp snapshot
    while IFS= read -r line
    do
        read timestamp snapshot <<< "$line"

        zfs destroy "$snapshot"
    done
}

# zfshotter::prune_snapshot <dataset> <options> <prune-policy>...
zfshotter::prune_snapshot() {
    local dataset="$1"
    local -n __options="$2"
    local prune_policies=("${@:3}")

    zfshotter::__list_snapshots "$dataset" | \
        zfshotter::__multi_purne_policy_pipe "${prune_policies[@]}" | \
        zfshotter::destroy_snapshots
}

# zfshotter::prune_snapshot_from_file <filepath> <prune-policy>...
zfshotter::prune_snapshot_from_file() {
    local filepath="$1"
    local prune_policies=("${@:2}")

    local -a datasets
    mapfile -t datasets < "$filepath"

    local dataset_config dataset
    for dataset_config in "${datasets[@]}"
    do
        local -A options

        dataset_config::parse options "$dataset_config"

        dataset="${options["dataset"]}"

        if ! dataset_config::boolean "${options["prune"]}" "yes"; then
            logging::debug "Skip pruning snapshots of $dataset"
            continue
        fi

        zfshotter::prune_snapshot "$dataset" options "${prune_policies[@]}"

        unset options
    done
}
