// First-party pico_phone file, NOT vendored/copied from libphonenumber
// (unlike its siblings in this directory). Declares the accessors for
// carrier_data.cc, which is generated at build time by running
// libphonenumber's own (unmodified) generate_geocoding_data tool against
// resources/carrier/ with accessor prefix "_carrier" -- see
// ext/pico_phone/build_deps.sh. Mirrors the shape of libphonenumber's own
// test/phonenumbers/geocoding/geocoding_test_data.h, which does the same
// thing for its "_test" prefix: reuse the CountryLanguages/
// PrefixDescriptions struct layouts from geocoding_data.h, declare
// prefix-renamed accessor functions.
//
// This file must live at exactly this path (phonenumbers/geocoding/
// carrier_data.h, relative to an include root) because the generator
// tool hardcodes `#include "phonenumbers/geocoding/<base_name>.h"` in
// every file it emits, where base_name is derived from the output .cc
// filename -- not configurable.

#ifndef PICO_PHONE_CARRIER_DATA_H_
#define PICO_PHONE_CARRIER_DATA_H_

#include "phonenumbers/geocoding/geocoding_data.h"

namespace i18n {
namespace phonenumbers {

// Returns a sorted array of country calling codes with carrier data.
const int* get_carrier_country_calling_codes();

// Returns the number of country calling codes in
// get_carrier_country_calling_codes() array.
int get_carrier_country_calling_codes_size();

// Returns the CountryLanguages record for country at index, index
// being in [0, get_carrier_country_calling_codes_size()).
const CountryLanguages* get_carrier_country_languages(int index);

// Returns a sorted array of prefix language code pairs like
// "1_de" or "82_ko".
const char** get_carrier_prefix_language_code_pairs();

// Returns the number of elements in
// get_carrier_prefix_language_code_pairs()
int get_carrier_prefix_language_code_pairs_size();

// Returns the PrefixDescriptions for language/code pair at index,
// index being in [0, get_carrier_prefix_language_code_pairs_size()).
const PrefixDescriptions* get_carrier_prefix_descriptions(int index);

}  // namespace phonenumbers
}  // namespace i18n

#endif  // PICO_PHONE_CARRIER_DATA_H_
