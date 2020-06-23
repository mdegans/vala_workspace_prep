#!/bin/bash

# Copyright (C) 2020 Michael de Gans
# 
# This file is part of install_newest_vala.
# 
# install_newest_vala is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# install_newest_vala is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with install_newest_vala.  If not, see <http://www.gnu.org/licenses/>.

set -ex

# attention: this gets recursively deleted on cleanup, so don't point it at ~:
readonly BUILD_DIR="/tmp/vala_build"
# change this if you have a good reason for it:
readonly PREFIX="/usr/local"
# change these when newer versions are released
readonly VALA_VER="0.48.6"
readonly LANG_SERV_VER="tegra-latest"

function cleanup () {
  rm -rf "$BUILD_DIR"
}

function ensure_build_dir () {
  mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
}

function install_deps () {
  sudo apt-get update && sudo apt-get install -y --no-install-recommends \
    autoconf \
    autoconf-archive \
    bison \
    build-essential \
    flex \
    git \
    graphviz \
    libgee-0.8-dev \
    libglib2.0-dev \
    libgraphviz-dev \
    libjsonrpc-glib-1.0-dev \
    libtool \
    ninja-build \
    python3-pip \
    python3-setuptools
  # because vala-language-server needs a recent version of meson because
  # of use of compiler object on line 10 of main meson.build
  pip3 install --upgrade meson
}

function fetch_source () {
  ensure_build_dir

  git clone --depth 1 \
    https://gitlab.gnome.org/Archive/vala-bootstrap.git
  git clone --depth 1 --branch "$VALA_VER" \
    https://gitlab.gnome.org/GNOME/vala.git
  git clone --depth 1 --branch "$LANG_SERV_VER" \
    https://github.com/mdegans/vala-language-server.git
}

function bootstrap () {
  ensure_build_dir

  local VALAC=/no-valac

  echo "bootstrapping vala"

  cd vala-bootstrap
  touch */*.stamp
  ./configure --prefix="$BUILD_DIR/vala-bootstrap"
  make -j"$(nproc)"
}

function build_vala () {
  ensure_build_dir

  cd vala
  VALAC="$BUILD_DIR/vala-bootstrap/compiler/valac" ./autogen.sh --prefix="$PREFIX"
  make -j"$(nproc)"
  sudo make install
  sudo ldconfig
}

function build_lang_server () {
  ensure_build_dir

  cd vala-language-server
  mkdir build && cd build
  # --prefix is the "right" way to do this
  meson -Dprefix="$PREFIX" ..
  ninja
  sudo ninja install
  sudo ldconfig
}

function main () {
  cleanup
  install_deps
  fetch_source
  bootstrap
  build_vala
  build_lang_server
  cleanup
}

main
