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
add_library(cdroid SHARED src/main.c)
target_link_libraries(cdroid native_app_glue android ${log_lib})

# create a keystore file and use it when packaging apk
set(keystore_file "${CMAKE_CURRENT_BINARY_DIR}/keystore.jks")
create_debug_keystore(${keystore_file})
# tie packaging process to the cdroid target build
pack_apk(cdroid # target that declares anroid_main
        "com.wirtos.awb_app" "awb app" # android package name and app title
        "latest" # function will try to use latest build tools, can be a string like "30.0.1"
        android/AndroidManifest.xml.in # manifest to be configured (see cmake configure_file)
        android/assets # dir containing assets
        android/res # dir containing resources
        "${keystore_file}" "androidkey" "password" # default keystore alias and password values for debug keystore
        ${CMAKE_CURRENT_BINARY_DIR}/result.apk) # resulting apk file
