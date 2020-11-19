cmake_minimum_required(VERSION 3.18)

function(d msg)
    message(STATUS ${msg})
endfunction()

function(create_keystore keystore_alias keystore_pass keystore_dname out_file)
    get_filename_component(out_file "${out_file}" ABSOLUTE)
    if (DEFINED JAVA_HOME)
        set(JDK_TOOLS_DIR "${JAVA_HOME}/bin")
    elseif (DEFINED ENV{JAVA_HOME})
        set(JDK_TOOLS_DIR "$ENV{JAVA_HOME}/bin")
    else ()
        message(FATAL_ERROR "Can't find keytool from JDK, \
        set JAVA_HOME variable in cmake or add it to PATH")
    endif ()
    file(TO_CMAKE_PATH ${JDK_TOOLS_DIR} JDK_TOOLS_DIR)

    add_custom_command(
            OUTPUT ${out_file}
            COMMAND ${JDK_TOOLS_DIR}/keytool
            -genkey
            -keystore ${out_file}
            -alias ${keystore_alias}
            -keyalg RSA
            -keysize 2048
            -validity 10000
            -storepass ${keystore_pass}
            -keypass ${keystore_pass}
            -dname ${keystore_dname}

            VERBATIM
            COMMENT "Generating keystore")

    add_custom_target(
            create_keystore
            DEPENDS ${out_file}
    )
endfunction()

function(create_debug_keystore out_file)
    create_keystore("androidkey" "password" "CN=example.com, OU=ID, O=Example, L=Doe, S=John, C=GB" ${out_file})
endfunction()

function(pack_apk main_target package_name app_name
        build_tools_version
        manifest assets_dir resources_dir
        keystore_file keystore_alias keystore_pass
        out_file)

    get_filename_component(assets_dir "${assets_dir}" ABSOLUTE)
    get_filename_component(resources_dir "${resources_dir}" ABSOLUTE)
    get_filename_component(keystore_file "${keystore_file}" ABSOLUTE)
    get_filename_component(out_file "${out_file}" ABSOLUTE)

    if (NOT DEFINED BANDROID_DEBUG)
        if (CMAKE_BUILD_TYPE MATCHES "Debug")
            set(app_debug true)
        else ()
            set(app_debug false)
        endif ()
    else ()
        if (BANDROID_DEBUG)
            set(app_debug true)
        else ()
            set(app_debug false)
        endif ()
    endif ()

    if (DEFINED ANDROID_SDK)
        # do nothing for now
    elseif (DEFINED ENV{ANDROID_HOME})
        set(ANDROID_SDK "$ENV{ANDROID_HOME}")
    else ()
        message(FATAL_ERROR "ANDROID_SDK cmake or ANDROID_HOME environment variable is not defined, \
        define either one of those so it'd point to android sdk root")
    endif ()
    file(TO_CMAKE_PATH "${ANDROID_SDK}" ANDROID_SDK)

    if (${build_tools_version} STREQUAL "latest")
        file(GLOB BANDROID_BUILD_TOOLS_DIRS "${ANDROID_SDK}/build-tools/*")
        list(FILTER BANDROID_BUILD_TOOLS_DIRS INCLUDE REGEX "([0-9]+\\.[0-9]+\\.[0-9]+)")
        list(LENGTH BANDROID_BUILD_TOOLS_DIRS LEN)
        if (NOT LEN)
            message(FATAL_ERROR "Can't find any build tools directory, \
            download them as \"Android SDK Build-Tools\" in SDK manager")
        endif ()
        list(SORT BANDROID_BUILD_TOOLS_DIRS COMPARE NATURAL ORDER DESCENDING)
        list(GET BANDROID_BUILD_TOOLS_DIRS 0 BANDROID_BUILD_TOOLS)
        unset(BANDROID_BUILD_TOOLS_DIRS)
        unset(LEN)
    else ()
        set(BANDROID_BUILD_TOOLS "${ANDROID_SDK}/build-tools/${build_tools_version}")
    endif ()

    if (NOT EXISTS ${BANDROID_BUILD_TOOLS})
        message(FATAL_ERROR "Invalid build tools version specified")
    endif ()

    set(BANDROID_APK_ABI_DIR "${CMAKE_CURRENT_BINARY_DIR}/apk")
    file(MAKE_DIRECTORY "${BANDROID_APK_ABI_DIR}/lib/${ANDROID_ABI}")

    set(BANDROID_MANIFEST "${CMAKE_CURRENT_BINARY_DIR}/AndroidManifest.xml")
    set(BANDROID_PLATFORMS_DIR "${ANDROID_SDK}/platforms/")

    configure_file(${manifest} ${BANDROID_MANIFEST})

    if (NOT EXISTS "${BANDROID_PLATFORMS_DIR}/${ANDROID_PLATFORM}")
        message(FATAL_ERROR "Corresponding ANDROID_PLATFORM \"${ANDROID_PLATFORM}\" \
        not found in ${BANDROID_PLATFORMS_DIR}, please see \
        https://developer.android.com/ndk/guides/cmake#android_platform")
    endif ()

    d("Using ANDROID_NDK: ${ANDROID_NDK}")
    d("Using ANDROID_SDK: ${ANDROID_SDK}")
    d("Using ANDROID_ABI: ${ANDROID_ABI}")
    d("Using ANDROID_PLATFORM: ${ANDROID_PLATFORM}")
    d("Using build tools: ${BANDROID_BUILD_TOOLS}")

    add_custom_command(
            TARGET ${main_target}
            POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy
            $<TARGET_FILE:cdroid>
            ${BANDROID_APK_ABI_DIR}/lib/${ANDROID_ABI}/lib${app_name}.so

            COMMAND ${BANDROID_BUILD_TOOLS}/aapt package
            -f
            -F ${CMAKE_CURRENT_BINARY_DIR}/temp.apk
            -M ${BANDROID_MANIFEST}
            -I ${BANDROID_PLATFORMS_DIR}/${ANDROID_PLATFORM}/android.jar
            -A ${assets_dir}
            -S ${resources_dir}
            --target-sdk-version ${ANDROID_PLATFORM_LEVEL}
            ${BANDROID_APK_ABI_DIR}

            COMMAND ${BANDROID_BUILD_TOOLS}/zipalign
            -f
            -p 4
            ${CMAKE_CURRENT_BINARY_DIR}/temp.apk
            ${CMAKE_CURRENT_BINARY_DIR}/temp_aligned.apk

            VERBATIM
            COMMENT "Copying library to the corresponding ABI directory | Packing apk file with aapt | Aligning apk file"
    )

    if (NOT EXISTS ${keystore_file})
        message(WARNING "Can't find a keystore file: ${keystore_file}, \
        build create_keystore target first or provide a valid keystore file path")
    endif ()

    add_custom_command(
            TARGET ${main_target}
            POST_BUILD
            COMMAND ${BANDROID_BUILD_TOOLS}/apksigner sign
            --ks ${keystore_file}
            --ks-key-alias ${keystore_alias}
            --ks-pass pass:${keystore_pass}
            --out ${out_file}
            ${CMAKE_CURRENT_BINARY_DIR}/temp_aligned.apk

            VERBATIM
            COMMENT "Signing apk file"
    )
endfunction()