//
//  iap.cpp
//  xptools
//
//  Created by Adrian Duermael on 05/14/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

#include "iap.hpp"

vx::IAP::Purchase_SharedPtr vx::IAP::Purchase::make(const std::string& productID,
                                                    std::string verifyURL,
                                                    const std::unordered_map<std::string, std::string>& verifyRequestHeaders) {
    Purchase_SharedPtr p(new Purchase(productID, verifyURL, verifyRequestHeaders));
    return p;
}
