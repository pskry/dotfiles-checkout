#!/bin/bash

if ! eval which git >/dev/null 2>&1; then
    1>&2 echo "'git' not found. Please check your path or install git."
    exit 1
fi

BRANCH="master"
if [ $# -gt 0 ]; then
    BRANCH="$1"
fi
exit 1

GIT="$(which git)"
WORK_DIR="$HOME"
TARGET_DIR="$WORK_DIR/.dotfiles"
BACKUP_DIR="$WORK_DIR/.dotfiles-backup"
UPSTREAM="git@github.com:pskry/dotfiles.git"

dot() {
    $GIT --git-dir=$TARGET_DIR --work-tree=$WORK_DIR $@
}

$GIT clone -b $BRANCH --bare $UPSTREAM $TARGET_DIR || exit 1

dot checkout 2>/dev/null
success=$?
if [ $success -ne 0 ]; then
    echo "backing up pre-existing dotfiles..."
    conflicts=$(dot checkout 2>&1 | grep -E "\s+\." | awk '{print $1}')

    # check all backup moves
    for item in ${conflicts[@]}; do
	src="$WORK_DIR/$item"
	dst="$BACKUP_DIR/$item"
        if [ -f $dst ]; then
		1>&2 echo "cannot backup '$src' - destination file ($dst) already exists! please move the destination file or choose another backup location."
	    exit 1
	fi
    done

    # commit backup move
    for item in ${conflicts[@]}; do
	src="$WORK_DIR/$item"
	dst="$BACKUP_DIR/$item"
        echo "  backup $item"
	mkdir -p $(dirname $dst)
        mv $src $dst
    done
fi

# checkout again after failure and subsequent backup
[ $success -eq 0 ] || dot checkout
if [ $? -ne 0 ]; then
	1>&2 echo "unexpected error. abort"
fi

# hide all untracked files
dot config status.showUntrackedFiles no

# resolve submodules
dot submodule init
dot submodule update

echo "dotfiles successfully checked out"
echo "convenience alias for managing dotfiles:"
echo "  alias dot='git --git-dir=$TARGET_DIR --work-tree=$WORK_DIR'"
