//
//  passkey_android.cpp
//  xptools
//
//  Created by Gaetan de Villele on 16/05/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

#include "passkey.hpp"

// C++
#include <cassert>

// android
#include <android/log.h>

// xptools
#include "JNIUtils.hpp"

//
// MARK: - Local functions' forward declarations -
//

// Returns an empty string on success, or an error message
std::string java_com_voxowl_tools_Passkey_createPasskey(const std::string &relyingPartyIdentifier,
                                                        const std::string &challenge,
                                                        const std::string &userID,
                                                        const std::string &username);

// Returns an empty string on success, or an error message
std::string java_com_voxowl_tools_Passkey_loginWithPasskey(const std::string &relyingPartyIdentifier,
                                                           const std::string &challengeBytes);

//
// MARK: - C++ implementation -
//

namespace vx {
namespace auth {

PassKey::CreatePasskeyCallbackFunc PassKey::_createPasskeyCallback = nullptr;
PassKey::LoginWithPasskeyCallbackFunc PassKey::_loginWithPasskeyCallback = nullptr;

// Returns true if passkey is available on the device, false otherwise
bool PassKey::IsAvailable() {

    // find Java/Kotlin function to call
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;
    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(&just_attached,
                                                           &methodInfo,
                                                           "com/voxowl/tools/Passkey",
                                                           "isAvailable",
                                                           "()Z")) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip JNI",
                            "Failed to get method info (%s)",
                            __func__);
        return false;
    }

    // JNI cleanup function
    auto cleanup = [&]() {
        methodInfo.env->DeleteLocalRef(methodInfo.classID);
        if (just_attached) {
            vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
        }
    };

    // call Java function
    jboolean result = methodInfo.env->CallStaticBooleanMethod(methodInfo.classID,
                                                              methodInfo.methodID);

    // check for JNI exceptions
    if (methodInfo.env->ExceptionCheck()) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip JNI",
                            "Exception occurred while calling (%s)",
                            __func__);
        methodInfo.env->ExceptionClear();
        cleanup();
        return false;
    }

    cleanup();
    return static_cast<bool>(result);
}

// Create a passkey using the native implementation.
// Returns an empty string on success or an error message on failure.
std::string PassKey::createPasskey(const std::string &relyingPartyIdentifier,
                                   const std::string &challenge,
                                   const std::string &userID,
                                   const std::string &username,
                                   CreatePasskeyCallbackFunc callback) {

    __android_log_print(
        ANDROID_LOG_DEBUG,
        "Blip",
        "🔑[C++][PassKey::createPasskey] rp: %s, challenge: %s, userID: %s, username: %s",
        relyingPartyIdentifier.c_str(),
        challenge.c_str(),
        userID.c_str(),
        username.c_str());

    // validate arguments
    if (relyingPartyIdentifier.empty()) {
        return "relying party identifier is empty";
    }
    if (challenge.empty()) {
        return "challenge argument is empty";
    }
    if (userID.empty()) {
        return "userID argument is empty";
    }
    if (username.empty()) {
        return "username argument is empty";
    }
    if (callback == nullptr) {
        return "callback argument is nullptr";
    }

    // make sure no callback is already stored
    if (PassKey::_createPasskeyCallback != nullptr) {
        return "a callback is already stored";
    }

    // store callback function
    PassKey::_createPasskeyCallback = callback;

    // call Kotlin function (async operation that will call the callback function)
    java_com_voxowl_tools_Passkey_createPasskey(relyingPartyIdentifier,
                                                challenge,
                                                userID,
                                                username);

    return ""; // success
}

// Called by Kotlin when the passkey creation is successful
void PassKey::onPasskeyCreateSuccess(const std::string& json) {
    // ensure a callback had been stored
    if (PassKey::_createPasskeyCallback == nullptr) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip xptools",
                            "🔑[PassKey::onPasskeyCreateSuccess] null callback");
        return;
    }

    // call callback
    PassKey::CreateResponse response = PassKey::CreateResponse(json);
    PassKey::_createPasskeyCallback(response, "");

    // reset callback
    PassKey::_createPasskeyCallback = nullptr;
}

// Called by Kotlin when the passkey creation fails
void PassKey::onPasskeyCreateFailure(const std::string& error) {
    // ensure a callback had been stored
    if (PassKey::_createPasskeyCallback == nullptr) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip xptools",
                            "🔑[PassKey::onPasskeyCreateFailure] null callback");
    }

    // call callback
    PassKey::_createPasskeyCallback(PassKey::CreateResponse(), error);

    // reset callback
    PassKey::_createPasskeyCallback = nullptr;
}

/// Returns an empty string on success or an error message on failure
std::string PassKey::loginWithPasskey(const std::string &relyingPartyIdentifier,
                                      const std::string &challengeBytes,
                                      LoginWithPasskeyCallbackFunc callback) {

    __android_log_print(
        ANDROID_LOG_DEBUG,
        "Blip",
        "🔑[C++][PassKey::loginWithPasskey] rp: %s, challenge: %s",
        relyingPartyIdentifier.c_str(),
        challengeBytes.c_str());

    // validate arguments
    if (relyingPartyIdentifier.empty()) {
        return "relying party identifier is empty";
    }
    if (challengeBytes.empty()) {
        return "challenge bytes argument is empty";
    }
    if (callback == nullptr) {
        return "callback argument is nullptr";
    }

    // make sure no callback is already stored
    if (PassKey::_loginWithPasskeyCallback != nullptr) {
        return "a login callback is already stored";
    }

    // store callback function
    PassKey::_loginWithPasskeyCallback = callback;

    // call Kotlin function (async operation that will call the callback function)
    std::string error = java_com_voxowl_tools_Passkey_loginWithPasskey(relyingPartyIdentifier,
                                                                       challengeBytes);
    
    if (!error.empty()) {
        // if there was an immediate error, reset the callback
        PassKey::_loginWithPasskeyCallback = nullptr;
        return error;
    }

    return ""; // success
}

// Called by Kotlin when the passkey login is successful
void PassKey::onPasskeyLoginSuccess(const std::string& json) {
    // ensure a callback had been stored
    if (PassKey::_loginWithPasskeyCallback == nullptr) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip xptools",
                            "🔑[PassKey::onPasskeyLoginSuccess] null callback");
        return;
    }

    // call callback
    LoginResponse_SharedPtr response = PassKey::LoginResponse::fromJSON(json);
    PassKey::_loginWithPasskeyCallback(response, "");

    // reset callback
    PassKey::_loginWithPasskeyCallback = nullptr;
}

// Called by Kotlin when the passkey login fails
void PassKey::onPasskeyLoginFailure(const std::string& error) {
    // ensure a callback had been stored
    if (PassKey::_loginWithPasskeyCallback == nullptr) {
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip xptools",
                            "🔑[PassKey::onPasskeyLoginFailure] null callback");
        return;
    }

    // call callback
    PassKey::_loginWithPasskeyCallback(nullptr, error);

    // reset callback
    PassKey::_loginWithPasskeyCallback = nullptr;
}

} // namespace auth
} // namespace vx

//
// MARK: - Local functions -
//

// C++ function calling Kotlin function to create a passkey
std::string java_com_voxowl_tools_Passkey_createPasskey(const std::string &relyingPartyIdentifier,
                                                        const std::string &challenge,
                                                        const std::string &userID,
                                                        const std::string &username) {
    std::string error;

    // Find Java/Kotlin function to call
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;
    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(
            &just_attached,
            &methodInfo,
            "com/voxowl/tools/Passkey",
            "createPasskey",
            "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/"
            "String;")) {
        error = "Failed to get createPasskey method info";
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip JNI",
                            "%s", error.c_str());
        return error;
    }

    jstring jRelyingPartyIdentifier = nullptr;
    jstring jChallenge = nullptr;
    jstring jUserID = nullptr;
    jstring jUsername = nullptr;

    // cleanup function
    auto cleanup = [&]() {
        if (jRelyingPartyIdentifier)
            methodInfo.env->DeleteLocalRef(jRelyingPartyIdentifier);
        if (jChallenge)
            methodInfo.env->DeleteLocalRef(jChallenge);
        if (jUserID)
            methodInfo.env->DeleteLocalRef(jUserID);
        if (jUsername)
            methodInfo.env->DeleteLocalRef(jUsername);
        methodInfo.env->DeleteLocalRef(methodInfo.classID);
        if (just_attached) {
            vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
        }
    };

    // Convert C strings to Java strings
    jRelyingPartyIdentifier = methodInfo.env->NewStringUTF(relyingPartyIdentifier.c_str());
    if (jRelyingPartyIdentifier == nullptr) {
        error = "Failed to create Java string for relying party identifier";
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip JNI",
                            "%s", error.c_str());
        cleanup();
        return error;
    }

    jChallenge = methodInfo.env->NewStringUTF(challenge.c_str());
    if (jChallenge == nullptr) {
        error = "Failed to create Java string for challenge";
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip JNI",
                            "%s", error.c_str());
        cleanup();
        return error;
    }

    jUserID = methodInfo.env->NewStringUTF(userID.c_str());
    if (jUserID == nullptr) {
        error = "Failed to create Java string for user ID";
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip JNI",
                            "%s", error.c_str());
        cleanup();
        return error;
    }

    jUsername = methodInfo.env->NewStringUTF(username.c_str());
    if (jUsername == nullptr) {
        error = "Failed to create Java string for username";
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip JNI",
                            "%s", error.c_str());
        cleanup();
        return error;
    }

    // Call Java function
    jstring result = (jstring)methodInfo.env->CallStaticObjectMethod(methodInfo.classID,
                                                                     methodInfo.methodID,
                                                                     jRelyingPartyIdentifier,
                                                                     jChallenge,
                                                                     jUserID,
                                                                     jUsername);

    // Check if there was an immediate error (non-null return value)
    if (result != nullptr) {
        error = vx::tools::string::convertJNIStringToCPPString(methodInfo.env, result);
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip JNI",
                            "Passkey creation error: %s",
                            error.c_str());
    }

    cleanup();
    return error;
}

// C++ function calling Kotlin function to login with a passkey
std::string java_com_voxowl_tools_Passkey_loginWithPasskey(const std::string &relyingPartyIdentifier,
                                                           const std::string &challengeBytes) {
    std::string error;

    // Find Java/Kotlin function to call
    bool just_attached = false;
    vx::tools::JniMethodInfo methodInfo;
    if (!vx::tools::JNIUtils::getInstance()->getMethodInfo(
            &just_attached,
            &methodInfo,
            "com/voxowl/tools/Passkey",
            "loginWithPasskey",
            "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;")) {
        error = "Failed to get loginWithPasskey method info";
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip JNI",
                            "%s", error.c_str());
        return error;
    }

    jstring jRelyingPartyIdentifier = nullptr;
    jstring jChallengeBytes = nullptr;

    // cleanup function
    auto cleanup = [&]() {
        if (jRelyingPartyIdentifier)
            methodInfo.env->DeleteLocalRef(jRelyingPartyIdentifier);
        if (jChallengeBytes)
            methodInfo.env->DeleteLocalRef(jChallengeBytes);
        methodInfo.env->DeleteLocalRef(methodInfo.classID);
        if (just_attached) {
            vx::tools::JNIUtils::getInstance()->getJavaVM()->DetachCurrentThread();
        }
    };

    // Convert C strings to Java strings
    jRelyingPartyIdentifier = methodInfo.env->NewStringUTF(relyingPartyIdentifier.c_str());
    if (jRelyingPartyIdentifier == nullptr) {
        error = "Failed to create Java string for relying party identifier";
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip JNI",
                            "%s", error.c_str());
        cleanup();
        return error;
    }

    jChallengeBytes = methodInfo.env->NewStringUTF(challengeBytes.c_str());
    if (jChallengeBytes == nullptr) {
        error = "Failed to create Java string for challenge bytes";
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip JNI",
                            "%s", error.c_str());
        cleanup();
        return error;
    }

    // Call Java function
    jstring result = (jstring)methodInfo.env->CallStaticObjectMethod(methodInfo.classID,
                                                                     methodInfo.methodID,
                                                                     jRelyingPartyIdentifier,
                                                                     jChallengeBytes);

    // Check if there was an immediate error (non-null return value)
    if (result != nullptr) {
        error = vx::tools::string::convertJNIStringToCPPString(methodInfo.env, result);
        __android_log_print(ANDROID_LOG_ERROR,
                            "Blip JNI",
                            "Login with Passkey error: %s",
                            error.c_str());
    }

    cleanup();
    return error;
}
