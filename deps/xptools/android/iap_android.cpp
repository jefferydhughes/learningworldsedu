//
//  iap_android.cpp
//  xptools
//
//  Created by Gaetan de Villele on 16/05/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

#include "iap.hpp"

bool vx::IAP::isAvailable() {
    // IAP is not available on Android for now
    return false;
}

vx::IAP::Purchase_SharedPtr vx::IAP::purchase(std::string productID,
                                              std::string verifyURL,
                                              const std::unordered_map<std::string, std::string>& headers,
                                              std::function<void(const Purchase_SharedPtr&)> callback) {
    return nullptr;
}

void vx::IAP::getProducts(const std::vector<std::string>& productIDs, std::function<void(std::unordered_map<std::string, Product> products)> callback) {
    std::unordered_map<std::string, vx::IAP::Product> products;
    callback(products);
}
