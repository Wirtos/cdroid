cmake_minimum_required(VERSION 3.10)

function(d msg)
    message(STATUS ${msg})
endfunction()

function(create_keystore alias_name password dname out)
    set(BANDROID_ALIAS_NAME ${alias_name})
    set(BANDROID_STOREPASS ${password})
    set(BANDROID_KEYSTORE_DNAME ${dname})
    set(BANDROID_KEYSTORE_FILE ${out})
    if (DEFINED JAVA_HOME)
        set(JDK_TOOLS_DIR "${JAVA_HOME}/bin")
    elseif (DEFINED ENV{JAVA_HOME})
        set(JDK_TOOLS_DIR "$ENV{JAVA_HOME}/bin")
    else ()
        message(FATAL_ERROR "Can't find keytool from JDK, \
        set JAVA_HOME variable in cmake or add it to PATH")
    endif ()

    add_custom_command(
            OUTPUT ${BANDROID_KEYSTORE_FILE}
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
            COMMENT "Generating keystore")

    add_custom_target(
            create_keystore ALL
            DEPENDS ${BANDROID_KEYSTORE_FILE}
    )
endfunction()

function(create_debug_keystore out)
    create_keystore("androidkey" "password" "CN=example.com, OU=ID, O=Example, L=Doe, S=John, C=GB" ${out})
endfunction()

function(pack_apk main_target package_name app_name
        build_tools_version
        manifest assets_dir resources_dir
        keystore_file keystore_alias keystore_pass
        out)

    if (NOT DEFINED BANDROID_DEBUG)
        if (CMAKE_BUILD_TYPE MATCHES DEBUG)
            set(BANDROID_DEBUG true)
        else ()
            set(BANDROID_DEBUG false)
        endif ()
    else ()
        if (BANDROID_DEBUG)
            set(BANDROID_DEBUG true)
        else ()
            set(BANDROID_DEBUG false)
        endif ()
    endif ()

    set(BANDROID_PACKAGE_NAME ${package_name})
    set(BANDROID_APP_NAME ${app_name})

    if (${build_tools_version} STREQUAL "latest")
        # todo: find latest build tools available
        message(FATAL_ERROR "Not implemented")
    else ()
        set(BANDROID_BUILD_TOOLS "${ANDROID_SDK}/build-tools/${build_tools_version}")
    endif ()


    set(BANDROID_APK_STRUCT_DIR "${CMAKE_CURRENT_BINARY_DIR}/apk")
    file(MAKE_DIRECTORY ${BANDROID_APK_STRUCT_DIR}/lib/${ANDROID_ABI})

    set(BANDROID_MANIFEST ${CMAKE_CURRENT_BINARY_DIR}/AndroidManifest.xml)
    set(BANDROID_PLATFORMS_DIR ${ANDROID_SDK}/platforms/)

    configure_file(${manifest} ${BANDROID_MANIFEST})


    #    get_target_property(OUT Target LINK_LIBRARIES)

    if (NOT EXISTS "${BANDROID_PLATFORMS_DIR}/${ANDROID_PLATFORM}")
        message(FATAL_ERROR "Corresponding ANDROID_PLATFORM \"${ANDROID_PLATFORM}\" not found in ${BANDROID_PLATFORMS_DIR}")
    endif ()
    d(${CMAKE_C_COMPILER})
    d(${ANDROID_NDK})
    d(${ANDROID_SDK})
    d(${ANDROID_ABI})
    d(${ANDROID_PLATFORM})
    d(${BANDROID_BUILD_TOOLS})

    add_custom_command(
            TARGET ${main_target}
            POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy
            $<TARGET_FILE:cdroid>
            ${BANDROID_APK_STRUCT_DIR}/lib/${ANDROID_ABI}/${BANDROID_APP_NAME}.so

            COMMAND ${BANDROID_BUILD_TOOLS}/aapt package
            -f
            -F ${CMAKE_CURRENT_BINARY_DIR}/temp.apk
            -M ${BANDROID_MANIFEST}
            -I ${BANDROID_PLATFORMS_DIR}/${ANDROID_PLATFORM}/android.jar
            -A ${assets_dir}
            -S ${resources_dir}
            --target-sdk-version ${ANDROID_PLATFORM_LEVEL}
            ${BANDROID_APK_STRUCT_DIR}

            COMMAND ${BANDROID_BUILD_TOOLS}/zipalign
            -f
            -p 4
            ${CMAKE_CURRENT_BINARY_DIR}/temp.apk
            ${CMAKE_CURRENT_BINARY_DIR}/temp_aligned.apk

            COMMENT "Copying library to the corresponding ABI directory\nPacking android file with aapt\nAligning apk file"
    )

    if (NOT EXISTS ${keystore_file})
        message(WARNING "Can't find a keystore file: ${keystore_file}, build create_keystore target first")
    endif ()

    add_custom_command(
            TARGET ${main_target}
            POST_BUILD
            COMMAND ${BANDROID_BUILD_TOOLS}/apksigner sign
            --ks ${keystore_file}
            --ks-key-alias ${keystore_alias}
            --ks-pass pass:${keystore_pass}
            --out ${out}
            ${CMAKE_CURRENT_BINARY_DIR}/temp_aligned.apk

            DEPENDS
            ${keystore_file}
            COMMENT "Signing apk file"
    )
endfunction()