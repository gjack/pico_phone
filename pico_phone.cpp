#include <rice/rice.hpp>
#include <rice/stl.hpp>
#include <string.h>
#include <iostream>
#include <phonenumbers/phonemetadata.pb.h>
#include <phonenumbers/phonenumber.pb.h>
#include <phonenumbers/phonenumberutil.h>

using namespace Rice;
using namespace i18n::phonenumbers;

void pico_phone_set_default_country(Object self, String str_code) {
  if (NIL_P(str_code)) {
    str_code = rb_str_new("ZZ", 2);
  }

  rb_ivar_set(self, rb_intern("@default_country"), str_code);
}

String pico_phone_get_default_country(Object self) {
  return self.iv_get("@default_country");
}

Object is_phone_number_valid(Object self, String str, String cc) {
  std::string phone_number = str.c_str();
  std::string country_code = cc.c_str();

  if (country_code.empty() || phone_number.empty()) {
    return Qfalse;
  }

  PhoneNumber parsed_number;
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  auto result = phone_util.ParseAndKeepRawInput(phone_number, country_code, &parsed_number);

  if (result != PhoneNumberUtil::NO_PARSING_ERROR) {
    return Qfalse;
  }

  if (country_code == "ZZ" && phone_util.IsValidNumber(parsed_number)) {
    return Qtrue;
  } else if (phone_util.IsValidNumberForRegion(parsed_number, country_code)) {
    return Qtrue;
  } else {
    return Qfalse;
  }
}

Object pico_phone_is_valid_for_default_country(Object self, String phone_number) {
  String country_code = self.iv_get("@default_country");
  return is_phone_number_valid(self, phone_number, country_code);
}

Object pico_phone_is_valid_for_country(Object self, String phone_number, String country_code) {
  return is_phone_number_valid(self, phone_number, country_code);
}

extern "C"
void Init_pico_phone() {
  Module rb_mPicoPhone = define_module("PicoPhone")
    .define_singleton_method("default_country=", &pico_phone_set_default_country)
    .define_singleton_method("default_country", &pico_phone_get_default_country)
    .define_singleton_method("valid?", &pico_phone_is_valid_for_default_country)
    .define_singleton_method("valid_for_country?", &pico_phone_is_valid_for_country);

  rb_ivar_set(rb_mPicoPhone, rb_intern("@default_country"), rb_str_new("ZZ", 2));

}
