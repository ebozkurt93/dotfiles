#!/usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell neovim-shell.nix

set -euo pipefail

case "$(uname -s)" in
  Darwin) os_tag="macos" ;;
  Linux)  os_tag="linux" ;;
  *) echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

nvim_repo_dir="$HOME/personal-repositories/neovim"
install_prefix="$HOME/bin/helpers/nvim-$os_tag"
selected_tag="${1:-nightly}"

function remove_neovim {
  echo "Removing neovim"
  rm -f ~/bin/nvim
  rm -rf "$install_prefix"
}

if ! [ -d "$nvim_repo_dir" ]; then
  git clone https://github.com/neovim/neovim.git $nvim_repo_dir
else
  echo $nvim_repo_dir already exists
fi
cd $nvim_repo_dir
git checkout master
git pull
git fetch --tags --force
git checkout $selected_tag

remove_neovim

echo 'Building neovim'
rm -rf build
rm -rf .deps
cmake_extra_flags=""
if [[ "$(uname -s)" == "Darwin" ]]; then
  gettext_prefix=$(dirname "$(dirname "$(command -v msgfmt)")")
  cmake_extra_flags="-DLIBINTL_INCLUDE_DIR=$gettext_prefix/include -DLIBINTL_LIBRARY=$gettext_prefix/lib/libintl.dylib"
fi
make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=$install_prefix CMAKE_EXTRA_FLAGS="$cmake_extra_flags"
make install
echo 'Built neovim'
git checkout master

echo 'Vendoring runtime dependencies so the binary no longer depends on the nix store'
nvim_bin="$install_prefix/bin/nvim"
lib_dir="$install_prefix/lib"
mkdir -p "$lib_dir"

function vendor_darwin {
  local queue=("$nvim_bin")
  local -A seen=()
  while [ ${#queue[@]} -gt 0 ]; do
    local f="${queue[0]}"
    queue=("${queue[@]:1}")
    while IFS= read -r store_path; do
      [ -z "$store_path" ] && continue
      local base dest
      base=$(basename "$store_path")
      dest="$lib_dir/$base"
      if [ -z "${seen[$base]:-}" ]; then
        cp "$store_path" "$dest"
        chmod u+w "$dest"
        seen[$base]=1
        queue+=("$dest")
      fi
      chmod u+w "$f"
      install_name_tool -change "$store_path" "@executable_path/../lib/$base" "$f"
    done < <(otool -L "$f" | grep -o '/nix/store/[a-z0-9]\{32\}-[^ ]*' || true)
  done
}

function vendor_linux {
  local queue=("$nvim_bin")
  local -A seen=()
  while [ ${#queue[@]} -gt 0 ]; do
    local f="${queue[0]}"
    queue=("${queue[@]:1}")
    local has_nix_dep=0
    while IFS= read -r store_path; do
      [ -z "$store_path" ] && continue
      has_nix_dep=1
      local base dest
      base=$(basename "$store_path")
      dest="$lib_dir/$base"
      if [ -z "${seen[$base]:-}" ]; then
        cp "$store_path" "$dest"
        chmod u+w "$dest"
        seen[$base]=1
        queue+=("$dest")
      fi
    done < <(ldd "$f" | grep -o '/nix/store/[a-z0-9]\{32\}-[^ )]*' || true)
    if [ "$has_nix_dep" -eq 1 ]; then
      patchelf --set-rpath '$ORIGIN/../lib' "$f"
    fi
  done
}

if [[ "$(uname -s)" == "Darwin" ]]; then
  vendor_darwin
else
  vendor_linux
fi

echo 'Symlinking neovim'
ln -s "$nvim_bin" ~/bin/nvim
