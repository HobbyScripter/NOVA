cmake_minimum_required(VERSION 3.20)
project(nova-compositor VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../desktop/libnova/include
)

set(SOURCES
    src/main.cpp
    src/nova_compositor.cpp
)

add_executable(nova-compositor ${SOURCES})

# Installation target
install(TARGETS nova-compositor DESTINATION bin)
