// First-party pico_phone file. See timezone_mapper.h.

#include "timezone_mapper.h"

#include <sstream>
#include <string>
#include <vector>

#include "phonenumbers/geocoding/area_code_map.h"
#include "phonenumbers/phonenumber.pb.h"
#include "timezone_data.h"

namespace i18n {
namespace phonenumbers {

using std::string;
using std::vector;

namespace {

// Time zones are joined with '&' in the raw description string, matching
// libphonenumber's own PrefixTimeZonesMap.RAW_STRING_TIMEZONES_SEPARATOR.
vector<string> SplitTimeZones(const string& raw) {
  vector<string> result;
  std::stringstream stream(raw);
  string token;
  while (std::getline(stream, token, '&')) {
    if (!token.empty()) {
      result.push_back(token);
    }
  }
  return result;
}

}  // namespace

PhoneNumberTimeZonesMapper::PhoneNumberTimeZonesMapper() {
  area_code_map_.reset(new AreaCodeMap());
  area_code_map_->ReadAreaCodeMap(get_timezone_descriptions());
}

PhoneNumberTimeZonesMapper::~PhoneNumberTimeZonesMapper() {}

vector<string> PhoneNumberTimeZonesMapper::GetTimeZonesForNumber(
    const PhoneNumber& number) const {
  const char* description = area_code_map_->Lookup(number);
  if (!description || *description == '\0') {
    return vector<string>();
  }
  return SplitTimeZones(description);
}

}  // namespace phonenumbers
}  // namespace i18n
