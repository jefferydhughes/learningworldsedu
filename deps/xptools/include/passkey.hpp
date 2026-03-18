//
//  passkey.hpp
//  xptools
//
//  Created by Gaetan de Villele on 28/03/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

#pragma once

// C++
#include <functional>
#include <memory>
#include <string>

namespace vx {
namespace auth {

class PassKey {
  public:

    /// Passkey creation reponse
    class CreateResponse {
      public:
        // Constructors
        CreateResponse();
        CreateResponse(const std::string &credentialIDBase64,
                       const std::string &rawClientDataJSONBase64,
                       const std::string &rawAttestationObjectBase64);
        CreateResponse(const std::string &responseJSON);

        // Getters
        std::string getResponseJSON() const;

      private:
        std::string _credentialIDBase64;
        std::string _rawClientDataJSONBase64;
        std::string _rawAttestationObjectBase64;
        std::string _responseJSON;
    };

    /// Passkey login reponse

    class LoginResponse;
    typedef std::shared_ptr<LoginResponse> LoginResponse_SharedPtr;

    class LoginResponse {
      public:

        // Static methods
        static LoginResponse_SharedPtr fromJSON(const std::string &json);
        static LoginResponse_SharedPtr fromComponents(const std::string &credentialIDBase64,
                                                      const std::string &authenticatorDataBase64,
                                                      const std::string &rawClientDataJSONString,
                                                      const std::string &signatureBase64,
                                                      const std::string &userIDString);

        // Constructor
        LoginResponse();

        // Getters
        std::string getCredentialIDBase64() const;
        std::string getAuthenticatorDataBase64() const;
        std::string getRawClientDataJSONString() const;
        std::string getSignatureBase64() const;
        std::string getUserIDString() const;

      private:
        std::string _credentialIDBase64;
        std::string _authenticatorDataBase64;
        std::string _rawClientDataJSONString;
        std::string _signatureBase64;
        std::string _userIDString;
    };

    /// Type of callback function for passkey creation
    /// TODO: gaetan: use a shared pointer for CreateResponse like we do for LoginResponse
    typedef std::function<void(const CreateResponse &response, const std::string &error)>
        CreatePasskeyCallbackFunc;

    /// Type of callback function for passkey login
    /// `response` can be null if the response could not be parsed or if an error is provided
    typedef std::function<void(const LoginResponse_SharedPtr response, const std::string &error)>
        LoginWithPasskeyCallbackFunc;

    /// Returns true if PassKey is available on the device, false otherwise.
    static bool IsAvailable();

    static std::string createPasskey(const std::string &relyingPartyIdentifier,
                                     const std::string &challenge,
                                     const std::string &userID,
                                     const std::string &username,
                                     CreatePasskeyCallbackFunc callback);

    static std::string loginWithPasskey(const std::string &relyingPartyIdentifier,
                                        const std::string &challengeBytes,
                                        LoginWithPasskeyCallbackFunc callback);

#if defined(__VX_PLATFORM_ANDROID)

  public:

    /// Called by Kotlin
    static void onPasskeyCreateSuccess(const std::string &json);

    /// Called by Kotlin
    static void onPasskeyCreateFailure(const std::string &error);

    /// Called by Kotlin
    static void onPasskeyLoginSuccess(const std::string &json);

    /// Called by Kotlin
    static void onPasskeyLoginFailure(const std::string &error);

  private:

    /// Stored callback function for passkey creation
    static CreatePasskeyCallbackFunc _createPasskeyCallback;

    /// Stored callback function for passkey login
    static LoginWithPasskeyCallbackFunc _loginWithPasskeyCallback;

#endif
};

} // namespace auth
} // namespace vx
