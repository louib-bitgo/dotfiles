#!/usr/bin/env bash
set -e

die() { echo "$*" 1>&2 ; exit 1; }

SCRIPT_DIR=$(realpath "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_DIR")

checkout_and_verify_git_ref () {
    git_repo_path=$1
    git_ref=$2
    git_checksum=$3
    if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
	echo "Missing parameters to checkout_and_verify_git_ref function.";
	return 1
    fi
    cd "$git_repo_path"
    if ! git checkout "$git_ref"; then
	echo "Invalid git ref $git_ref for $git_repo_path."
	return 1
    fi
    # I followed this guide to find an archiving command that is deterministic:
    # https://reproducible-builds.org/docs/archives/
    tar --sort=name --mtime='2015-10-21 00:00Z' -cf "/tmp/$git_ref.tar" ./
    checksum=$(sha256sum "/tmp/$git_ref.tar" | cut -d ' ' -f1)
    if [[ "$checksum" != "$git_checksum" ]]; then
	echo "Checksum for $git_repo_path $git_ref did not match. Expected $git_checksum. Got $checksum"
	return 1
    fi
    echo "✔️ Checksum for $git_repo_path $git_ref is valid."
}

install_vim_plugin () {
    git_repo_url=$1
    git_repo_path=$2
    git_ref=$3
    git_checksum=$4
    if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]]; then
	echo "Missing parameters to install_git_plugin function.";
	return 1
    fi
    if [[ ! -d "$git_repo_path" ]]; then
	# FIXME we might want to only use the recursive flag if absolutely necessary.
	git clone --recursive "$git_repo_url" "$git_repo_path"
    fi
    if ! checkout_and_verify_git_ref "$git_repo_path" "$git_ref" "$git_checksum"; then
	echo "Could not verify the integrity of git repo $git_repo_url.";
	return 1
    fi
    echo "✔️ Installed vim plugin from $git_repo_url."
}

if [ -d "$HOME/.config/nvim" ]; then
    echo "✔️ NeoVim is already configured."
else
    # Creating the required directories.
    # mkdir ~/.config/nvim
    # mkdir ~/.config/nvim/autoload
    # mkdir ~/.config/nvim/bundle
    # mkdir ~/.config/nvim/ftplugin

    # Installing vim pathogen.
    # curl -LSso ~/.config/nvim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

    # Cloning plugins.
    if ! install_vim_plugin "https://github.com/morhetz/gruvbox.git" "$HOME/Projects/gruvbox" bf2885a95efdad7bd5e4794dd0213917770d79b7 38a9bf882e32d95738b031507c63ba24969b078b5a44bc96777ed832c012c0fd; then
	exit 1
    fi
    echo "here!!!"

    # git clone --recursive https://github.com/leafgarland/typescript-vim.git ~/.config/nvim/bundle/typescript-vim
    # git clone --recursive https://github.com/pangloss/vim-javascript.git ~/.config/nvim/bundle/vim-javascript
    # git clone --recursive https://github.com/python-mode/python-mode.git ~/.config/nvim/bundle/python-mode
    # git clone --recursive https://github.com/tpope/vim-surround.git ~/.config/nvim/bundle/vim-surround
    # git clone --recursive https://github.com/vim-airline/vim-airline ~/.config/nvim/bundle/vim-airline
    # git clone --recursive https://github.com/octol/vim-cpp-enhanced-highlight.git ~/.config/nvim/bundle/vim-cpp-enhanced-highlight
    # git clone --recursive https://github.com/hashivim/vim-terraform.git ~/.config/nvim/bundle/vim-terraform
    # git clone --recursive https://github.com/rust-lang/rust.vim.git ~/.config/nvim/bundle/rust.vim

    # Copying config file
    # cp "$SCRIPT_DIR/../assets/vim/init.vim" ~/.config/nvim/

    # Copying language files.
    # cp "$SCRIPT_DIR/../assets/vim/javascript.vim" ~/.config/nvim/ftplugin/
    # cp "$SCRIPT_DIR/../assets/vim/sh.vim" ~/.config/nvim/ftplugin/
    # cp "$SCRIPT_DIR/../assets/vim/typescript.vim" ~/.config/nvim/ftplugin/
    # cp "$SCRIPT_DIR/../assets/vim/cpp.vim" ~/.config/nvim/ftplugin/
    # cp "$SCRIPT_DIR/../assets/vim/python.vim" ~/.config/nvim/ftplugin/
    # echo "✔️ Configured NeoVim"
fi
