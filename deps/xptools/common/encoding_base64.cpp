//
//  encoding_base64.cpp
//  xptools
//
//  Created by Gaetan de Villele on 02/06/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

#include "encoding_base64.hpp"

// C++
#include <algorithm>
#include <cstdint>

//
// Based on:
// https://gist.githubusercontent.com/tomykaira/f0fd86b6c73063283afe550bc5d77594/raw/dceb7af2f73afb7aae20322cca04f27331d2e16a/Base64.h
//

namespace vx {
namespace encoding {
namespace base64 {

// Encode a string to base64 (no padding)
std::string encode(const std::string &data, const Variant variant) {
    static constexpr char sEncodingTable[] = {
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
        'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
        'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
        'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/'};

    size_t in_len = data.size();
    size_t out_len = 4 * ((in_len + 2) / 3);
    std::string ret(out_len, '\0');
    size_t i;
    char *p = const_cast<char *>(ret.c_str());

    for (i = 0; in_len > 2 && i < in_len - 2; i += 3) {
        *p++ = sEncodingTable[(data[i] >> 2) & 0x3F];
        *p++ = sEncodingTable[((data[i] & 0x3) << 4) |
                              ((int)(data[i + 1] & 0xF0) >> 4)];
        *p++ = sEncodingTable[((data[i + 1] & 0xF) << 2) |
                              ((int)(data[i + 2] & 0xC0) >> 6)];
        *p++ = sEncodingTable[data[i + 2] & 0x3F];
    }

    if (i < in_len) {

        // add padding
        *p++ = sEncodingTable[(data[i] >> 2) & 0x3F];
        if (i == (in_len - 1)) {
            *p++ = sEncodingTable[((data[i] & 0x3) << 4)];
            *p++ = '=';
        } else {
            *p++ = sEncodingTable[((data[i] & 0x3) << 4) |
                                  ((int)(data[i + 1] & 0xF0) >> 4)];
            *p++ = sEncodingTable[((data[i + 1] & 0xF) << 2)];
        }
        *p++ = '=';
    }

    // If base64 "URL" encoding has been requested,
    // remove any padding and replace '+' with '-' and '/' with '_'
    if (variant == Variant::URL) {
        // no padding, resize the string to the correct size
        while (ret.back() == '=') {
            ret.pop_back();
        }
        std::replace(ret.begin(), ret.end(), '+', '-');
        std::replace(ret.begin(), ret.end(), '/', '_');
    }

    return ret;
}

// Decode a base64 string
// Returns an empty string on success, or an error message
std::string decode(std::string input, std::string &out, const Variant variant) {

    // check that input has a valid length (with or without padding)
    // and add padding if needed to make it a padded base64 string
    {
        int remainder = input.size() % 4;
        if (remainder == 1) {
            return "Invalid input length (1)";
        } else if (remainder == 2) {
            input += "==";
        } else if (remainder == 3) {
            input += "=";
        }
    }

    // if base64 input is declared as URL encoded,
    // replace '-' with '+' and '_' with '/'
    // to make it a standard base64 string
    if (variant == Variant::URL) {
        std::replace(input.begin(), input.end(), '-', '+');
        std::replace(input.begin(), input.end(), '_', '/');
    }


    static constexpr unsigned char kDecodingTable[] = {
        64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
        64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
        64, 64, 64, 64, 64, 64, 64, 62, 64, 64, 64, 63, 52, 53, 54, 55, 56, 57,
        58, 59, 60, 61, 64, 64, 64, 64, 64, 64, 64, 0,  1,  2,  3,  4,  5,  6,
        7,  8,  9,  10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
        25, 64, 64, 64, 64, 64, 64, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36,
        37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 64, 64, 64,
        64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
        64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
        64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
        64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
        64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
        64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
        64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
        64, 64, 64, 64};

    size_t in_len = input.size();
    if (in_len % 4 != 0) {
        return "Input data size is not a multiple of 4";
    }

    size_t out_len = in_len / 4 * 3;
    if (in_len >= 1 && input[in_len - 1] == '=')
        out_len--;
    if (in_len >= 2 && input[in_len - 2] == '=')
        out_len--;

    out.resize(out_len);

    for (size_t i = 0, j = 0; i < in_len;) {
        uint32_t a = input[i] == '='
        ? 0 & i++
        : kDecodingTable[static_cast<int>(input[i++])];
        uint32_t b = input[i] == '='
        ? 0 & i++
        : kDecodingTable[static_cast<int>(input[i++])];
        uint32_t c = input[i] == '='
        ? 0 & i++
        : kDecodingTable[static_cast<int>(input[i++])];
        uint32_t d = input[i] == '='
        ? 0 & i++
        : kDecodingTable[static_cast<int>(input[i++])];

        uint32_t triple =
        (a << 3 * 6) + (b << 2 * 6) + (c << 1 * 6) + (d << 0 * 6);

        if (j < out_len)
            out[j++] = (triple >> 2 * 8) & 0xFF;
        if (j < out_len)
            out[j++] = (triple >> 1 * 8) & 0xFF;
        if (j < out_len)
            out[j++] = (triple >> 0 * 8) & 0xFF;
    }

    return "";
}

} // namespace base64
} // namespace encoding
} // namespace vx

// UNIT TESTS

//std::string origin = R"""(Binary: M = 01001101, a = ?><":L|}{P)(*&^%$#@!@#$%^&*()_)""";
//
//std::string encoded_1 = encoding::base64::encode(origin).c_str();
//vxlog_info("ENCODE -> %s", encoded_1.c_str());
//
//std::string encoded_2 = encoding::base64::encode(origin, true).c_str();
//vxlog_info("ENCODE (URL) -> %s", encoded_2.c_str());
//
//std::string decoded_1;
//std::string error = encoding::base64::decode(encoded_1, decoded_1);
//if (error != "") {
//    vxlog_debug("DECODE -> ERROR: %s", error.c_str());
//} else {
//    vxlog_debug("DECODE -> %s", decoded_1 == origin ? "✅" : "❌");
//}
//
//std::string decoded_2;
//error = encoding::base64::decode(encoded_2, decoded_2, true);
//if (error != "") {
//    vxlog_debug("DECODE (URL) -> ERROR: %s", error.c_str());
//} else {
//    vxlog_debug("DECODE (URL) -> %s", decoded_2 == origin ? "✅" : "❌");
//}
