cmake_minimum_required(VERSION 3.22.1)
project("qfildroid_engine" CXX)

add_library(qfildroid_engine SHARED
    qfildroid_jni.cpp
    usb_transport.cpp
    sahara.cpp
    firehose.cpp)

target_compile_features(qfildroid_engine PRIVATE cxx_std_17)
target_compile_options(qfildroid_engine PRIVATE -Wall -Wextra)

find_library(log-lib log)
target_link_libraries(qfildroid_engine ${log-lib})
