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
    printf("Nil value");
    str_code = rb_str_new("ZZ", 2);
  }

  rb_ivar_set(self, rb_intern("@default_country"), str_code);
}

String pico_phone_get_default_country(Object self) {
  return self.iv_get("@default_country");
}

extern "C"
void Init_pico_phone() {
  Module rb_mPicoPhone = define_module("PicoPhone")
    .define_singleton_method("default_country=", &pico_phone_set_default_country)
    .define_singleton_method("default_country", &pico_phone_get_default_country);

  rb_ivar_set(rb_mPicoPhone, rb_intern("@default_country"), rb_str_new("ZZ", 2));

}
