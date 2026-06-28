#include <rice/rice.hpp>
#include <rice/stl.hpp>
#include <string.h>
#include <list>
#include <set>
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

void pico_phone_set_default_country(VALUE self, VALUE str_code) {
  if (RB_NIL_P(str_code)) {
    str_code = rb_str_new("ZZ", 2);
  }

  rb_ivar_set(self, rb_intern("@default_country"), str_code);
}

void pico_phone_set_default_extension_prefix(VALUE self, VALUE str_code) {
  if (RB_NIL_P(str_code)) {
    str_code = rb_str_new(";", 1);
  }

  rb_ivar_set(self, rb_intern("@default_extn_prefix"), str_code);
}

String pico_phone_get_default_country(Object self) {
  return self.iv_get("@default_country");
}

Object is_phone_number_valid(Object self, String str, String cc) {
  std::string phone_number = str.c_str();
  std::string country = cc.c_str();

  if (country.empty() || phone_number.empty()) {
    return Qfalse;
  }

  PhoneNumber parsed_number;
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  auto result = phone_util.ParseAndKeepRawInput(phone_number, country, &parsed_number);

  if (result != PhoneNumberUtil::NO_PARSING_ERROR) {
    return Qfalse;
  }

  if (country == "ZZ" && phone_util.IsValidNumber(parsed_number)) {
    return Qtrue;
  } else if (phone_util.IsValidNumberForRegion(parsed_number, country)) {
    return Qtrue;
  } else {
    return Qfalse;
  }
}

Object is_phone_number_possible(Object self, String str, String cc) {
  std::string phone_number = str.c_str();
  std::string country = cc.c_str();

  if (country.empty() || phone_number.empty()) {
    return Qnil;
  }

  PhoneNumber parsed_number;
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  auto result = phone_util.Parse(phone_number, country, &parsed_number);

  if (result == PhoneNumberUtil::NO_PARSING_ERROR && phone_util.IsPossibleNumber(parsed_number)) {
    return Qtrue;
  } else {
    return Qfalse;
  }
}

Object pico_phone_is_valid_for_default_country(Object self, String phone_number) {
  String country = self.iv_get("@default_country");
  return is_phone_number_valid(self, phone_number, country);
}

Object pico_phone_is_valid_for_country(Object self, String phone_number, String country) {
  return is_phone_number_valid(self, phone_number, country);
}

Object pico_phone_is_possible_for_default_country(Object self, String phone_number) {
  String country = self.iv_get("@default_country");
  return is_phone_number_possible(self, phone_number, country);
}

Object pico_phone_is_possible_for_country(Object self, String phone_number, String country) {
  return is_phone_number_possible(self, phone_number, country);
}

static Array regions_for_number(const PhoneNumber& number, bool strict) {
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());
  std::list<std::string> regions;
  phone_util.GetRegionCodesForCountryCallingCode(number.country_code(), &regions);

  Array result;

  // For the lenient (possible) check with a single region there is nothing to
  // disambiguate, so a length-only check is sufficient and preferable: it lets
  // possible_countries return the region for numbers that are the right length
  // but fail strict pattern validation (e.g. a digit transposition in a French
  // number still belongs to France). For ambiguous calling codes (+1, +7, +44,
  // …) we must use IsValidNumberForRegion to distinguish between the candidate
  // regions regardless of strictness, since IsPossibleNumber has no concept of
  // region and would accept every candidate region equally.
  if (!strict && regions.size() == 1) {
    if (phone_util.IsPossibleNumber(number)) {
      const auto& region = regions.front();
      result.push(Object(rb_str_new(region.c_str(), region.size())));
    }
    return result;
  }

  for (const auto& region : regions) {
    if (phone_util.IsValidNumberForRegion(number, region)) {
      result.push(Object(rb_str_new(region.c_str(), region.size())));
    }
  }
  return result;
}

Array pico_phone_supported_regions(Object self) {
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());
  std::set<std::string> regions;
  phone_util.GetSupportedRegions(&regions);

  Array result;
  for (const auto& region : regions) {
    result.push(Object(rb_str_new(region.c_str(), region.size())));
  }
  return result;
}

String pico_phone_convert_alpha_characters(Object self, String str) {
  std::string phone_str = str.c_str();
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());
  phone_util.ConvertAlphaCharactersInNumber(&phone_str);
  return rb_str_new(phone_str.c_str(), phone_str.size());
}

Object pico_phone_is_alpha_number(Object self, String str) {
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());
  return phone_util.IsAlphaNumber(str.c_str()) ? Qtrue : Qfalse;
}

Array pico_phone_possible_countries_for_string(Object self, String str) {
  std::string phone_number_str = str.c_str();
  if (phone_number_str.empty()) return Array();

  PhoneNumber parsed_number;
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  auto parse_result = phone_util.Parse(phone_number_str, "ZZ", &parsed_number);
  if (parse_result != PhoneNumberUtil::NO_PARSING_ERROR) return Array();

  return regions_for_number(parsed_number, false);
}

Array pico_phone_valid_countries_for_string(Object self, String str) {
  std::string phone_number_str = str.c_str();
  if (phone_number_str.empty()) return Array();

  PhoneNumber parsed_number;
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  auto parse_result = phone_util.Parse(phone_number_str, "ZZ", &parsed_number);
  if (parse_result != PhoneNumberUtil::NO_PARSING_ERROR) return Array();

  return regions_for_number(parsed_number, true);
}

Object parsed_number_possible_with_reason(Object self) {
  if (rb_ivar_defined(self, rb_intern("@possible_with_reason"))) {
    return rb_iv_get(self, "@possible_with_reason");
  }

  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  VALUE reason;
  switch (phone_util.IsPossibleNumberWithReason(*phone_number)) {
    case PhoneNumberUtil::IS_POSSIBLE:
      reason = rb_intern("is_possible");
      break;
    case PhoneNumberUtil::IS_POSSIBLE_LOCAL_ONLY:
      reason = rb_intern("is_possible_local_only");
      break;
    case PhoneNumberUtil::TOO_SHORT:
      reason = rb_intern("too_short");
      break;
    case PhoneNumberUtil::TOO_LONG:
      reason = rb_intern("too_long");
      break;
    case PhoneNumberUtil::INVALID_COUNTRY_CODE:
      reason = rb_intern("invalid_country_code");
      break;
    case PhoneNumberUtil::INVALID_LENGTH:
      reason = rb_intern("invalid_length");
      break;
    default:
      reason = rb_intern("unknown");
      break;
  }
  return rb_iv_set(self, "@possible_with_reason", rb_id2sym(reason));
}

Object parsed_number_geographical(Object self) {
  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());
  return phone_util.IsNumberGeographical(*phone_number) ? Qtrue : Qfalse;
}

Object parsed_number_can_be_internationally_dialled(Object self) {
  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());
  return phone_util.CanBeInternationallyDialled(*phone_number) ? Qtrue : Qfalse;
}

VALUE phone_number_nullify_ivars(Object self) {
  rb_iv_set(self, "@input_country", Qnil);
  rb_iv_set(self, "@possible", Qfalse);
  rb_iv_set(self, "@valid", Qfalse);
  rb_iv_set(self, "@type", Qnil);
  rb_iv_set(self, "@national", Qnil);
  rb_iv_set(self, "@international", Qnil);
  rb_iv_set(self, "@e164", Qnil);
  rb_iv_set(self, "@country_code", Qnil);
  rb_iv_set(self, "@country", Qnil);
  rb_iv_set(self, "@area_code", Qnil);
  rb_iv_set(self, "@local_number", Qnil);
  rb_iv_set(self, "@original_format", Qnil);
  rb_iv_set(self, "@raw_national", Qnil);
  rb_iv_set(self, "@possible_with_reason", Qnil);

  return Qtrue;
}

VALUE phone_number_initialize(int argc, VALUE *argv, VALUE self) {
  VALUE str;
  VALUE input_country;

  rb_scan_args(argc, argv, "11", &str, &input_country);
  rb_iv_set(self, "@input_country", input_country);
  rb_iv_set(self, "@original", str);

  if (RB_NIL_P(input_country)) {
    input_country = rb_iv_get(rb_mPicoPhone, "@default_country");
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
  std::string country(StringValuePtr(input_country), RSTRING_LEN(input_country));

  PhoneNumber parsed_number;

  auto result = phone_util.ParseAndKeepRawInput(phone_number_value, country, &parsed_number);

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

Object is_parsed_phone_number_impossible(Object self) {
  return (bool) is_parsed_phone_number_possible(self) ? Qfalse : Qtrue;
}

Object is_parsed_phone_number_valid(Object self) {
  if (rb_ivar_defined(self, rb_intern("@valid"))) {
    return rb_iv_get(self, "@valid");
  }

  VALUE input_country = rb_iv_get(self, "@input_country");
  if (RB_NIL_P(input_country)) {
    input_country = rb_iv_get(rb_mPicoPhone, "@default_country");
  }

  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);

  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  if (!rb_str_equal(input_country, rb_str_new_literal("ZZ"))) {
    std::string country(StringValuePtr(input_country), RSTRING_LEN(input_country));
    if (phone_util.IsValidNumberForRegion(*phone_number, country)) {
      return rb_iv_set(self, "@valid", Qtrue);
    } else {
      return rb_iv_set(self, "@valid", Qfalse);
    }
  }

  if (phone_util.IsValidNumber(*phone_number)) {
    return rb_iv_set(self, "@valid", Qtrue);
  } else {
    return rb_iv_set(self, "@valid", Qfalse);
  }
}

Object is_parsed_phone_number_invalid(Object self) {
  return (bool) is_parsed_phone_number_valid(self) ? Qfalse : Qtrue;
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

static inline String format_parsed_phone_number(Object self, PhoneNumberUtil::PhoneNumberFormat selected_format, bool full_format = false) {
  PhoneNumber *phone_number;

  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
  PhoneNumber copied_proto(*phone_number);

  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());
  std::string formatted_phone_number;
  String extension_prefix = rb_iv_get(rb_mPicoPhone, "@default_extn_prefix");

  // if the phone number has an extension
  // remove it so it's not part of formatting
  if (phone_number->has_extension()) {
    copied_proto.clear_extension();
  }

  phone_util.Format(copied_proto, selected_format, &formatted_phone_number);

  return (full_format && phone_number->has_extension()) ? formatted_phone_number.append(extension_prefix.c_str()).append(phone_number->extension()) : formatted_phone_number;
}

String format_parsed_number_national(Object self) {
  if (rb_ivar_defined(self, rb_intern("@national"))) {
    return rb_iv_get(self, "@national");
  }

  return rb_iv_set(self, "@national", format_parsed_phone_number(self, PhoneNumberUtil::PhoneNumberFormat::NATIONAL));
}

String format_parsed_number_full_national(Object self) {
  return format_parsed_phone_number(self, PhoneNumberUtil::PhoneNumberFormat::NATIONAL, true);
}

String format_parsed_number_raw_national(Object self) {
  if (rb_ivar_defined(self, rb_intern("@raw_national"))) {
    return rb_iv_get(self, "@raw_national");
  }

  PhoneNumber *phone_number;
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);

  std::string national_number;
  phone_util.GetNationalSignificantNumber(*phone_number, &national_number);

  return rb_iv_set(self, "@raw_national", rb_str_new(national_number.c_str(), national_number.size()));
}

String format_parsed_international(Object self) {
  if (rb_ivar_defined(self, rb_intern("@international"))) {
    return rb_iv_get(self, "@international");
  }
  return rb_iv_set(self, "@international", format_parsed_phone_number(self, PhoneNumberUtil::PhoneNumberFormat::INTERNATIONAL));
}

String format_parsed_full_international(Object self) {
  return format_parsed_phone_number(self, PhoneNumberUtil::PhoneNumberFormat::INTERNATIONAL, true);
}

String format_parsed_number_raw_international(Object self) {
  if (rb_ivar_defined(self, rb_intern("@raw_international"))) {
    return rb_iv_get(self, "@raw_international");
  }

  String formatted;

  if (rb_ivar_defined(self, rb_intern("@e164"))) {
    formatted = rb_iv_get(self, "@e164");
  } else {
    formatted = format_parsed_phone_number(self, PhoneNumberUtil::PhoneNumberFormat::E164);
  }

  std::string formatted_raw = formatted.str().erase(0, 1);

  return rb_iv_set(self, "@raw_international", (String) formatted_raw);
}

String format_parsed_number_e164(Object self) {
  if (rb_ivar_defined(self, rb_intern("@e164"))) {
    return rb_iv_get(self, "@e164");
  }
  return rb_iv_set(self, "@e164", format_parsed_phone_number(self, PhoneNumberUtil::PhoneNumberFormat::E164));
}

String format_parsed_number_full_e164(Object self) {
  return format_parsed_phone_number(self, PhoneNumberUtil::PhoneNumberFormat::E164, true);
}

String format_parsed_number_in_original_format(Object self) {
  if (rb_ivar_defined(self, rb_intern("@original_format"))) {
    return rb_iv_get(self, "@original_format");
  }

  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  VALUE input_country = rb_iv_get(self, "@input_country");
  if (RB_NIL_P(input_country)) {
    input_country = rb_iv_get(rb_mPicoPhone, "@default_country");
  }
  std::string region(StringValuePtr(input_country), RSTRING_LEN(input_country));

  std::string formatted;
  phone_util.FormatInOriginalFormat(*phone_number, region, &formatted);
  return rb_iv_set(self, "@original_format", rb_str_new(formatted.c_str(), formatted.size()));
}

String format_parsed_number_out_of_country(Object self, String calling_from) {
  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  std::string formatted;
  phone_util.FormatOutOfCountryCallingNumber(*phone_number, calling_from.c_str(), &formatted);
  return rb_str_new(formatted.c_str(), formatted.size());
}

String format_parsed_number_mobile_dialing(Object self, String calling_from) {
  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  std::string formatted;
  phone_util.FormatNumberForMobileDialing(*phone_number, calling_from.c_str(), true, &formatted);
  return rb_str_new(formatted.c_str(), formatted.size());
}

Object parsed_phone_number_has_extension(Object self) {
  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);

  return phone_number->has_extension() ? Qtrue : Qfalse;
}

// Returns the extension for the parsed phone number according to the pattern in
// libphonenumber library https://github.com/google/libphonenumber/blob/424617599369e7adba8a5d1509b910d9ce2e3e44/cpp/src/phonenumbers/phonenumberutil.cc#L220
String parsed_number_extension(Object self) {
  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);

  if (phone_number->has_extension()) {
    return phone_number->extension();
  } else {
    return String("");
  }
}

Object parsed_number_country_code(Object self) {
  if (rb_ivar_defined(self, rb_intern("@country_code"))) {
    return rb_iv_get(self, "@country_code");
  }

  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);

  int code = phone_number->country_code();

  return rb_iv_set(self, "@country_code", INT2FIX(code));
}

String parsed_number_country(Object self) {
  if (rb_ivar_defined(self, rb_intern("@country"))) {
    return rb_iv_get(self, "@country");
  }

  VALUE input_country = rb_iv_get(self, "@input_country");

  if(RB_NIL_P(input_country)) {
    PhoneNumber *phone_number;
    std::string country;
    TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
    const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());
    phone_util.GetRegionCodeForCountryCode(phone_number->country_code(), &country);

    return rb_iv_set(self, "@country", rb_str_new(country.c_str(), country.size()));
  } else {
    return rb_iv_set(self, "@country", input_country);
  }
}

String parsed_number_area_code(Object self) {
  if (rb_ivar_defined(self, rb_intern("@area_code"))) {
    return rb_iv_get(self, "@area_code");
  }

  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());
  std::string national_significant_number;
  std::string area_code;
  int area_code_size = phone_util.GetLengthOfGeographicalAreaCode(*phone_number);

  if (area_code_size > 0) {
    phone_util.GetNationalSignificantNumber(*phone_number, &national_significant_number);
    area_code = national_significant_number.substr(0, area_code_size);
  } else {
    area_code = "";
  }

  return rb_iv_set(self, "@area_code", rb_str_new(area_code.c_str(), area_code.size()));
}

String parsed_number_local_number(Object self) {
  if (rb_ivar_defined(self, rb_intern("@local_number"))) {
    return rb_iv_get(self, "@local_number");
  }

  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());

  std::string national_significant_number;
  phone_util.GetNationalSignificantNumber(*phone_number, &national_significant_number);

  int area_code_length = phone_util.GetLengthOfGeographicalAreaCode(*phone_number);
  std::string local = area_code_length > 0
    ? national_significant_number.substr(area_code_length)
    : national_significant_number;

  return rb_iv_set(self, "@local_number", rb_str_new(local.c_str(), local.size()));
}

Object parsed_number_valid_for_country(Object self, String country) {
  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
  const PhoneNumberUtil &phone_util(*PhoneNumberUtil::GetInstance());
  return phone_util.IsValidNumberForRegion(*phone_number, country.c_str()) ? Qtrue : Qfalse;
}

Object parsed_number_invalid_for_country(Object self, String country) {
  return RTEST(parsed_number_valid_for_country(self, country)) ? Qfalse : Qtrue;
}

Object parsed_number_original(Object self) {
  return rb_iv_get(self, "@original");
}

Object parsed_number_to_s(Object self) {
  if (RTEST(is_parsed_phone_number_valid(self))) {
    return format_parsed_number_e164(self);
  }
  VALUE original = rb_iv_get(self, "@original");
  return RB_NIL_P(original) ? Object(rb_str_new("", 0)) : Object(original);
}

Array parsed_number_possible_countries(Object self) {
  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
  return regions_for_number(*phone_number, false);
}

Array parsed_number_valid_countries(Object self) {
  PhoneNumber *phone_number;
  TypedData_Get_Struct(self, PhoneNumber, &phone_number_type, phone_number);
  return regions_for_number(*phone_number, true);
}

extern "C"
void Init_pico_phone() {
  rb_mPicoPhone = define_module("PicoPhone")
    .define_singleton_method("default_country", &pico_phone_get_default_country)
    .define_singleton_method("valid?", &pico_phone_is_valid_for_default_country)
    .define_singleton_method("valid_for_country?", &pico_phone_is_valid_for_country)
    .define_singleton_method("possible?", &pico_phone_is_possible_for_default_country)
    .define_singleton_method("possible_for_country?", &pico_phone_is_possible_for_country)
    .define_singleton_method("possible_countries", &pico_phone_possible_countries_for_string)
    .define_singleton_method("valid_countries", &pico_phone_valid_countries_for_string)
    .define_singleton_method("supported_regions", &pico_phone_supported_regions)
    .define_singleton_method("convert_alpha_characters", &pico_phone_convert_alpha_characters)
    .define_singleton_method("alpha_number?", &pico_phone_is_alpha_number);

    rb_define_module_function(rb_mPicoPhone, "default_country=", reinterpret_cast<VALUE (*)(...)>(pico_phone_set_default_country), 1);
    rb_define_module_function(rb_mPicoPhone, "default_extension_prefix=", reinterpret_cast<VALUE (*)(...)>(pico_phone_set_default_extension_prefix), 1);
    rb_define_singleton_method(rb_mPicoPhone, "parse", reinterpret_cast<VALUE (*)(...)>(pico_phone_phone_number_parse), -1);
    rb_ivar_set(rb_mPicoPhone, rb_intern("@default_country"), rb_str_new("ZZ", 2));
    rb_ivar_set(rb_mPicoPhone, rb_intern("@default_extn_prefix"), rb_str_new(";", 1));

  rb_cPhoneNumber = define_class_under(rb_mPicoPhone, "PhoneNumber")
    .define_method("possible?", &is_parsed_phone_number_possible)
    .define_method("impossible?", &is_parsed_phone_number_impossible)
    .define_method("valid?", &is_parsed_phone_number_valid)
    .define_method("invalid?", &is_parsed_phone_number_invalid)
    .define_method("type", &parsed_phone_type)
    .define_method("national", &format_parsed_number_national)
    .define_method("international", &format_parsed_international)
    .define_method("e164", &format_parsed_number_e164)
    .define_method("extension", &parsed_number_extension)
    .define_method("has_extension?", &parsed_phone_number_has_extension)
    .define_method("full_national", &format_parsed_number_full_national)
    .define_method("full_international", &format_parsed_full_international)
    .define_method("full_e164", &format_parsed_number_full_e164)
    .define_method("format_in_original_format", &format_parsed_number_in_original_format)
    .define_method("out_of_country_format", &format_parsed_number_out_of_country)
    .define_method("mobile_dialing_format", &format_parsed_number_mobile_dialing)
    .define_method("country_code", &parsed_number_country_code)
    .define_method("country", &parsed_number_country)
    .define_method("area_code", &parsed_number_area_code)
    .define_method("local_number", &parsed_number_local_number)
    .define_method("valid_for_country?", &parsed_number_valid_for_country)
    .define_method("invalid_for_country?", &parsed_number_invalid_for_country)
    .define_method("original", &parsed_number_original)
    .define_method("to_s", &parsed_number_to_s)
    .define_method("raw_national", &format_parsed_number_raw_national)
    .define_method("raw_international", &format_parsed_number_raw_international)
    .define_method("possible_countries", &parsed_number_possible_countries)
    .define_method("valid_countries", &parsed_number_valid_countries)
    .define_method("possible_with_reason", &parsed_number_possible_with_reason)
    .define_method("geographical?", &parsed_number_geographical)
    .define_method("can_be_internationally_dialled?", &parsed_number_can_be_internationally_dialled);

    rb_define_alloc_func(rb_cPhoneNumber, rb_phone_number_alloc);
    rb_define_method(rb_cPhoneNumber, "initialize", reinterpret_cast<VALUE (*)(...)>(phone_number_initialize), -1);
}
