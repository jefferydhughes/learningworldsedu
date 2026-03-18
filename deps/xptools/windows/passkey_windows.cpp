//
//  passkey_windows.cpp
//  xptools
//
//  Created by Gaetan de Villele on 16/05/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

#include "passkey.hpp"

bool vx::auth::PassKey::IsAvailable() {
    return false;
}

std::string vx::auth::PassKey::createPasskey(const std::string &relyingPartyIdentifier,
                                             const std::string &challenge,
                                             const std::string &userID,
                                             const std::string &username,
                                             CreatePasskeyCallbackFunc callback) {
    return "not implemented";
}

std::string vx::auth::PassKey::loginWithPasskey(const std::string& relyingPartyIdentifier,
                                                const std::string& challengeBytes,
                                                LoginWithPasskeyCallbackFunc callback) {
    return "not implemented";
}
