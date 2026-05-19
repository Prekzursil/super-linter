#!/usr/bin/env bash

set -euo pipefail

apk add --no-cache --virtual .chktex-build-deps \
  autoconf \
  automake \
  curl \
  gcc \
  git \
  libc-dev \
  libtool \
  make \
  ncurses-dev

# FIX 2026-11-17: git.savannah.gnu.org has been hard-down for extended
# windows (HTTP 500/504; the git-clone retry loop below exhausted itself on
# the Build and Test workflow repeatedly — runs 44133889720 etc.). Build from
# the PINNED upstream release tarball mirrored on deb.debian.org instead
# (Savannah's own download host serves the same file but shares the outage),
# verify it against a pinned SHA-256, and keep the git clone only as a
# fallback for the day the mirror is unreachable.
CHKTEX_VERSION="1.7.9"
CHKTEX_SHA256="df6ee31632a4f4a8e18849b804657e27e3d96deb3f237edbd25656415eb31195"
CHKTEX_TARBALL="chktex_${CHKTEX_VERSION}.orig.tar.gz"
CHKTEX_MIRROR="http://deb.debian.org/debian/pool/main/c/chktex"

if curl --retry 5 --retry-delay 5 --retry-all-errors -fsSL \
  -o "${CHKTEX_TARBALL}" "${CHKTEX_MIRROR}/${CHKTEX_TARBALL}" \
  && echo "${CHKTEX_SHA256}  ${CHKTEX_TARBALL}" | sha256sum -c -; then
  echo "Successfully fetched the chktex ${CHKTEX_VERSION} release tarball"
  tar -xzf "${CHKTEX_TARBALL}"
  cd "chktex-${CHKTEX_VERSION}"
else
  echo "Tarball fetch/verification failed; falling back to the git clone."
  RETRIES=5
  DELAY=5
  COUNT=0
  while [ "${COUNT}" -lt "${RETRIES}" ]; do
    if git clone https://git.savannah.gnu.org/git/chktex.git; then
      echo "Successfully cloned the chktex Git repository"
      RETRIES=0
      break
    fi
    echo "Error while cloning the chktex Git repository."
    ((COUNT = COUNT + 1))
    sleep "${DELAY}"
  done

  if [[ ! -d "./chktex/chktex" ]]; then
    echo "chktex directory doesn't exist."
    exit 1
  fi

  cd chktex/chktex
fi

sed -i 's/\[termcap termlib\]/[termcap termlib tinfo ncurses]/g' configure.ac
./autogen.sh --prefix=/usr/bin
./configure
make
install chktex /usr/bin

rm -rfv /chktex

apk del --no-network --purge .chktex-build-deps
