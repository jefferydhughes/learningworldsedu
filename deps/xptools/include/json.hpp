//
//  json.hpp
//  xptools
//
//  Created by Xavier Legland on 1/28/22.
//

#pragma once

// C
#include <cstdint>
// C++
#include <string>
#include <vector>
#include <unordered_map>

// cJSON lib
#include "cJSON.h"

namespace vx {

namespace json {

// returns true if json is an object and contains the field
bool hasField(const cJSON * const obj, const std::string& field);

// returns true if found
bool readStringField(const cJSON * const src, const std::string& field, std::string& value, bool canBeOmitted = false);
// returns true on success
bool writeStringField(cJSON * const obj, const std::string& field, const std::string& value, bool omitIfEmpty = true);

// returns true if found
bool readIntField(const cJSON *src, const std::string &field, int& value, bool canBeOmitted = false);
bool readUInt8Field(const cJSON *src, const std::string &field, uint8_t& value, bool canBeOmitted = false);
void writeIntField(cJSON *dest, const std::string& field, const int value);
void writeInt64Field(cJSON *dest, const std::string& field, const int64_t value);

// returns true if found
bool readDoubleField(const cJSON *src, const std::string& field, double& value, bool canBeOmitted = false);
void writeDoubleField(cJSON *dest, const std::string& field, const double value);

// returns true if found
bool readBoolField(const cJSON *src, const std::string& field, bool &value, bool canBeOmitted = false);
void writeBoolField(cJSON *dest, const std::string& field, const bool value);

void writeNullField(cJSON *dest, const std::string &field);

/// Returns true on success, false otherwise.
bool readStringArray(const cJSON *const src, std::vector<std::string>& value);
// static bool readStringArrayField(const cJSON *const src, const std::string& field, std::vector<std::string>& value, bool canBeOmitted = false);

bool readMapStringString(const cJSON * const src, std::unordered_map<std::string, std::string>& value);

} // namespace json

} // namespace vx
