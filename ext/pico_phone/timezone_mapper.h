// First-party pico_phone file. Unlike carrier_mapper.h, this doesn't need
// its own AreaCodeMap-alike class: timezone data is a single flat prefix
// table (no per-language dimension, no multiple files to lazily choose
// between), so it's a thin wrapper directly around the vendored
// AreaCodeMap -- same longest-prefix-match lookup logic already reused by
// the geocoder and carrier mapper, just with one eagerly-loaded table
// (the whole thing is ~86KB source data, small enough that lazy loading
// isn't worth the complexity here).

#ifndef PICO_PHONE_TIMEZONE_MAPPER_H_
#define PICO_PHONE_TIMEZONE_MAPPER_H_

#include <string>
#include <vector>

#include "phonenumbers/base/memory/scoped_ptr.h"

namespace i18n {
namespace phonenumbers {

class AreaCodeMap;
class PhoneNumber;

class PhoneNumberTimeZonesMapper {
 public:
  PhoneNumberTimeZonesMapper();

  PhoneNumberTimeZonesMapper(const PhoneNumberTimeZonesMapper&) = delete;
  PhoneNumberTimeZonesMapper& operator=(const PhoneNumberTimeZonesMapper&) = delete;

  ~PhoneNumberTimeZonesMapper();

  // Returns the time zones the given phone number's prefix belongs to, or
  // an empty vector if no mapping is available. A single prefix can map to
  // several time zones (e.g. NANPA numbers span many), hence the plural --
  // matching libphonenumber's own Java PhoneNumberToTimeZonesMapper shape,
  // though this returns an empty vector for "not found" rather than Java's
  // single-element ["Etc/Unknown"] sentinel, to match this codebase's own
  // convention (see carrier_mapper.h) of empty over sentinel values.
  std::vector<std::string> GetTimeZonesForNumber(const PhoneNumber& number) const;

 private:
  scoped_ptr<AreaCodeMap> area_code_map_;
};

}  // namespace phonenumbers
}  // namespace i18n

#endif  // PICO_PHONE_TIMEZONE_MAPPER_H_
