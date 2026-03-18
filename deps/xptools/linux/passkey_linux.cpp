//
//  passkey_linux.cpp
//  xptools
//
//  Created by Gaetan de Villele on 23/05/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

#include "passkey.hpp"

/// Returns true if PassKey is available on the current platform, false otherwise
bool vx::auth::PassKey::IsAvailable() {
    return false; // not available on Linux
}

/// Returns an empty string on success or an error message on failure
std::string vx::auth::PassKey::createPasskey(const std::string& relyingPartyIdentifier,
                                             const std::string& challenge,
                                             const std::string& userID,
                                             const std::string& username,
                                             CreatePasskeyCallbackFunc callback) {
    return "not implemented"; // error
}

/// Returns an empty string on success or an error message on failure
std::string vx::auth::PassKey::loginWithPasskey(const std::string& relyingPartyIdentifier,
                                                const std::string& challengeBytes,
                                                LoginWithPasskeyCallbackFunc callback) {
    return "not implemented"; // error
}
