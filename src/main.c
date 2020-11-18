#include <android_native_app_glue.h>
#include <android/log.h>
#include <android/asset_manager.h>
#include <stdlib.h>
#include <string.h>

#define APPNAME "AWB"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, APPNAME, __VA_ARGS__)
#define LOGA(cond, ...) __android_log_assert(cond, APPNAME, __VA_ARGS__)


void android_main(struct android_app *app) {
    char *asset_txt = NULL;

    AAsset *file = AAssetManager_open(app->activity->assetManager, "text.txt", AASSET_MODE_BUFFER);

    if (file) {
        size_t fileLength = AAsset_getLength(file);
        char *temp = malloc(fileLength + 1);
        memcpy(temp, AAsset_getBuffer(file), fileLength);
        temp[fileLength] = '\0';
        asset_txt = temp;
    }
    
    LOGI("HolyShit I did it!");
    LOGI("Asset \"text.txt\" data: %s", asset_txt ? asset_txt : "Not found");

    free(asset_txt);

    ANativeActivity_finish(app->activity);
}
