cmake_minimum_required(VERSION 3.10)
project(cdroid C)

function(d msg)
    message(STATUS ${msg})
endfunction()

set(CMAKE_C_STANDARD 99)

set(BANDROID_BUILD_TOOLS "${ANDROID_SDK}/build-tools/${BANDROID_BUILD_TOOLS_VERSION}")
set(BANDROID_APP_NAME "AndroidWithoutBloat")
set(BANDROID_PACKAGE "org.wirtos")
set(BANDROID_APK_SOURCES_DIR "${CMAKE_SOURCE_DIR}/android")
set(JDK_TOOLS_DIR "$ENV{JAVA_HOME}/bin")
file(TO_CMAKE_PATH ${JDK_TOOLS_DIR} JDK_TOOLS_DIR)
set(BANDROID_APK_STRUCT_DIR "${CMAKE_CURRENT_BINARY_DIR}/apk")
option(BANDROID_DEBUGGABLE "Wheter to allow debugging of the resulting apk" OFF)
if (BANDROID_DEBUGGABLE)
    set(BANDROID_DEBUGGABLE true)
else ()
    set(BANDROID_DEBUGGABLE false)
endif ()

configure_file(android/AndroidManifest.xml.in ${CMAKE_CURRENT_BINARY_DIR}/AndroidManifest.xml)
file(MAKE_DIRECTORY ${BANDROID_APK_STRUCT_DIR}/lib/${ANDROID_ABI})

d(${CMAKE_C_COMPILER})
d(${ANDROID_NDK})
d(${ANDROID_SDK})
d(${ANDROID_ABI})
d(${ANDROID_PLATFORM})
d(${BANDROID_BUILD_TOOLS})
d(${JDK_TOOLS_DIR})

add_library(cdroid SHARED src/main.c ${ANDROID_NDK}/sources/android/native_app_glue/android_native_app_glue.c)
target_include_directories(cdroid PRIVATE ${ANDROID_NDK}/sources/android/native_app_glue)
target_link_libraries(cdroid log android)
set_target_properties(cdroid PROPERTIES OUTPUT_NAME ${BANDROID_APP_NAME})


add_custom_target(pack_apk ALL
        COMMAND ${CMAKE_COMMAND} -E copy
        $<TARGET_FILE:cdroid>
        ${BANDROID_APK_STRUCT_DIR}/lib/${ANDROID_ABI}

        COMMAND ${BANDROID_BUILD_TOOLS}/aapt package
        -f
        -F ${CMAKE_CURRENT_BINARY_DIR}/temp.apk
        -M ${CMAKE_CURRENT_BINARY_DIR}/AndroidManifest.xml
        -I ${ANDROID_SDK}/platforms/${ANDROID_PLATFORM}/android.jar
        -A ${BANDROID_APK_SOURCES_DIR}/assets
        -S ${BANDROID_APK_SOURCES_DIR}/res
        --target-sdk-version ${ANDROID_PLATFORM_LEVEL}
        ${BANDROID_APK_STRUCT_DIR}

        COMMAND ${BANDROID_BUILD_TOOLS}/zipalign
        -f
        -p 4
        ${CMAKE_CURRENT_BINARY_DIR}/temp.apk
        ${CMAKE_CURRENT_BINARY_DIR}/temp_aligned.apk

        COMMENT "Copying library to the corresponding ABI directory\nPacking android file with aapt\nAligning apk file"
        )

add_dependencies(pack_apk cdroid)

set(BANDROID_KEYSTORE_FILE "${CMAKE_CURRENT_BINARY_DIR}/keystore.jks")
set(BANDROID_ALIAS_NAME "androidkey")
set(BANDROID_STOREPASS "password")
set(BANDROID_KEYSTORE_DNAME "CN=example.com, OU=ID, O=Example, L=Doe, S=John, C=GB")


add_custom_target(create_keystore
        COMMAND ${JDK_TOOLS_DIR}/keytool
        -genkey
        -keystore ${BANDROID_KEYSTORE_FILE}
        -alias ${BANDROID_ALIAS_NAME}
        -keyalg RSA
        -keysize 2048
        -validity 10000
        -storepass ${BANDROID_STOREPASS}
        -keypass ${BANDROID_STOREPASS}
        -dname \"${BANDROID_KEYSTORE_DNAME}\"

        COMMENT "No keystore file provided, generating a new one")

if (NOT EXISTS ${BANDROID_KEYSTORE_FILE})
    message(WARNING "Can't find a keystore file: ${BANDROID_KEYSTORE_FILE}, build create_keystore target first")
endif ()


add_custom_target(sign_apk ALL
        BYPRODUCTS ${CMAKE_CURRENT_BINARY_DIR}/temp_aligned_signed.apk

        COMMAND ${BANDROID_BUILD_TOOLS}/apksigner sign
        --ks ${BANDROID_KEYSTORE_FILE}
        --ks-key-alias ${BANDROID_ALIAS_NAME}
        --ks-pass pass:${BANDROID_STOREPASS}
        --out ${CMAKE_CURRENT_BINARY_DIR}/temp_aligned_signed.apk
        ${CMAKE_CURRENT_BINARY_DIR}/temp_aligned.apk

        COMMENT "Signing apk file")
add_dependencies(sign_apk pack_apk)