cmake_minimum_required(VERSION 3.10)

project(CondaEnv)

set(PKG_NAME $ENV{PKG_NAME})
set(PKG_VERSION $ENV{PKG_VERSION})

set(RECIPE_DIR $ENV{RECIPE_DIR})
set(SRC_DIR $ENV{SRC_DIR})
set(PREFIX $ENV{PREFIX})

execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory "${PREFIX}/etc/conda/activate.d")
execute_process(COMMAND ${CMAKE_COMMAND} -E make_directory "${PREFIX}/etc/conda/deactivate.d")

configure_file(${RECIPE_DIR}/scripts/activate.sh.in
               "${PREFIX}/etc/conda/activate.d/${PKG_NAME}_activate.sh" @ONLY)

configure_file(${RECIPE_DIR}/scripts/deactivate.sh.in
               "${PREFIX}/etc/conda/deactivate.d/${PKG_NAME}_deactivate.sh" @ONLY)
