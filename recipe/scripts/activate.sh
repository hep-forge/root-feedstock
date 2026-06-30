#!/usr/bin/env bash

# ROOTSYS — backup and override with the conda prefix
if [ ! -z "${ROOTSYS+x}" ]; then
	export CONDA_BACKUP_ROOTSYS="${ROOTSYS}"
fi
export ROOTSYS="${CONDA_PREFIX}"

# ROOT_INCLUDE_PATH / ROOT_LIBRARY_PATH — a pre-existing ROOT installation
# (e.g. spack) may have these pointing at its own headers and libraries.
# Override them to the conda prefix so cling stays self-consistent; restore
# on deactivate.
if [ ! -z "${ROOT_INCLUDE_PATH+x}" ]; then
	export CONDA_BACKUP_ROOT_INCLUDE_PATH="${ROOT_INCLUDE_PATH}"
fi
export ROOT_INCLUDE_PATH="${CONDA_PREFIX}/include"

if [ ! -z "${ROOT_LIBRARY_PATH+x}" ]; then
	export CONDA_BACKUP_ROOT_LIBRARY_PATH="${ROOT_LIBRARY_PATH}"
fi
export ROOT_LIBRARY_PATH="${CONDA_PREFIX}/lib"

# CLING_MODULEMAP_FILES — if a system ROOT set this, cling picks it up and
# tries to load module maps that reference build-time PCM paths (e.g.
# .../conda-bld/.../work/build-dir/lib/Vc.pcm) causing "module file not
# found" errors.  Clear it so the conda ROOT's cling discovers its own
# modules from ROOTSYS; restore on deactivate.
if [ ! -z "${CLING_MODULEMAP_FILES+x}" ]; then
	export CONDA_BACKUP_CLING_MODULEMAP_FILES="${CLING_MODULEMAP_FILES}"
	unset CLING_MODULEMAP_FILES
fi
