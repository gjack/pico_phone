// First-party pico_phone file. A trimmed mirror of libphonenumber's
// PhoneNumberOfflineGeocoder (phonenumbers/geocoding/
// phonenumber_offline_geocoder.h in the vendored source), reusing the same
// AreaCodeMap/MappingFileProvider machinery -- lazy per (country calling
// code, language) file loading, cached for the life of the process -- but
// backed by carrier_data.cc instead of geocoding_data.cc, and with the
// ICU-based country-name fallback removed: carrier data has no natural
// "fall back to the country name" concept (unlike geocoding), so an
// unmapped prefix returns an empty string, matching phonelib's carrier
// semantics. This also means, unlike the geocoder, this class has no ICU
// dependency at all.

#ifndef PICO_PHONE_CARRIER_MAPPER_H_
#define PICO_PHONE_CARRIER_MAPPER_H_

#include <map>
#include <string>

#include "absl/synchronization/mutex.h"
#include "phonenumbers/base/memory/scoped_ptr.h"

namespace i18n {
namespace phonenumbers {

class AreaCodeMap;
class MappingFileProvider;
class PhoneNumber;
struct CountryLanguages;
struct PrefixDescriptions;

class PhoneNumberCarrierMapper {
 private:
  typedef std::map<std::string, const AreaCodeMap*> AreaCodeMaps;

 public:
  PhoneNumberCarrierMapper();

  PhoneNumberCarrierMapper(const PhoneNumberCarrierMapper&) = delete;
  PhoneNumberCarrierMapper& operator=(const PhoneNumberCarrierMapper&) = delete;

  ~PhoneNumberCarrierMapper();

  // Returns the carrier name for the given phone number in the given
  // language, or an empty string if no carrier mapping is available for
  // this prefix. lang is a two or three-letter lowercase ISO 639 language
  // code, as with PhoneNumberOfflineGeocoder.
  //
  // The carrier name is the one the number was originally allocated to,
  // however if the country supports mobile number portability the number
  // might not belong to the returned carrier anymore (same caveat as
  // upstream's Java-only PhoneNumberToCarrierMapper.getNameForNumber,
  // verbatim -- see java/carrier/src/.../PhoneNumberToCarrierMapper.java
  // in the vendored source tree).
  std::string GetNameForNumber(const PhoneNumber& number,
                               const std::string& lang) const;

 private:
  typedef const PrefixDescriptions* (*prefix_descriptions_getter)(int index);

  const AreaCodeMap* LoadAreaCodeMapFromFile(
      const std::string& filename) const ABSL_EXCLUSIVE_LOCKS_REQUIRED(mu_);

  const AreaCodeMap* GetPhonePrefixDescriptions(
      int prefix, const std::string& language, const std::string& script,
      const std::string& region) const ABSL_EXCLUSIVE_LOCKS_REQUIRED(mu_);

  const char* GetAreaDescription(const PhoneNumber& number,
                                 const std::string& lang,
                                 const std::string& script,
                                 const std::string& region) const
      ABSL_LOCKS_EXCLUDED(mu_);

  bool MayFallBackToEnglish(const std::string& lang) const;

  scoped_ptr<const MappingFileProvider> provider_;

  const char** prefix_language_code_pairs_;
  int prefix_language_code_pairs_size_;
  prefix_descriptions_getter get_prefix_descriptions_;

  mutable absl::Mutex mu_;
  mutable AreaCodeMaps available_maps_ ABSL_GUARDED_BY(mu_);
};

}  // namespace phonenumbers
}  // namespace i18n

#endif  // PICO_PHONE_CARRIER_MAPPER_H_
