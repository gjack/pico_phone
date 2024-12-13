#include <rice/rice.hpp>
#include <rice/stl.hpp>
#include <string.h>
#include <iostream>
#include <phonenumbers/phonemetadata.pb.h>
#include <phonenumbers/phonenumber.pb.h>
#include <phonenumbers/phonenumberutil.h>

using namespace Rice;
using namespace i18n::phonenumbers;
static VALUE rb_cPhoneNumber;
static VALUE rb_mPicoPhone;

size_t phone_number_size(const void *data) { return sizeof(PhoneNumber); }

void phone_number_free(void *data) {
  PhoneNumber *phone_number = static_cast<PhoneNumber *>(data);
  phone_number->~PhoneNumber();
  xfree(data);
}

static const rb_data_type_t phone_number_type = {
  .wrap_struct_name = "phone_number",
    .function =
        {
            .dmark = NULL,
            .dfree = phone_number_free,
            .dsize = phone_number_size,
        },
    .parent = NULL,
    .data = NULL,
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};

VALUE rb_phone_number_alloc(VALUE self) {
  void *phone_number_data = ALLOC(PhoneNumber);
  PhoneNumber *phone_number = new (phone_number_data) PhoneNumber();
  phone_number = phone_number;

  return TypedData_Wrap_Struct(self, &phone_number_type, phone_number);
}

VALUE pico_phone_phone_number_parse(int argc, VALUE *argv, Object self) {
  return rb_class_new_instance(argc, argv, rb_cPhoneNumber);
}


void pico_phone_set_default_country(VALUE str_code, Object self) {
  if (RB_NIL_P(str_code)) {
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

Object is_phone_number_possible(Object self, String str, String cc) {
  std::string phone_number = str.c_str();
  std::string country_code = cc.c_str();

  if (country_code.empty() || phone_number.empty()) {
    return Qnil;
  }

  PhoneNumber parsed_number;
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  auto result = phone_util.Parse(phone_number, country_code, &parsed_number);

  if (result == PhoneNumberUtil::NO_PARSING_ERROR && phone_util.IsPossibleNumber(parsed_number)) {
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

Object pico_phone_is_possible_for_default_country(Object self, String phone_number) {
  String country_code = self.iv_get("@default_country");
  return is_phone_number_possible(self, phone_number, country_code);
}

Object pico_phone_is_possible_for_country(Object self, String phone_number, String country_code) {
  return is_phone_number_possible(self, phone_number, country_code);
}

VALUE phone_number_nullify_ivars(Object self) {
  rb_iv_set(rb_cPhoneNumber, "@input_country_code", Qnil);
  rb_iv_set(rb_cPhoneNumber, "@possible", Qnil);
  rb_iv_set(rb_cPhoneNumber, "@valid", Qnil);
  rb_iv_set(rb_cPhoneNumber, "@type", Qnil);

  return Qtrue;
}

VALUE phone_number_initialize(int argc, VALUE *argv, VALUE self) {
  VALUE str;
  VALUE input_country_code;

  rb_scan_args(argc, argv, "11", &str, &input_country_code);
  rb_iv_set(self, "@input_country_code", input_country_code);

  if (RB_NIL_P(input_country_code)) {
    input_country_code = rb_iv_get(rb_mPicoPhone, "@default_country");
  }

  if (RB_FIXNUM_P(str)) {
    str = rb_fix2str(str, 10);
  } else if (!RB_TYPE_P(str, T_STRING)) {
    return phone_number_nullify_ivars(self);
  }

  PhoneNumber *phone_number;

  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);

  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());
  std::string phone_number_value(StringValuePtr(str), RSTRING_LEN(str));
  std::string country_code(StringValuePtr(input_country_code), RSTRING_LEN(input_country_code));

  PhoneNumber parsed_number;

  auto result = phone_util.ParseAndKeepRawInput(phone_number_value, country_code, &parsed_number);

  if (result != PhoneNumberUtil::NO_PARSING_ERROR) {
    phone_number_nullify_ivars(self);
  }

  phone_number->Swap(&parsed_number);

  return self;
}

Object is_parsed_phone_number_possible(Object self) {
  if (rb_ivar_defined(self, rb_intern("@possible"))) {
    return rb_iv_get(self, "@possible");
  }

  PhoneNumber *phone_number;

  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);

  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  if (phone_util.IsPossibleNumber(*phone_number)) {
    return rb_iv_set(self, "@possible", Qtrue);
  } else {
    return rb_iv_set(self, "@possible", Qfalse);
  }
}

Object is_parsed_phone_number_valid(Object self) {
  if (rb_ivar_defined(self, rb_intern("@valid"))) {
    return rb_iv_get(self, "@valid");
  }

  VALUE input_country_code = rb_iv_get(self, "@input_country_code");
  if (RB_NIL_P(input_country_code)) {
    input_country_code = rb_iv_get(rb_mPicoPhone, "@default_country");
  }

  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);

  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  if (!rb_str_equal(input_country_code, rb_str_new_literal("ZZ"))) {
    std::string country_code(StringValuePtr(input_country_code), RSTRING_LEN(input_country_code));
    if (phone_util.IsValidNumberForRegion(*phone_number, country_code)) {
      return rb_iv_set(self, "@valid", Qtrue);
    } else {
      return rb_iv_set(self, "@valid", Qfalse);
    }
  }

  if (phone_util.IsValidNumber(*phone_number)) {
    return rb_iv_set(self, "@valid", Qtrue);;
  } else {
    return rb_iv_set(self, "@valid", Qfalse);
  }
}

Object parsed_phone_type(Object self) {
  if (rb_ivar_defined(self, rb_intern("@type"))) {
    return rb_iv_get(self, "@type");
  }

  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);

  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  VALUE type_value;
  switch (phone_util.GetNumberType(*phone_number))
  {
    case PhoneNumberUtil::FIXED_LINE:
      type_value = rb_intern("fixed_line");
      break;
    case PhoneNumberUtil::MOBILE:
      type_value = rb_intern("mobile");
      break;
    case PhoneNumberUtil::FIXED_LINE_OR_MOBILE:
      type_value = rb_intern("fixed_line_or_mobile");
      break;
    case PhoneNumberUtil::TOLL_FREE:
      type_value = rb_intern("toll_free");
      break;
    case PhoneNumberUtil::PREMIUM_RATE:
      type_value = rb_intern("premium_rate");
      break;
    case PhoneNumberUtil::SHARED_COST:
      type_value = rb_intern("shared_cost");
      break;
    case PhoneNumberUtil::VOIP:
      type_value = rb_intern("voip");
      break;
    case PhoneNumberUtil::PERSONAL_NUMBER:
      type_value = rb_intern("personal_number");
      break;
    case PhoneNumberUtil::PAGER:
      type_value = rb_intern("pager");
      break;
    case PhoneNumberUtil::UAN:
      type_value = rb_intern("uan");
      break;
    case PhoneNumberUtil::VOICEMAIL:
      type_value = rb_intern("voicemail");
      break;
    default:
      type_value = rb_intern("unknown");
      break;
  }
  return rb_iv_set(self, "@type", rb_id2sym(type_value));
}

static inline String format_parsed_phone_number(Object self, PhoneNumberUtil::PhoneNumberFormat selected_format) {
  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
  PhoneNumber copied_proto(*phone_number);

  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());
  std::string formatted_phone_number;

  // if the phone number has an extension, remove it so it's not part of formatting
  if (phone_number->has_extension()) {
    copied_proto.clear_extension();
  }
  phone_util.Format(copied_proto, selected_format, &formatted_phone_number);

  return formatted_phone_number;
}

String format_parsed_number_national(Object self) {
  return format_parsed_phone_number(self, PhoneNumberUtil::PhoneNumberFormat::NATIONAL);
}

String format_parsed_international(Object self) {
  return format_parsed_phone_number(self, PhoneNumberUtil::PhoneNumberFormat::INTERNATIONAL);
}

String format_parsed_number_e164(Object self) {
  return format_parsed_phone_number(self, PhoneNumberUtil::PhoneNumberFormat::E164);
}

extern "C"
void Init_pico_phone() {
  rb_mPicoPhone = define_module("PicoPhone")
    .define_singleton_method("default_country", &pico_phone_get_default_country)
    .define_singleton_method("valid?", &pico_phone_is_valid_for_default_country)
    .define_singleton_method("valid_for_country?", &pico_phone_is_valid_for_country)
    .define_singleton_method("possible?", &pico_phone_is_possible_for_default_country)
    .define_singleton_method("possible_for_country?", &pico_phone_is_possible_for_country);

    rb_define_singleton_method(rb_mPicoPhone, "default_country=", reinterpret_cast<VALUE (*)(...)>(pico_phone_set_default_country), -1);
    rb_define_singleton_method(rb_mPicoPhone, "parse", reinterpret_cast<VALUE (*)(...)>(pico_phone_phone_number_parse), -1);
    rb_ivar_set(rb_mPicoPhone, rb_intern("@default_country"), rb_str_new("ZZ", 2));

  rb_cPhoneNumber = define_class_under(rb_mPicoPhone, "PhoneNumber")
    .define_method("possible?", &is_parsed_phone_number_possible)
    .define_method("valid?", &is_parsed_phone_number_valid)
    .define_method("type", &parsed_phone_type)
    .define_method("national", &format_parsed_number_national)
    .define_method("international", &format_parsed_international)
    .define_method("e164", &format_parsed_number_e164);

    rb_define_alloc_func(rb_cPhoneNumber, rb_phone_number_alloc);
    rb_define_method(rb_cPhoneNumber, "initialize", reinterpret_cast<VALUE (*)(...)>(phone_number_initialize), -1);
}
