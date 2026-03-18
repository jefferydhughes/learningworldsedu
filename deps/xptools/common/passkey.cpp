//
//  passkey.cpp
//  xptools
//
//  Created by Gaetan de Villele on 28/03/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

#include "passkey.hpp"

#include "json.hpp"
#include "vxlog.h"
#include "encoding_base64.hpp"

namespace vx {
namespace auth {

// Type CreateResponse

// Default constructor
PassKey::CreateResponse::CreateResponse()
    : _credentialIDBase64(""), _rawClientDataJSONBase64(""), _rawAttestationObjectBase64(""),
      _responseJSON("") {}

// Constructor with individual parameters
PassKey::CreateResponse::CreateResponse(const std::string &credentialIDBase64,
                                        const std::string &rawClientDataJSONBase64,
                                        const std::string &rawAttestationObjectBase64) :
_credentialIDBase64(credentialIDBase64),
_rawClientDataJSONBase64(rawClientDataJSONBase64),
_rawAttestationObjectBase64(rawAttestationObjectBase64),
_responseJSON("") {}

// Constructor with JSON response
PassKey::CreateResponse::CreateResponse(const std::string &responseJSON) :
_credentialIDBase64(""),
_rawClientDataJSONBase64(""),
_rawAttestationObjectBase64(""),
_responseJSON(responseJSON) {}

// Getter for response JSON
// If the response JSON is not available, build it from the individual components
// Returns an empty string if the response JSON cannot be built
std::string PassKey::CreateResponse::getResponseJSON() const {
    // Return the response JSON if it is already available
    if (!_responseJSON.empty()) {
        return _responseJSON;
    }

    // Build JSON from individual components if not already available
    if (_credentialIDBase64.empty() || _rawClientDataJSONBase64.empty() ||
        _rawAttestationObjectBase64.empty()) {
        return "";
    }

    // Create the main JSON object
    cJSON *bodyJson = cJSON_CreateObject();
    vx::json::writeStringField(bodyJson, "id", _credentialIDBase64);
    vx::json::writeStringField(bodyJson, "rawId", _credentialIDBase64);
    vx::json::writeStringField(bodyJson, "type", "public-key");

    // Create the response child object
    cJSON *responseObj = cJSON_CreateObject();
    vx::json::writeStringField(responseObj, "clientDataJSON", _rawClientDataJSONBase64);
    vx::json::writeStringField(responseObj, "attestationObject", _rawAttestationObjectBase64);
    cJSON_AddItemToObject(bodyJson, "response", responseObj);

    char *s = cJSON_PrintUnformatted(bodyJson);
    const std::string bodyStr = std::string(s);
    free(s);
    s = nullptr;
    cJSON_Delete(bodyJson);

    return bodyStr;
}

// Type LoginResponse

// Static methods

PassKey::LoginResponse_SharedPtr PassKey::LoginResponse::fromJSON(const std::string &json) {

    // JSON example:
    // {
    //   "rawId": "5wSfysCsA6VtGy23-rQGWg",
    //   "authenticatorAttachment": "platform",
    //   "type": "public-key",
    //   "id": "5wSfysCsA6VtGy23-rQGWg",
    //   "response": {
    //     "clientDataJSON": "eyJ0eXBlIjoid2ViYXV0aG4uZ2V0IiwiY2hhbGxlbmdlIjoiWnpocFVucFliV3hOZUhKMk5sVlZjWEJFZHpCaVVubFdja1J4WVd0MWRFbyIsIm9yaWdpbiI6ImFuZHJvaWQ6YXBrLWtleS1oYXNoOmdwNWZick1NNTB1Z09qRnJNbXpycTZHVk0yc3JoWmhrZk1GZU5rRzlnRTQiLCJhbmRyb2lkUGFja2FnZU5hbWUiOiJjb20udm94b3dsLmJsaXAifQ",
    //     "authenticatorData": "3KMdhJMyhpStNvG1u6_Fyuubah6NVOCrhDOKgUOBILEdAAAAAA",
    //     "signature": "MEYCIQC6J374Y_H8dygxUsVeTmJSOkXyr-FIL_Ll1KhABZqVDgIhANrKTn5nSQOG_NCQcml_O_ovgzwwNR1vxqgIOt3D-3Lr",
    //     "userHandle": "NTIzMzQ5NjQtOTJjYS00Y2NjLTlmMjUtMjljYTg3NDQ4ZjIx"
    //   },
    //   "clientExtensionResults": {}
    // }

    // Notes
    // we need to decode clientDataJSON and userHandle

    // Parse the JSON response and extract the individual components
    cJSON *root = cJSON_Parse(json.c_str());
    if (root == nullptr) {
        return nullptr;
    }

    // Extract the credential ID from root level
    cJSON *id = cJSON_GetObjectItem(root, "id");
    if (id == nullptr || !cJSON_IsString(id)) {
        cJSON_Delete(root);
        return nullptr;
    }
    std::string credentialIDBase64 = id->valuestring;

    // Get the response object
    cJSON *responseObj = cJSON_GetObjectItem(root, "response");
    if (responseObj == nullptr || !cJSON_IsObject(responseObj)) {
        cJSON_Delete(root);
        return nullptr;
    }

    // Extract fields from the response object
    cJSON *authenticatorData = cJSON_GetObjectItem(responseObj, "authenticatorData");
    if (authenticatorData == nullptr || !cJSON_IsString(authenticatorData)) {
        cJSON_Delete(root);
        return nullptr;
    }
    std::string authenticatorDataBase64 = authenticatorData->valuestring;

    cJSON *clientDataJSON = cJSON_GetObjectItem(responseObj, "clientDataJSON");
    if (clientDataJSON == nullptr || !cJSON_IsString(clientDataJSON)) {
        cJSON_Delete(root);
        return nullptr;
    }
    const std::string rawClientDataJSONBase64 = clientDataJSON->valuestring;
    // decode (base64-url)
    std::string rawClientDataJSONString;
    std::string error = vx::encoding::base64::decode(rawClientDataJSONBase64,
                                                     rawClientDataJSONString,
                                                     vx::encoding::base64::Variant::URL);
    if (error.empty() == false) {
        vxlog_error("%s", error.c_str());
        return nullptr; // error
    }

    cJSON *signature = cJSON_GetObjectItem(responseObj, "signature");
    if (signature == nullptr || !cJSON_IsString(signature)) {
        cJSON_Delete(root);
        return nullptr;
    }
    std::string signatureBase64 = signature->valuestring;

    cJSON *userHandle = cJSON_GetObjectItem(responseObj, "userHandle");
    if (userHandle == nullptr || !cJSON_IsString(userHandle)) {
        cJSON_Delete(root);
        return nullptr;
    }
    const std::string userIDBase64 = userHandle->valuestring;
    std::string userIDString;
    error = vx::encoding::base64::decode(userIDBase64,
                                         userIDString,
                                         vx::encoding::base64::Variant::URL);
    if (error.empty() == false) {
        vxlog_error("%s", error.c_str());
        return nullptr; // error
    }

    cJSON_Delete(root);
    root = nullptr;

    // Create and return the LoginResponse object using the fromComponents method
    return fromComponents(credentialIDBase64,
                          authenticatorDataBase64,
                          rawClientDataJSONString,
                          signatureBase64,
                          userIDString);
}

PassKey::LoginResponse_SharedPtr PassKey::LoginResponse::fromComponents(
    const std::string &credentialIDBase64,
    const std::string &authenticatorDataBase64,
    const std::string &rawClientDataJSONString,
    const std::string &signatureBase64,
    const std::string &userIDString) {

    if (credentialIDBase64.empty() ||
        authenticatorDataBase64.empty() ||
        rawClientDataJSONString.empty() ||
        signatureBase64.empty() ||
        userIDString.empty()) {
        return nullptr;
    }

    // Build the JSON response
    PassKey::LoginResponse_SharedPtr response = std::make_shared<PassKey::LoginResponse>();
    response->_credentialIDBase64 = credentialIDBase64;
    response->_authenticatorDataBase64 = authenticatorDataBase64;
    response->_rawClientDataJSONString = rawClientDataJSONString;
    response->_signatureBase64 = signatureBase64;
    response->_userIDString = userIDString;

    return response;
}

// Default constructor
PassKey::LoginResponse::LoginResponse() {}

// Getters
std::string PassKey::LoginResponse::getCredentialIDBase64() const {
    return _credentialIDBase64;
}

std::string PassKey::LoginResponse::getAuthenticatorDataBase64() const {
    return _authenticatorDataBase64;
}

std::string PassKey::LoginResponse::getRawClientDataJSONString() const {
    return _rawClientDataJSONString;
}

std::string PassKey::LoginResponse::getSignatureBase64() const {
    return _signatureBase64;
}

std::string PassKey::LoginResponse::getUserIDString() const {
    return _userIDString;
}

} // namespace auth
} // namespace vx
