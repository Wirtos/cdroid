cmake_minimum_required(VERSION 3.10)
project(cdroid C)

set(CMAKE_C_STANDARD 99)

# cmake module with pack_apk and create[_debug]_keystore
include(cmake/cdroid.cmake)
# ANDROID_NDK is a variable declared by NDK cmake toolchain file

set(ndk_glue_dir ${ANDROID_NDK}/sources/android/native_app_glue/)
add_library(native_app_glue STATIC "${ndk_glue_dir}/android_native_app_glue.c")
target_include_directories(native_app_glue PUBLIC ${ndk_glue_dir})

find_library(log_lib log REQUIRED)

# we use add_library instead of add_executable for android
add_library(cdroid SHARED src/main.c ${ndk_glue_dir}/android_native_app_glue.c)
target_link_libraries(cdroid native_app_glue android ${log_lib})

set(keystore_file "${CMAKE_CURRENT_BINARY_DIR}/keystore.jks")
create_debug_keystore(${keystore_file})
pack_apk(cdroid "com.wirtos.awb_app" "awb app"
        "latest"
        android/AndroidManifest.xml.in
        android/assets
        android/res
        "${keystore_file}" "androidkey" "password" # default values for debug keystore
        ${CMAKE_CURRENT_BINARY_DIR}/result.apk)
