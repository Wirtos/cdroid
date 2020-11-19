# cdroid
Build android apps with a bit of CMake and C without even a line of java, kotlin or gradle!

### !!! Requires cmake >=3.18
```shell script
mkdir build && cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE="<NDK-PATH>/<NDK-VERSION>/build/cmake/android.toolchain.cmake" \
  -DANDROID_SDK="<SDK-PATH>" -DJAVA_HOME="<JDK-PATH>"
  -DANDROID_PLATFORM="android-30" -DANDROID_ABI=x86 
cmake --build . --target create_keystore cdroid
```
- -DANDROID_SDK (absolute path to android SDK root) can be omitted, the script then will try to use \
   ANDROID_HOME environment variable
- -DJAVA_HOME (absolute path to JDK root) can be omitted, the script will try to use JAVA_HOME environment variable instead
- https://developer.android.com/ndk/guides/cmake#variables
- create_keystore target can be ommited if you provide own keystore file in the CMakeLists.txt
