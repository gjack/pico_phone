# frozen_string_literal: true

# Not loaded at runtime — exists only for YARD and IDE tooling.
# All methods are defined in ext/pico_phone/pico_phone.cpp via Rice.

module PicoPhone
  # @!method self.parse(string, region = nil)
  #   Parse a phone number string into a PhoneNumber object.
  #   @param string [String] raw phone number input
  #   @param region [String, nil] ISO 3166-1 alpha-2 region hint (e.g. "US")
  #   @return [PhoneNumber]

  # @!method self.valid?(string)
  #   @param string [String]
  #   @return [Boolean]

  # @!method self.possible?(string)
  #   @param string [String]
  #   @return [Boolean]

  # @!method self.valid_for_country?(string, region)
  #   @param string [String]
  #   @param region [String] ISO 3166-1 alpha-2 region code
  #   @return [Boolean]

  # @!method self.possible_for_country?(string, region)
  #   @param string [String]
  #   @param region [String] ISO 3166-1 alpha-2 region code
  #   @return [Boolean]

  # @!method self.possible_countries(string)
  #   Regions that could own this number based on length or pattern.
  #   @param string [String]
  #   @return [Array<String>] ISO 3166-1 alpha-2 region codes

  # @!method self.valid_countries(string)
  #   Regions for which this number passes strict pattern validation.
  #   @param string [String]
  #   @return [Array<String>] ISO 3166-1 alpha-2 region codes

  # @!method self.supported_types_for_region(region)
  #   @param region [String] ISO 3166-1 alpha-2 region code
  #   @return [Array<Symbol>]

  # @!method self.example_number(region)
  #   @param region [String] ISO 3166-1 alpha-2 region code
  #   @return [PhoneNumber]

  # @!method self.example_number_for_type(region, type)
  #   @param region [String] ISO 3166-1 alpha-2 region code
  #   @param type [Symbol] e.g. :mobile, :fixed_line, :toll_free
  #   @return [PhoneNumber]

  # @!method self.emergency_number?(string, region)
  #   @param string [String]
  #   @param region [String] ISO 3166-1 alpha-2 region code
  #   @return [Boolean]

  # @!method self.short_number_valid?(string, region)
  #   @param string [String]
  #   @param region [String] ISO 3166-1 alpha-2 region code
  #   @return [Boolean]

  # @!method self.short_number_cost(string, region)
  #   @param string [String]
  #   @param region [String] ISO 3166-1 alpha-2 region code
  #   @return [Symbol] :toll_free, :standard_rate, :premium_rate, or :unknown_cost

  # @!method self.supported_regions
  #   All region codes the library knows about (~245 in libphonenumber 9.x).
  #   @return [Array<String>] ISO 3166-1 alpha-2 region codes

  # @!method self.convert_alpha_characters(string)
  #   Convert vanity number alpha characters to digits (e.g. "1-800-FLOWERS" → "1-800-3569377").
  #   @param string [String]
  #   @return [String]

  # @!method self.alpha_number?(string)
  #   @param string [String]
  #   @return [Boolean]

  # @!method self.country_calling_code(region)
  #   Returns the international calling code for a region.
  #   Returns 0 for unknown or invalid region codes.
  #   @param region [String] ISO 3166-1 alpha-2 region code (e.g. "US")
  #   @return [Integer] e.g. 1 for "US", 33 for "FR", 0 for unknown

  # @!method self.number_match(first, second)
  #   Compare two phone number strings and return how closely they match.
  #   Neither string requires a region hint; E.164 input gives the most precise result.
  #   @param first [String]
  #   @param second [String]
  #   @return [Symbol] :exact_match, :nsn_match, :short_nsn_match, :no_match, or :invalid_number

  class PhoneNumber
    # @param string [String, nil] raw phone number input
    # @param region [String, nil] ISO 3166-1 alpha-2 region hint (e.g. "US")
    def initialize(string, region = nil); end

    # @return [Boolean]
    def valid?; end

    # @return [Boolean]
    def invalid?; end

    # @return [Boolean]
    def possible?; end

    # @return [Boolean]
    def impossible?; end

    # Why the number is or is not possible.
    # @return [Symbol] :is_possible, :is_possible_local_only, :too_short, :too_long,
    #   :invalid_country_code, or :invalid_length
    def possible_with_reason; end

    # @return [String] e.g. "(510) 274-5656"
    def national; end

    # @return [String] e.g. "+1 510-274-5656"
    def international; end

    # @return [String] e.g. "+15102745656"
    def e164; end

    # @return [String, nil]
    def extension; end

    # @return [Boolean]
    def has_extension?; end

    # National format with extension appended using the configured prefix.
    # @return [String]
    def full_national; end

    # International format with extension appended using the configured prefix.
    # @return [String]
    def full_international; end

    # E.164 format with extension appended using the configured prefix.
    # @return [String]
    def full_e164; end

    # @return [Integer] e.g. 1 for US/CA, 61 for AU
    def country_code; end

    # @return [String] ISO 3166-1 alpha-2 region code (e.g. "US")
    def country; end

    # @return [String] geographic area code digits, or empty string if none
    def area_code; end

    # National significant number as plain digits, no formatting punctuation.
    # @return [String]
    def raw_national; end

    # International number digits with calling code, no formatting punctuation.
    # @return [String]
    def raw_international; end

    # @return [Symbol] :fixed_line, :mobile, :fixed_line_or_mobile, :toll_free,
    #   :premium_rate, :shared_cost, :voip, :personal_number, :pager, :uan,
    #   :voicemail, or :unknown
    def type; end

    # Subscriber number after the area code. Returns the full national number when
    # there is no geographic area code (e.g. mobile numbers in AU).
    # @return [String]
    def local_number; end

    # Text description of the geographic area the number is from (e.g. a city
    # or region), falling back to the country name when no finer-grained
    # description is available. Returns an empty string for non-geographical
    # numbers (e.g. toll-free) or numbers that could not be parsed.
    # @param language [String] two- or three-letter ISO 639 language code (default: "en")
    # @return [String]
    def geo_name(language = "en"); end

    # Name of the carrier the number was originally allocated to. In
    # countries that support mobile number portability, the number may no
    # longer actually belong to this carrier -- this is the carrier at
    # allocation time, not necessarily the current one. Returns an empty
    # string when no carrier mapping exists for the prefix, or for numbers
    # that could not be parsed.
    # @param language [String] two- or three-letter ISO 639 language code (default: "en")
    # @return [String]
    def carrier_name(language = "en"); end

    # IANA time zone names the number's prefix belongs to. A single prefix
    # can map to several zones (e.g. NANPA numbers span many), hence the
    # plural. Time zone identifiers aren't translated, so unlike geo_name
    # and carrier_name there's no language parameter. Returns an empty
    # array when no mapping exists for the prefix, or for numbers that
    # could not be parsed.
    # @return [Array<String>]
    def timezones; end

    # @param region [String] ISO 3166-1 alpha-2 region code
    # @return [Boolean]
    def valid_for_country?(region); end

    # @param region [String] ISO 3166-1 alpha-2 region code
    # @return [Boolean]
    def invalid_for_country?(region); end

    # The raw input string as passed to the constructor. Survives a failed parse.
    # @return [String, nil]
    def original; end

    # E.164 for a valid number; falls back to {#original} for an invalid one.
    # Returns an empty string when nil was passed as input.
    # @return [String]
    def to_s; end

    # Format using the same style (international vs. national) as the original input.
    # @return [String]
    def format_in_original_format; end

    # Format the number as it would be dialed from outside its home country.
    # @param region [String] ISO 3166-1 alpha-2 region of the caller
    # @return [String]
    def out_of_country_format(region); end

    # Format the number for convenient dialing on a mobile device in the given region.
    # @param region [String] ISO 3166-1 alpha-2 region of the caller
    # @return [String]
    def mobile_dialing_format(region); end

    # Regions that could own this number based on length (unambiguous codes) or
    # pattern (shared calling codes like +1 or +7).
    # @return [Array<String>] ISO 3166-1 alpha-2 region codes
    def possible_countries; end

    # Regions for which this number passes strict pattern validation.
    # @return [Array<String>] ISO 3166-1 alpha-2 region codes
    def valid_countries; end

    # True for fixed-line numbers tied to a geographic area code.
    # @return [Boolean]
    def geographical?; end

    # Compare this number against another and return how closely they match.
    # Pass a String or a PhoneNumber. When passed a PhoneNumber, the country code
    # stored in the proto is used for comparison, giving more precise results than
    # a bare national-format string.
    # @param other [String, PhoneNumber]
    # @return [Symbol] :exact_match, :nsn_match, :short_nsn_match, :no_match, or :invalid_number
    def match_type(other); end

    # True when the number's digit count is consistent with the given type in its region.
    # More permissive than {#type}: a 10-digit US number is possible for both
    # :fixed_line_or_mobile and :toll_free since they share the same digit count.
    # @param type [Symbol] e.g. :mobile, :toll_free, :fixed_line
    # @return [Boolean]
    def possible_for_type?(type); end

    # False for numbers that only work within their own country.
    # @return [Boolean]
    def can_be_internationally_dialled?; end

    # Removes trailing digits until the number is valid, returning the truncated
    # number as a new PhoneNumber. Returns nil if the number was not too long or
    # if no valid truncation exists. Does not mutate the receiver.
    # @return [PhoneNumber, nil]
    def truncate; end
  end
end
