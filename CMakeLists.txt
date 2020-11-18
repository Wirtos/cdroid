cmake_minimum_required(VERSION 3.10)
project(cdroid C)

set(CMAKE_C_STANDARD 99)

include(cmake/cdroid.cmake)

set(ndk_glue_dir ${ANDROID_NDK}/sources/android/native_app_glue)
add_library(cdroid SHARED src/main.c ${ndk_glue_dir}/android_native_app_glue.c)
target_include_directories(cdroid PRIVATE ${ndk_glue_dir})
target_link_libraries(cdroid log android)

set(keystore_file "${CMAKE_CURRENT_BINARY_DIR}/keystore.jks")
create_debug_keystore(${keystore_file})
pack_apk(cdroid "com.wirtos.awb" "awb" "latest"
        "${CMAKE_SOURCE_DIR}/android/AndroidManifest.xml.in"
        "${CMAKE_SOURCE_DIR}/android/assets"
        "${CMAKE_SOURCE_DIR}/android/res"
        "${keystore_file}"
        "androidkey" "password"
        ${CMAKE_CURRENT_BINARY_DIR}/result.apk)
