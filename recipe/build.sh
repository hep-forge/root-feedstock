#!/bin/bash
set -x

mkdir build-scripts
cd build-scripts

cmake $RECIPE_DIR/scripts
cd ..

# rebuild afterimage ./configure script after patch
(cd graf2d/asimage/src/libAfterImage; autoconf)

export target_platform="linux-64"

export CXXFLAGS="${CXXFLAGS} -fno-merge-constants"
export CFLAGS="${CFLAGS} -fno-merge-constants"

INSTALL_SYSROOT=$(python -c "import os; rel = os.path.relpath('$CONDA_BUILD_SYSROOT', '$CONDA_PREFIX'); assert not rel.startswith('.'); print(os.path.join('$PREFIX', rel))")
CMAKE_PLATFORM_FLAGS+=("-DCMAKE_AR=${GCC_AR}")
CMAKE_PLATFORM_FLAGS+=("-DCLANG_DEFAULT_LINKER=${LD_GOLD}")
CMAKE_PLATFORM_FLAGS+=("-DDEFAULT_SYSROOT=${INSTALL_SYSROOT}")
CMAKE_PLATFORM_FLAGS+=("-DRT_LIBRARY=${INSTALL_SYSROOT}/usr/lib/librt.so")

# Fix finding X11 with CMake, copied from below with minor modifications
# https://github.com/Kitware/CMake/blob/e59e17c1c7059b7d0f02d6b12bc3094a2afee778/Modules/FindX11.cmake
cp "${RECIPE_DIR}/FindX11.cmake" "cmake/modules/"

# Hide symbols from LLVM/clang to avoid conflicts with other libraries
for lib_name in $(ls "${PREFIX}/lib" | grep -E 'lib(LLVM|clang).*\.a'); do
    export CXXFLAGS="${CXXFLAGS} -Wl,--exclude-libs,${lib_name}"
done
echo "CXXFLAGS is now '${CXXFLAGS}'"

export CFLAGS="${CFLAGS//-isystem /-I}"
export CPPFLAGS="${CPPFLAGS//-isystem /-I}"
export CXXFLAGS="${CXXFLAGS//-isystem /-I}"
export DEBUG_CFLAGS="${DEBUG_CFLAGS//-isystem /-I}"
export DEBUG_CXXFLAGS="${DEBUG_CXXFLAGS//-isystem /-I}"
export DEBUG_FFLAGS="${DEBUG_FFLAGS//-isystem /-I}"
export DEBUG_FORTRANFLAGS="${DEBUG_FORTRANFLAGS//-isystem /-I}"
export FFLAGS="${FFLAGS//-isystem /-I}"
export FORTRANFLAGS="${FORTRANFLAGS//-isystem /-I}"

Clang_DIR=${PREFIX}

declare -a CMAKE_PLATFORM_FLAGS
mkdir -p build-dir
cd build-dir

# Remove -std=c++XX from build ${CXXFLAGS}
CXXFLAGS=$(echo "${CXXFLAGS}" | sed -E 's@-std=c\+\+[^ ]+@@g')
export CXXFLAGS

# The cross-linux toolchain breaks find_file relative to the current file
# Patch up with sed
sed -i -E 's#(ROOT_TEST_DRIVER RootTestDriver.cmake PATHS \$\{THISDIR\} \$\{CMAKE_MODULE_PATH\} NO_DEFAULT_PATH)#\1 CMAKE_FIND_ROOT_PATH_BOTH#g' \
    ../cmake/modules/RootNewMacros.cmake

# The basics
if [ "${ROOT_CONDA_BUILD_TYPE-}" == "" ]; then
    CMAKE_PLATFORM_FLAGS+=("-DCMAKE_BUILD_TYPE=Release")
else
    CMAKE_PLATFORM_FLAGS+=("-DCMAKE_BUILD_TYPE=${ROOT_CONDA_BUILD_TYPE}")
fi
CMAKE_PLATFORM_FLAGS+=("-DCMAKE_INSTALL_PREFIX=${PREFIX}")
CMAKE_PLATFORM_FLAGS+=("-DCMAKE_PREFIX_PATH=${PREFIX}")

CMAKE_PLATFORM_FLAGS+=("-Dfail-on-missing=ON")
# TODO: Switch this on?
CMAKE_PLATFORM_FLAGS+=("-Dgnuinstall=OFF")
CMAKE_PLATFORM_FLAGS+=("-Drpath=ON")
CMAKE_PLATFORM_FLAGS+=("-Dshared=ON")
CMAKE_PLATFORM_FLAGS+=("-Dsoversion=ON")
CMAKE_PLATFORM_FLAGS+=("-DCMAKE_CXX_STANDARD=20")
CMAKE_PLATFORM_FLAGS+=("-DTBB_ROOT_DIR=${PREFIX}")

# Disable all of the builtins
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_cfitsio=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_davix=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_fftw3=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_freetype=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_ftgl=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_gl2ps=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_glew=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_gsl=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_lz4=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_lzma=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_nlohmannjson=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_openssl=OFF")
# TODO: Make external?
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_openui5=ON")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_pcre=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_tbb=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_unuran=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_vc=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_vdt=ON")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_xrootd=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_xxhash=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_zlib=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_zstd=OFF")

# Configure LLVM/Clang/Cling
if [ "${ROOT_CONDA_BUILTIN_CLANG-}" = "1" ]; then
    CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_llvm=ON")
    CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_clang=ON")
else
    CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_llvm=OFF")
    CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_clang=OFF")

    CMAKE_PLATFORM_FLAGS+=("-DLLVM_CONFIG=${Clang_DIR}/bin/llvm-config")
    CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_cling=ON")
    CMAKE_PLATFORM_FLAGS+=("-DCLING_BUILD_PLUGINS=ON")
    CMAKE_PLATFORM_FLAGS+=("-Dclad=ON")

    # Cling needs some minor patches to the LLVM sources, hackily apply them rather than rebuilding LLVM
    sed -i "s@LLVM_LINK_LLVM_DYLIB yes@LLVM_LINK_LLVM_DYLIB no@g" "${Clang_DIR}/lib/cmake/llvm/LLVMConfig.cmake"
fi

# Enable some vectorisation options
if [[ "${target_platform}" == *-64 ]]; then
    export CXXFLAGS="${CXXFLAGS} -march=nehalem"
fi
CMAKE_PLATFORM_FLAGS+=("-Dveccore=ON")
CMAKE_PLATFORM_FLAGS+=("-Dvc=ON")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_veccore=ON")

# Disable the Python bindings if we're building them in standalone mode
CMAKE_PLATFORM_FLAGS+=("-Dpyroot_legacy=OFF")
if [ "${ROOT_CONDA_BUILTIN_PYROOT-}" = "1" ]; then
    CMAKE_PLATFORM_FLAGS+=("-DPYTHON_EXECUTABLE=${PYTHON}")
    CMAKE_PLATFORM_FLAGS+=("-DCMAKE_INSTALL_PYTHONDIR=${SP_DIR}")
    CMAKE_PLATFORM_FLAGS+=("-Dpyroot=ON")
    CMAKE_PLATFORM_FLAGS+=("-Dtmva-pymva=ON")
else
    CMAKE_PLATFORM_FLAGS+=("-DPYTHON_EXECUTABLE=${PYTHON}")
    CMAKE_PLATFORM_FLAGS+=("-Dpyroot=OFF")
    CMAKE_PLATFORM_FLAGS+=("-Dtmva-pymva=OFF")
fi

# Disable the R bindings, should be made standalong like PyROOT
CMAKE_PLATFORM_FLAGS+=("-Dr=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dtmva-rmva=OFF")

# TMVA, the GPU part should be made standalone like PyROOT
CMAKE_PLATFORM_FLAGS+=("-Dtmva=ON")
CMAKE_PLATFORM_FLAGS+=("-Dtmva-cpu=ON")
CMAKE_PLATFORM_FLAGS+=("-Dtmva-gpu=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dcuda=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dcudnn=OFF")

# Enable other specific features
CMAKE_PLATFORM_FLAGS+=("-Dasimage=ON")
CMAKE_PLATFORM_FLAGS+=("-Ddataframe=ON")
CMAKE_PLATFORM_FLAGS+=("-Ddavix=ON")
CMAKE_PLATFORM_FLAGS+=("-Dfftw3=ON")
CMAKE_PLATFORM_FLAGS+=("-Dfitsio=ON")
CMAKE_PLATFORM_FLAGS+=("-Dgdml=ON")
CMAKE_PLATFORM_FLAGS+=("-Dgviz=ON")
CMAKE_PLATFORM_FLAGS+=("-Dhttp=ON")
CMAKE_PLATFORM_FLAGS+=("-Dimt=ON")
CMAKE_PLATFORM_FLAGS+=("-Dmathmore=ON")
CMAKE_PLATFORM_FLAGS+=("-Dmlp=ON")
CMAKE_PLATFORM_FLAGS+=("-Dopengl=ON")
CMAKE_PLATFORM_FLAGS+=("-Dpythia8=ON")
CMAKE_PLATFORM_FLAGS+=("-Droofit=ON")
CMAKE_PLATFORM_FLAGS+=("-Droot7=ON")
CMAKE_PLATFORM_FLAGS+=("-Dspectrum=ON")
CMAKE_PLATFORM_FLAGS+=("-Dsqlite=ON")
CMAKE_PLATFORM_FLAGS+=("-Dssl=ON")
CMAKE_PLATFORM_FLAGS+=("-Dtbb=ON")
CMAKE_PLATFORM_FLAGS+=("-Dvdt=ON")
CMAKE_PLATFORM_FLAGS+=("-Dwebgui=ON")
CMAKE_PLATFORM_FLAGS+=("-Dxml=ON")
CMAKE_PLATFORM_FLAGS+=("-Dxrootd=ON")

# On by default but disabled
CMAKE_PLATFORM_FLAGS+=("-Dgfal=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dpythia6=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dmysql=OFF")
CMAKE_PLATFORM_FLAGS+=("-Doracle=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dpgsql=OFF")

# Disable other specific features
CMAKE_PLATFORM_FLAGS+=("-Dalien=OFF")
CMAKE_PLATFORM_FLAGS+=("-Darrow=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dcefweb=OFF")
CMAKE_PLATFORM_FLAGS+=("-Ddcache=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dfcgi=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dfortran=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dgsl_shared=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dmacos_native=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dmonalisa=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dmpi=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dodbc=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dpythia6_nolink=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dqt5web=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dshadowpw=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dunuran=OFF")
CMAKE_PLATFORM_FLAGS+=("-During=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dvecgeom=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dvmc=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dxproofd=OFF")

# Developer only options
CMAKE_PLATFORM_FLAGS+=("-Dccache=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dcoverage=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dcxxmodules=OFF")
CMAKE_PLATFORM_FLAGS+=("-Ddev=OFF")
CMAKE_PLATFORM_FLAGS+=("-Ddistcc=OFF")
CMAKE_PLATFORM_FLAGS+=("-Djemalloc=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dlibcxx=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dmemory_termination=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dmemstat=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dtcmalloc=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dtest_distrdf_pyspark=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dwin_broken_tests=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dwinrtdebug=OFF")

# Platform specific options
if [[ "${target_platform}" == linux* ]]; then
    CMAKE_PLATFORM_FLAGS+=("-Dx11=ON")
fi

cmake .. $CMAKE_ARGS "${CMAKE_PLATFORM_FLAGS[@]}"

set +e
make -j2 #-j$(nproc)
ret=$?
if [ ! $ret -eq 0 ]; then
   for log_file in $(find . \( -name '*-configure-*.log' -o -name '*-build-*.log' -o -name '*-install-*.log' \)); do
     cat "$log_file"
   done
   exit $ret
fi

make install
