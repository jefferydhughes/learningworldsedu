//
//  iap.hpp
//  xptools
//
//  Created by Adrian Duermael on 05/10/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

#pragma once

// C++
#include <string>
#include <functional>
#include <memory>
#include <unordered_map>

namespace vx {
namespace IAP {

typedef struct Product {
    std::string id;
    std::string title;
    std::string description;
    float price;
    std::string currency;
    std::string currencySymbol;
    std::string displayPrice;
} Product;

class Purchase;
typedef std::shared_ptr<Purchase> Purchase_SharedPtr;
typedef std::weak_ptr<Purchase> Purchase_WeakPtr;

class Purchase final {

public:
    enum class Status {
        Pending,
        Success,
        Failed,
        Cancelled,
        InvalidProduct,
        SuccessNotVerified, // seen as success from client, but server couldn't verify it
    };

    static Purchase_SharedPtr make(const std::string& productID,
                                   std::string verifyURL,
                                   const std::unordered_map<std::string, std::string>& verifyRequestHeaders);

    Status status;
    std::string verifyURL;
    std::unordered_map<std::string, std::string> verifyRequestHeaders;
    std::string productID;
    std::string transactionID; // For successful purchases
    std::string receiptData;   // Base64-encoded receipt for server validation
    std::string errorMessage;  // For failed or cancelled purchases
    std::function<void(const Purchase_SharedPtr&)> callback;

private:

    Purchase(const std::string& productID,
             std::string verifyURL,
             const std::unordered_map<std::string, std::string>& verifyRequestHeaders) :
    status(Status::Pending),
    verifyURL(verifyURL),
    verifyRequestHeaders(verifyRequestHeaders),
    productID(productID),
    transactionID(""), // will be assigned later on
    receiptData(""), // will be assigned later on
    errorMessage(""), // will be assigned later on
    callback(nullptr)
    {}

};

bool isAvailable();
Purchase_SharedPtr purchase(std::string productID,
                            std::string verifyURL,
                            const std::unordered_map<std::string, std::string>& headers,
                            std::function<void(const Purchase_SharedPtr&)> callback);

void getProducts(const std::vector<std::string>& productIDs, std::function<void(std::unordered_map<std::string, Product> products)> callback);

} // namespace IAP
} // namespace vx
