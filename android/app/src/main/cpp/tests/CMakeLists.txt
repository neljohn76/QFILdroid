cmake_minimum_required(VERSION 3.16)
project(qfildroid_engine_tests CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(engine_tests
    test_main.cpp
    sahara_tests.cpp
    firehose_tests.cpp
    ../sahara.cpp
    ../firehose.cpp
    ../usb_transport.cpp)

target_include_directories(engine_tests PRIVATE ..)
target_compile_options(engine_tests PRIVATE -Wall -Wextra -Werror)
