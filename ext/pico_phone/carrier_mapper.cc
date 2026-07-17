// First-party pico_phone file. See carrier_mapper.h.

#include "carrier_mapper.h"

#include <algorithm>
#include <cstring>
#include <string>

#include "phonenumbers/geocoding/area_code_map.h"
#include "phonenumbers/geocoding/carrier_data.h"
#include "phonenumbers/geocoding/mapping_file_provider.h"
#include "phonenumbers/phonenumber.pb.h"

#include "absl/synchronization/mutex.h"

namespace i18n {
namespace phonenumbers {

using std::string;

namespace {

// Returns true if s1 comes strictly before s2 in lexicographic order.
bool IsLowerThan(const char* s1, const char* s2) {
  return strcmp(s1, s2) < 0;
}

}  // namespace

PhoneNumberCarrierMapper::PhoneNumberCarrierMapper() {
  provider_.reset(new MappingFileProvider(get_carrier_country_calling_codes(),
                                          get_carrier_country_calling_codes_size(),
                                          get_carrier_country_languages));
  prefix_language_code_pairs_ = get_carrier_prefix_language_code_pairs();
  prefix_language_code_pairs_size_ = get_carrier_prefix_language_code_pairs_size();
  get_prefix_descriptions_ = get_carrier_prefix_descriptions;
}

PhoneNumberCarrierMapper::~PhoneNumberCarrierMapper() {
  // Pointer-taking constructor, not the reference-taking one: this file
  // compiles against two different Abseil versions depending on build path
  // (vendored 20260526.0 for the static/native build, whatever Debian/Ubuntu
  // packages for the dynamic/apt-linked build), and only the older
  // pointer-taking overload exists in both. The vendored geocoder itself hit
  // the same tension in the other direction (see build_deps.sh's
  // absl::MutexLock patch) -- there it's a -Werror'd deprecation inside
  // libphonenumber's own CMake build; here it's just a harmless warning
  // since pico_phone's own extension build doesn't set -Werror.
  absl::MutexLock l(&mu_);
  for (AreaCodeMaps::const_iterator it = available_maps_.begin();
       it != available_maps_.end(); ++it) {
    delete it->second;
  }
}

const AreaCodeMap* PhoneNumberCarrierMapper::GetPhonePrefixDescriptions(
    int prefix, const string& language, const string& script,
    const string& region) const {
  string filename;
  provider_->GetFileName(prefix, language, script, region, &filename);
  if (filename.empty()) {
    return NULL;
  }
  AreaCodeMaps::const_iterator it = available_maps_.find(filename);
  if (it == available_maps_.end()) {
    return LoadAreaCodeMapFromFile(filename);
  }
  return it->second;
}

const AreaCodeMap* PhoneNumberCarrierMapper::LoadAreaCodeMapFromFile(
    const string& filename) const {
  const char** const prefix_language_code_pairs_end =
      prefix_language_code_pairs_ + prefix_language_code_pairs_size_;
  const char** const prefix_language_code_pair =
      std::lower_bound(prefix_language_code_pairs_,
                       prefix_language_code_pairs_end,
                       filename.c_str(), IsLowerThan);
  if (prefix_language_code_pair != prefix_language_code_pairs_end &&
      filename.compare(*prefix_language_code_pair) == 0) {
    AreaCodeMap* const m = new AreaCodeMap();
    m->ReadAreaCodeMap(get_prefix_descriptions_(
            prefix_language_code_pair - prefix_language_code_pairs_));
    return available_maps_.insert(AreaCodeMaps::value_type(filename, m))
        .first->second;
  }
  return NULL;
}

const char* PhoneNumberCarrierMapper::GetAreaDescription(
    const PhoneNumber& number, const string& lang, const string& script,
    const string& region) const {
  const int country_calling_code = number.country_code();
  // NANPA area is not split in C++ code (matches PhoneNumberOfflineGeocoder).
  const int phone_prefix = country_calling_code;
  absl::MutexLock l(&mu_);
  const AreaCodeMap* const descriptions = GetPhonePrefixDescriptions(
      phone_prefix, lang, script, region);
  const char* description = descriptions ? descriptions->Lookup(number) : NULL;
  // When a carrier name is not available in the requested language, fall
  // back to English.
  if ((!description || *description == '\0') && MayFallBackToEnglish(lang)) {
    const AreaCodeMap* default_descriptions = GetPhonePrefixDescriptions(
        phone_prefix, "en", "", "");
    if (!default_descriptions) {
      return "";
    }
    description = default_descriptions->Lookup(number);
  }
  return description ? description : "";
}

// Don't fall back to English if the requested language is among the following:
// - Chinese
// - Japanese
// - Korean
bool PhoneNumberCarrierMapper::MayFallBackToEnglish(const string& lang) const {
  return lang.compare("zh") && lang.compare("ja") && lang.compare("ko");
}

string PhoneNumberCarrierMapper::GetNameForNumber(
    const PhoneNumber& number, const string& lang) const {
  return GetAreaDescription(number, lang, "", "");
}

}  // namespace phonenumbers
}  // namespace i18n
