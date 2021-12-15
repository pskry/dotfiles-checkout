#!/bin/bash

if ! eval which git >/dev/null 2>&1; then
    1>&2 echo "'git' not found. Please check your path or install git."
    exit 1
fi

LOG_DISABLE=true

function log() {
    $LOG_DISABLE && return
    local msg=$1
    1>&2 echo "$(date -Iseconds) - $msg"
}

BRANCH='master'
if [ $# -gt 0 ]; then
    BRANCH="$1"
fi

WORK_DIR=$HOME
if [ $# -gt 1 ]; then
    WORK_DIR=$2
fi

TARGET_DIR="$WORK_DIR/.dotfiles"
BACKUP_DIR="$WORK_DIR/.dotfiles-backup"
UPSTREAM="git@github.com:pskry/dotfiles.git"

log "branch:     $BRANCH"
log "target-dir: $TARGET_DIR"
log "backup-dir: $TARGET_DIR"

git config --global alias.dot "!git --git-dir=$TARGET_DIR --work-tree=$WORK_DIR"
git clone -b "$BRANCH" --bare $UPSTREAM "$TARGET_DIR" || exit 1

log "checkout..."
git dot checkout 2>/dev/null
success=$?
if [ $success -ne 0 ]; then
    log "backing up pre-existing dotfiles..."
    # conflicts=$(git dot checkout 2>&1 | grep -E '^\s+' | sed 's/^\s//' | sed 's/(\s)/\\#_#/g')
    conflicts=$(git dot checkout 2>&1 | grep -E '^\s+' | sed 's/^\s//')

    # copy to backup or fail
    OLD_IFS="$IFS"
    trap IFS="$OLD_IFS" EXIT
    IFS=$'\n'
    for item in ${conflicts[@]}; do
        src="$WORK_DIR/$item"
        dst="$BACKUP_DIR/$item"
        if [ -f "$dst" ]; then
            1>&2 echo "cannot backup '$src' - destination file ($dst) already exists! please move the destination file or choose another backup location."
            exit 1
        fi
        log "  backup $src"
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst" || exit 2
    done

    # delete original
    for item in ${conflicts[@]}; do
        src="$WORK_DIR/$item"
        log "  remove $src"
        rm "$item"
    done
fi

# checkout again after failure and subsequent backup
if [ $success -ne 0 ]; then
    log "checkout after backup..."
    git dot checkout || exit 1
fi

# hide all untracked files
log "configuring git dot..."
git dot config status.showUntrackedFiles no

# resolve submodules
log "loading submodules..."
pushd "$TARGET_DIR" >/dev/null || exit 2
git dot submodule update --init || exit 1
popd >/dev/null || exit 2

echo ""
echo "====================================="
echo "= dotfiles successfully checked out ="
echo "====================================="
echo "git operations on the dotfiles can be performed with the alias 'dot'"
echo "  i.e. git dot status, git dot add my.file && git dot commit -m \"awesome\""
