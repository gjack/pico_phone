# frozen_string_literal: true

RSpec.describe PicoPhone do
  it "has a version number" do
    expect(PicoPhone::VERSION).not_to be nil
  end

  it "stores a default_country" do
    PicoPhone.default_country = "US"

    expect(PicoPhone.default_country).to eq("US")
  end

  it "sets the default country to ZZ if passed nil" do
    PicoPhone.default_country = nil

    expect(PicoPhone.default_country).to eq("ZZ")
  end

  it "stores a default extension prefix" do
    PicoPhone.default_extension_prefix = "ext."

    expect(PicoPhone.instance_variable_get(:@default_extn_prefix)).to eq("ext.")
  end

  it "sets a default extension prefix of ; if passed nil" do
    PicoPhone.default_extension_prefix = nil

    expect(PicoPhone.instance_variable_get(:@default_extn_prefix)).to eq(";")
  end

  describe "possible?" do
    it "returns false for a string that is not a phone number" do
      expect(PicoPhone.possible?("Not a number")).to be false
    end

    context "when default_country is set" do
      before do
        PicoPhone.default_country = "US"
      end

      it "returns true for a string that contains a possible phone number for the country among other words" do
        expect(PicoPhone.possible?("This is my phone: 5102745656")).to be true
      end
    end
  end

  describe "possible_for_country?" do
    it "returns false for numbers that cannot represent a phone number in the country" do
      expect(PicoPhone.possible_for_country?("208765432", "US")).to be false
    end

    it "returnst true for numbers that could represent a phone number in the country" do
      expect(PicoPhone.possible_for_country?("5102745556", "US")).to be true
    end
  end

  describe "valid?" do
    before do
      PicoPhone.default_country = "US"
    end

    it "returns false for a number that is not valid in the default country" do
      expect(PicoPhone.valid?("0435582008")).to be false
    end

    it "returns true for a number that is valid in the default country" do
      expect(PicoPhone.valid?("5102745656")).to be true
    end
  end

  describe "valid_for_country?" do
    before do
      PicoPhone.default_country = "US"
    end

    it "returns false for a number that is not valid in the specified country" do
      expect(PicoPhone.valid_for_country?("0435582008", "US")).to be false
    end

    it "returns true for a number that is valid in the specified country" do
      expect(PicoPhone.valid_for_country?("0435582008", "AU")).to be true
    end
  end

  describe "parse" do
    it "returns an instance of PhoneNumber" do
      expect(PicoPhone.parse("5102743434")).to be_a(PicoPhone::PhoneNumber)
    end
  end

  describe "possible_countries" do
    it "returns the single matching region for an unambiguous calling code" do
      expect(PicoPhone.possible_countries("+33123456789")).to eq(["FR"])
    end

    it "returns the correct region for an unambiguous calling code when only the length is right (not the pattern)" do
      expect(PicoPhone.possible_countries("+33000000000")).to eq(["FR"])
    end

    it "disambiguates NANP numbers to the correct country" do
      expect(PicoPhone.possible_countries("+15102745656")).to eq(["US"])
    end

    it "resolves a Bahamas NANP number correctly" do
      expect(PicoPhone.possible_countries("+12423570000")).to eq(["BS"])
    end

    it "returns all matching regions for an ambiguous calling code" do
      expect(PicoPhone.possible_countries("+78005553535")).to match_array(["RU", "KZ"])
    end

    it "returns an empty array for garbage input" do
      expect(PicoPhone.possible_countries("garbage")).to eq([])
    end

    it "returns an empty array for an empty string" do
      expect(PicoPhone.possible_countries("")).to eq([])
    end
  end

  describe "valid_countries" do
    it "returns the correct region for a valid number" do
      expect(PicoPhone.valid_countries("+33123456789")).to eq(["FR"])
    end

    it "returns an empty array when the number is right length but fails pattern validation" do
      expect(PicoPhone.valid_countries("+33000000000")).to eq([])
    end

    it "disambiguates NANP numbers to the correct country" do
      expect(PicoPhone.valid_countries("+15102745656")).to eq(["US"])
    end

    it "returns an empty array for garbage input" do
      expect(PicoPhone.valid_countries("garbage")).to eq([])
    end
  end

  describe "supported_types_for_region" do
    it "returns an array of symbols" do
      expect(PicoPhone.supported_types_for_region("US")).to all(be_a(Symbol))
    end

    it "includes expected types for the US" do
      expect(PicoPhone.supported_types_for_region("US")).to include(:mobile, :toll_free, :fixed_line)
    end

    it "returns different types for different regions" do
      expect(PicoPhone.supported_types_for_region("AU")).to include(:voip, :pager)
      expect(PicoPhone.supported_types_for_region("US")).not_to include(:voip)
    end
  end

  describe "example_number" do
    it "returns a PhoneNumber instance" do
      expect(PicoPhone.example_number("AU")).to be_a(PicoPhone::PhoneNumber)
    end

    it "returns a valid number for the region" do
      expect(PicoPhone.example_number("AU").valid_for_country?("AU")).to be true
    end

    it "returns a different number for a different region" do
      expect(PicoPhone.example_number("US").e164).not_to eq(PicoPhone.example_number("AU").e164)
    end
  end

  describe "example_number_for_type" do
    it "returns a PhoneNumber instance" do
      expect(PicoPhone.example_number_for_type("US", :toll_free)).to be_a(PicoPhone::PhoneNumber)
    end

    it "returns a number of the requested type" do
      expect(PicoPhone.example_number_for_type("US", :toll_free).type).to eq(:toll_free)
    end

    it "returns a number valid for the given region" do
      expect(PicoPhone.example_number_for_type("AU", :fixed_line).valid_for_country?("AU")).to be true
    end
  end

  describe "emergency_number?" do
    it "returns true for an emergency number in the given region" do
      expect(PicoPhone.emergency_number?("911", "US")).to be true
    end

    it "returns true for an emergency number in a non-US region" do
      expect(PicoPhone.emergency_number?("999", "GB")).to be true
    end

    it "returns false for a regular phone number" do
      expect(PicoPhone.emergency_number?("5102745656", "US")).to be false
    end
  end

  describe "short_number_valid?" do
    it "returns true for a valid short number in the given region" do
      expect(PicoPhone.short_number_valid?("411", "US")).to be true
    end

    it "returns true for an emergency number" do
      expect(PicoPhone.short_number_valid?("911", "US")).to be true
    end

    it "returns false for a string that cannot be parsed" do
      expect(PicoPhone.short_number_valid?("garbage", "US")).to be false
    end
  end

  describe "short_number_cost" do
    it "returns :toll_free for an emergency number" do
      expect(PicoPhone.short_number_cost("911", "US")).to eq(:toll_free)
    end

    it "returns :unknown_cost when the number cannot be parsed" do
      expect(PicoPhone.short_number_cost("garbage", "US")).to eq(:unknown_cost)
    end
  end

  describe "supported_regions" do
    it "returns an Array" do
      expect(PicoPhone.supported_regions).to be_an(Array)
    end

    it "includes common regions" do
      expect(PicoPhone.supported_regions).to include("US", "AU", "GB", "FR")
    end

    it "returns all supported regions" do
      expect(PicoPhone.supported_regions.size).to eq(245)
    end
  end

  describe "convert_alpha_characters" do
    it "converts alpha characters in a vanity number to digits" do
      expect(PicoPhone.convert_alpha_characters("1-800-FLOWERS")).to eq("1-800-3569377")
    end

    it "leaves a number with no alpha characters unchanged" do
      expect(PicoPhone.convert_alpha_characters("+15102745656")).to eq("+15102745656")
    end
  end

  describe "number_match" do
    it "returns :exact_match for the same E.164 number" do
      expect(PicoPhone.number_match("+15102745656", "+15102745656")).to eq(:exact_match)
    end

    it "returns :nsn_match for E.164 vs national format of the same number" do
      expect(PicoPhone.number_match("+15102745656", "5102745656")).to eq(:nsn_match)
    end

    it "returns :short_nsn_match when one number is a suffix of the other's national number" do
      expect(PicoPhone.number_match("+15102745656", "2745656")).to eq(:short_nsn_match)
    end

    it "returns :no_match for two different numbers" do
      expect(PicoPhone.number_match("+15102745656", "+61435582008")).to eq(:no_match)
    end

    it "returns :invalid_number for unparseable input" do
      expect(PicoPhone.number_match("+15102745656", "garbage")).to eq(:invalid_number)
    end

    it "returns :exact_match for NANP numbers with the same digits (US and CA share calling code 1)" do
      expect(PicoPhone.number_match("+12892710892", "+12892710892")).to eq(:exact_match)
    end
  end

  describe "alpha_number?" do
    it "returns true for a vanity number containing alpha characters" do
      expect(PicoPhone.alpha_number?("1-800-FLOWERS")).to be true
    end

    it "returns false for a regular digit-only phone number" do
      expect(PicoPhone.alpha_number?("+15102745656")).to be false
    end
  end

  describe "country_calling_code" do
    it "returns 1 for US" do
      expect(PicoPhone.country_calling_code("US")).to eq(1)
    end

    it "returns 1 for CA (NANP member)" do
      expect(PicoPhone.country_calling_code("CA")).to eq(1)
    end

    it "returns 33 for FR" do
      expect(PicoPhone.country_calling_code("FR")).to eq(33)
    end

    it "returns 55 for BR" do
      expect(PicoPhone.country_calling_code("BR")).to eq(55)
    end

    it "returns 44 for GB" do
      expect(PicoPhone.country_calling_code("GB")).to eq(44)
    end

    it "returns 0 for an unknown region code" do
      expect(PicoPhone.country_calling_code("XX")).to eq(0)
    end

    it "returns 0 for an empty string" do
      expect(PicoPhone.country_calling_code("")).to eq(0)
    end
  end

  describe PicoPhone::PhoneNumber do
    before do
      PicoPhone.default_country = "US"
    end

    let(:valid_phone_number) { PicoPhone::PhoneNumber.new("5102746767") }
    let(:invalid_phone_number) { PicoPhone::PhoneNumber.new("0435582008") }
    let(:impossible_number) { PicoPhone::PhoneNumber.new("123456789000") }

    describe "#valid?" do
      it "returns true for a valid phone number" do
        expect(valid_phone_number.valid?).to be true
      end

      it "returns false for an invalid phone number" do
        expect(invalid_phone_number.valid?).to be false
      end
    end

    describe "#invalid?" do
      it "returns false for a valid phone number" do
        expect(valid_phone_number.invalid?).to be false
      end

      it "returns true for an invalid phone number" do
        expect(invalid_phone_number.invalid?).to be true
      end
    end

    describe "#possible?" do
      it "returns true for a number that is a possible number" do
        expect(valid_phone_number.possible?).to be true
      end

      it "returns false for a number that is not possible" do
        expect(impossible_number.possible?).to be false
      end
    end

    describe "#impossible?" do
      it "returns false for a number that is a possible number" do
        expect(valid_phone_number.impossible?).to be false
      end

      it "returns true for an impossible number" do
        expect(impossible_number.impossible?).to be true
      end
    end

    describe "#national" do
      let(:us_number) { PicoPhone::PhoneNumber.new("5102745155", "US") }
      let(:aus_number) { PicoPhone::PhoneNumber.new("0435582008", "AU") }
      let(:br_number) { PicoPhone::PhoneNumber.new("1155256325", "BR") }
      let(:nanp_number) { PicoPhone::PhoneNumber.new("2892710892", "CA") }

      context "for a number in the US" do
        it "returns the phone number formatted in national format for the US" do
          expect(us_number.national).to eq("(510) 274-5155")
        end
      end

      context "for a number outside the US" do
        it "returns the phone number formatted for the specified country (AU)" do
          expect(aus_number.national).to eq("0435 582 008")
        end

        it "returns the phone number formatted for the specified country (BR)" do
          expect(br_number.national).to eq("(11) 5525-6325")
        end
      end

      context "for a NANP number (Canada)" do
        it "returns the phone number formatted in national format" do
          expect(nanp_number.national).to eq("(289) 271-0892")
        end
      end
    end

    describe "#international" do
      let(:us_number) { PicoPhone::PhoneNumber.new("5102745155", "US") }
      let(:aus_number) { PicoPhone::PhoneNumber.new("0435582008", "AU") }
      let(:br_number) { PicoPhone::PhoneNumber.new("1155256325", "BR") }

      it "returns the US phone number in international format" do
        expect(us_number.international).to eq("+1 510-274-5155")
      end

      it "returns the BR phone number in international format" do
        expect(br_number.international).to eq("+55 11 5525-6325")
      end

      it "returns the AU phone number in international format" do
        expect(aus_number.international).to eq("+61 435 582 008")
      end
    end

    describe "#e164" do
      let(:us_number) { PicoPhone::PhoneNumber.new("5102745155", "US") }
      let(:aus_number) { PicoPhone::PhoneNumber.new("0435582008", "AU") }
      let(:br_number) { PicoPhone::PhoneNumber.new("1155256325", "BR") }

      it "returns the US phone number in e164 format" do
        expect(us_number.e164).to eq("+15102745155")
      end

      it "returns the AU phone number in e164 format" do
        expect(aus_number.e164).to eq("+61435582008")
      end

      it "returns the BR phone number in e164 format" do
        expect(br_number.e164).to eq("+551155256325")
      end
    end

    describe "#extension" do
      let(:ext_phone1) { PicoPhone::PhoneNumber.new("5102745656;456", "US") }
      let(:ext_phone2) { PicoPhone::PhoneNumber.new("5102745656 ext: 456", "US") }
      let(:ext_phone3) { PicoPhone::PhoneNumber.new("5102745656 ext. 456", "US") }
      let(:ext_phone4) { PicoPhone::PhoneNumber.new("5102745656x456", "US") }

      it "correctly finds the extension when separator is ;" do
        expect(ext_phone1.extension).to eq("456")
      end

      it "correctly finds the extension when separator is ext:" do
        expect(ext_phone2.extension).to eq("456")
      end

      it "correctly finds the extension when separator is ext." do
        expect(ext_phone3.extension).to eq("456")
      end

      it "correctly finds the extension when separator is x" do
        expect(ext_phone4.extension).to eq("456")
      end
    end

    describe "#has_extension?" do
      let(:ext_phone) { PicoPhone::PhoneNumber.new("5102745656;456", "US") }
      let(:no_ext_phone) { PicoPhone::PhoneNumber.new("5102745656", "US") }

      it "returns true if the phone number has an extension" do
        expect(ext_phone.has_extension?).to be true
      end

      it "returns false if the phone number doesn't have an extension" do
        expect(no_ext_phone.has_extension?).to be false
      end
    end

    describe "#full_national" do
      let(:ext_phone) { PicoPhone::PhoneNumber.new("5102745656;456", "US") }
      let(:no_ext_phone) { PicoPhone::PhoneNumber.new("5102745656", "US") }

      before do
        PicoPhone.default_extension_prefix = " ext. "
      end

      context "when the phone number has an extension" do
        it "returns the phone number formatted as national with the formatted extension appended" do
          expect(ext_phone.full_national).to eq("(510) 274-5656 ext. 456")
        end
      end

      context "when the phone number doesn't have an extension" do
        it "returns the phone number formatted as national" do
          expect(no_ext_phone.full_national).to eq("(510) 274-5656")
        end
      end
    end

    describe "#full_international" do
      let(:us_number) { PicoPhone::PhoneNumber.new("5102745155;456", "US") }
      let(:aus_number) { PicoPhone::PhoneNumber.new("0435582008;456", "AU") }
      let(:br_number) { PicoPhone::PhoneNumber.new("1155256325;456", "BR") }
      let(:us_no_extn_number) { PicoPhone::PhoneNumber.new("5102745155", "US") }

      before do
        PicoPhone.default_extension_prefix = " ext. "
      end

      it "returns the US phone number in international format with the extension appended" do
        expect(us_number.full_international).to eq("+1 510-274-5155 ext. 456")
      end

      it "returns the BR phone number in international format with the extension appended" do
        expect(br_number.full_international).to eq("+55 11 5525-6325 ext. 456")
      end

      it "returns the AU phone number in international format with the extension appended" do
        expect(aus_number.full_international).to eq("+61 435 582 008 ext. 456")
      end

      it "returns the number without extension formatted in international format" do
        expect(us_no_extn_number.full_international).to eq("+1 510-274-5155")
      end
    end

    describe "#full_e164" do
      let(:us_number) { PicoPhone::PhoneNumber.new("5102745155;456", "US") }
      let(:aus_number) { PicoPhone::PhoneNumber.new("0435582008;456", "AU") }
      let(:br_number) { PicoPhone::PhoneNumber.new("1155256325;456", "BR") }
      let(:us_no_extn_number) { PicoPhone::PhoneNumber.new("5102745155", "US") }

      before do
        PicoPhone.default_extension_prefix = " ext. "
      end

      it "returns the US phone number in e164 format with the extension appended" do
        expect(us_number.full_e164).to eq("+15102745155 ext. 456")
      end

      it "returns the AU phone number in e164 format with the extension appended" do
        expect(aus_number.full_e164).to eq("+61435582008 ext. 456")
      end

      it "returns the BR phone number in e164 format with the extension appended" do
        expect(br_number.full_e164).to eq("+551155256325 ext. 456")
      end

      it "returns the phone number withot extension in e164 format" do
        expect(us_no_extn_number.full_e164).to eq("+15102745155")
      end
    end

    describe "#country_code" do
      let(:us_number) { PicoPhone::PhoneNumber.new("5102745155", "US") }
      let(:aus_number) { PicoPhone::PhoneNumber.new("0435582008", "AU") }
      let(:br_number) { PicoPhone::PhoneNumber.new("1155256325", "BR") }

      it "returns the correct country code for US" do
        expect(us_number.country_code).to eq(1)
      end

      it "returns the correct country code for AU" do
        expect(aus_number.country_code).to eq(61)
      end

      it "returns the correct country code for BR" do
        expect(br_number.country_code).to eq(55)
      end

      it "stores the country code correctly as a Ruby integer" do
        us_number.country_code
        expect(us_number.instance_variable_get(:@country_code)).to eq(1)
      end
    end

    describe "#country" do
      context "when a default country is set" do
        before do
          PicoPhone.default_country = "US"
        end

        let(:us_number) { PicoPhone::PhoneNumber.new("5102745155", "US") }
        let(:aus_number) { PicoPhone::PhoneNumber.new("0435582008", "AU") }
        let(:br_number) { PicoPhone::PhoneNumber.new("1155256325", "BR") }

        it "returns the correct country for number in US" do
          expect(us_number.country).to eq("US")
        end

        it "returns the correct country for number in AU" do
          expect(aus_number.country).to eq("AU")
        end

        it "returns the correct country for number in BR" do
          expect(br_number.country).to eq("BR")
        end
      end

      context "when a default country is not set" do
        before do
          PicoPhone.default_country = nil
        end

        let(:us_number) { PicoPhone::PhoneNumber.new("5102745155", "US") }
        let(:aus_number) { PicoPhone::PhoneNumber.new("0435582008", "AU") }
        let(:br_number) { PicoPhone::PhoneNumber.new("1155256325", "BR") }

        it "returns the correct country for number in US" do
          expect(us_number.country).to eq("US")
        end

        it "returns the correct country for number in AU" do
          expect(aus_number.country).to eq("AU")
        end

        it "returns the correct country for number in BR" do
          expect(br_number.country).to eq("BR")
        end
      end
    end

    describe "#area_code" do
      before do
        PicoPhone.default_country = "US"
      end

      let(:us_number) { PicoPhone::PhoneNumber.new("5102745155", "US") }
      let(:aus_number) { PicoPhone::PhoneNumber.new("0435582008", "AU") }

      context "when an area code exists for the number" do
        it "returns the area code for the number" do
          expect(us_number.area_code).to eq("510")
        end
      end

      context "when an area code does not exist for the number" do
        it "returns an empty string" do
          expect(aus_number.area_code).to be_empty
        end
      end
    end

    describe "#raw_national" do
      let(:us_number) { PicoPhone::PhoneNumber.new("+15102745155", "US") }
      let(:br_number) { PicoPhone::PhoneNumber.new("+551155256325", "BR") }
      let(:aus_number) { PicoPhone::PhoneNumber.new("+61435582008", "AU") }
      let(:fr_number)  { PicoPhone::PhoneNumber.new("+33123456789", "FR") }

      context "for a number in the US" do
        it "returns only the digits that would appear when formatted as national" do
          expect(us_number.raw_national).to eq("5102745155")
        end
      end

      context "for a number outside the US" do
        it "returns only the digits of what would be the number formatted as national for that country" do
          expect(br_number.raw_national).to eq("1155256325")
        end
      end

      context "for a non-10-digit national number (AU mobile, 9 digits)" do
        it "returns all 9 digits without truncation or padding" do
          expect(aus_number.raw_national).to eq("435582008")
        end
      end

      context "for a non-10-digit national number (FR landline, 9 digits)" do
        it "returns all 9 digits without truncation or padding" do
          expect(fr_number.raw_national).to eq("123456789")
        end
      end
    end

    describe "#raw_international" do
      let(:us_number) { PicoPhone::PhoneNumber.new("+15102745155", "US") }
      let(:aus_number) { PicoPhone::PhoneNumber.new("0435582008", "AU") }

      context "for a number in the US" do
        it "returns the digits of what would be the number formatted as international" do
          expect(us_number.raw_international).to eq("15102745155")
        end
      end

      context "for a number outside of the US" do
        it "returns the digits of what would be the number formatted as international" do
          expect(aus_number.raw_international).to eq("61435582008")
        end
      end
    end

    describe "#type" do
      let(:voip_phone) { PicoPhone::PhoneNumber.new("+445631231234", "US") }
      let(:toll_free_phone) { PicoPhone::PhoneNumber.new("1-800-FLOWERS", "US") }
      let(:premium_rate_phone) { PicoPhone::PhoneNumber.new("+19004433030", "US") }
      let(:mobile_number) { PicoPhone::PhoneNumber.new("+12423570000", "US") }
      let(:fixed_line_phone) { PicoPhone::PhoneNumber.new("+12423651234", "US") }
      let(:fixed_and_mobile_phone) { PicoPhone::PhoneNumber.new("+16502531111", "US") }
      let(:personal_number_phone) { PicoPhone::PhoneNumber.new("+447031231234", "US") }
      let(:unknown_phone) { PicoPhone::PhoneNumber.new("+165025311111", "US") }

      it "returns the correct type for voip" do
        expect(voip_phone.type).to eq(:voip)
      end

      it "returns the correct type for toll_free" do
        expect(toll_free_phone.type).to eq(:toll_free)
      end

      it "returns the correct type for premium_rate" do
        expect(premium_rate_phone.type).to eq(:premium_rate)
      end

      it "returns the correct type for mobile" do
        expect(mobile_number.type).to eq(:mobile)
      end

      it "returns the correct type for fixed_line" do
        expect(fixed_line_phone.type).to eq(:fixed_line)
      end

      it "returns the correct type for fixed_line_or_mobile" do
        expect(fixed_and_mobile_phone.type).to eq(:fixed_line_or_mobile)
      end

      it "returns the correct type for personal" do
        expect(personal_number_phone.type).to eq(:personal_number)
      end

      it "returns the correct type for unknown" do
        expect(unknown_phone.type).to eq(:unknown)
      end
    end

    describe "#local_number" do
      let(:us_number) { PicoPhone::PhoneNumber.new("5102745656", "US") }
      let(:aus_number) { PicoPhone::PhoneNumber.new("0435582008", "AU") }

      it "returns the subscriber number after the area code" do
        expect(us_number.local_number).to eq("2745656")
      end

      it "returns the full national significant number when there is no geographical area code" do
        expect(aus_number.local_number).to eq("435582008")
      end
    end

    describe "#geo_name" do
      let(:us_number) { PicoPhone::PhoneNumber.new("5102745656", "US") }
      let(:aus_number) { PicoPhone::PhoneNumber.new("0435582008", "AU") }

      it "returns an area-level description in English by default" do
        expect(us_number.geo_name).to eq("California")
      end

      it "accepts a language code" do
        expect(us_number.geo_name("de")).to be_a(String)
      end

      it "falls back to the country name when no finer description is available" do
        expect(aus_number.geo_name).to eq("Australia")
      end

      it "returns an empty string for a number that could not be parsed" do
        expect(PicoPhone::PhoneNumber.new("garbage").geo_name).to eq("")
      end
    end

    describe "#carrier_name" do
      let(:in_number) { PicoPhone::PhoneNumber.new("6001234567", "IN") }
      let(:us_number) { PicoPhone::PhoneNumber.new("5102745656", "US") }

      it "returns the carrier name in English by default" do
        expect(in_number.carrier_name).to eq("Reliance Jio")
      end

      it "accepts a language code" do
        expect(in_number.carrier_name("de")).to be_a(String)
      end

      it "returns an empty string when no carrier mapping exists for the prefix" do
        expect(us_number.carrier_name).to eq("")
      end

      it "returns an empty string for a number that could not be parsed" do
        expect(PicoPhone::PhoneNumber.new("garbage").carrier_name).to eq("")
      end
    end

    describe "#timezones" do
      let(:nanp_number)   { PicoPhone::PhoneNumber.new("+12082123456") }
      let(:india_number)  { PicoPhone::PhoneNumber.new("6001234567", "IN") }
      let(:france_number) { PicoPhone::PhoneNumber.new("+33612345678") }

      it "returns a single timezone for an unambiguous prefix" do
        expect(france_number.timezones).to eq(["Europe/Paris"])
      end

      it "returns multiple timezones when the prefix spans more than one zone" do
        expect(nanp_number.timezones).to eq(["America/Boise", "America/Los_Angeles"])
      end

      it "falls back to the country-level entry when no finer prefix match exists" do
        expect(india_number.timezones).to eq(["Asia/Calcutta"])
      end

      it "returns an empty array for a number that could not be parsed" do
        expect(PicoPhone::PhoneNumber.new("garbage").timezones).to eq([])
      end
    end

    describe "#truncate" do
      it "returns a new PhoneNumber with trailing digits removed when the number is too long" do
        long_number = PicoPhone::PhoneNumber.new("+151027456560000")
        result = long_number.truncate
        expect(result).to be_a(PicoPhone::PhoneNumber)
        expect(result.e164).to eq("+15102745656")
      end

      it "does not mutate the receiver" do
        long_number = PicoPhone::PhoneNumber.new("+151027456560000")
        long_number.truncate
        expect(long_number.e164).not_to eq("+15102745656")
      end

      it "returns nil when the number is already valid" do
        valid_number = PicoPhone::PhoneNumber.new("+15102745656")
        expect(valid_number.truncate).to be_nil
      end

      it "returns nil for a number that could not be parsed" do
        expect(PicoPhone::PhoneNumber.new("garbage").truncate).to be_nil
      end
    end

    describe "#valid_for_country?" do
      let(:us_number) { PicoPhone::PhoneNumber.new("5102745656", "US") }

      it "returns true when the number is valid for the given country" do
        expect(us_number.valid_for_country?("US")).to be true
      end

      it "returns false when the number is not valid for the given country" do
        expect(us_number.valid_for_country?("AU")).to be false
      end
    end

    describe "#invalid_for_country?" do
      let(:us_number) { PicoPhone::PhoneNumber.new("5102745656", "US") }

      it "returns false when the number is valid for the given country" do
        expect(us_number.invalid_for_country?("US")).to be false
      end

      it "returns true when the number is not valid for the given country" do
        expect(us_number.invalid_for_country?("AU")).to be true
      end
    end

    describe "#original" do
      it "returns the input string as passed to the constructor" do
        expect(PicoPhone::PhoneNumber.new("5102745656", "US").original).to eq("5102745656")
      end

      it "returns the original string even when parsing fails" do
        expect(PicoPhone::PhoneNumber.new("garbage").original).to eq("garbage")
      end

      it "returns nil when nil was passed as input" do
        expect(PicoPhone::PhoneNumber.new(nil).original).to be_nil
      end
    end

    describe "#to_s" do
      it "returns the e164 format when the number is valid" do
        expect(PicoPhone::PhoneNumber.new("5102745656", "US").to_s).to eq("+15102745656")
      end

      it "returns the original input string when the number is invalid" do
        expect(PicoPhone::PhoneNumber.new("garbage").to_s).to eq("garbage")
      end

      it "returns an empty string when nil was passed as input" do
        expect(PicoPhone::PhoneNumber.new(nil).to_s).to eq("")
      end
    end

    describe "#format_in_original_format" do
      it "returns the number in international format when it was entered with a + prefix" do
        phone = PicoPhone::PhoneNumber.new("+15102745656", "US")
        expect(phone.format_in_original_format).to eq("+1 510-274-5656")
      end

      it "returns the number in national format when it was entered without a country code" do
        phone = PicoPhone::PhoneNumber.new("5102745656", "US")
        expect(phone.format_in_original_format).to eq("(510) 274-5656")
      end
    end

    describe "#out_of_country_format" do
      let(:us_number) { PicoPhone::PhoneNumber.new("+15102745656", "US") }

      it "returns the number formatted for dialing from within the same NANP region" do
        expect(us_number.out_of_country_format("US")).to eq("1 (510) 274-5656")
      end

      it "returns the number formatted for dialing from the UK" do
        expect(us_number.out_of_country_format("GB")).to eq("00 1 510-274-5656")
      end

      it "returns the number formatted for dialing from Australia" do
        expect(us_number.out_of_country_format("AU")).to eq("0011 1 510-274-5656")
      end
    end

    describe "#mobile_dialing_format" do
      let(:us_number) { PicoPhone::PhoneNumber.new("+15102745656", "US") }

      it "returns the number formatted for mobile dialing from the US" do
        expect(us_number.mobile_dialing_format("US")).to eq("+1 510-274-5656")
      end

      it "returns the number formatted for mobile dialing from the UK" do
        expect(us_number.mobile_dialing_format("GB")).to eq("+1 510-274-5656")
      end
    end

    describe "#possible_countries" do
      it "returns the correct region for an unambiguous calling code" do
        expect(PicoPhone::PhoneNumber.new("+33123456789").possible_countries).to eq(["FR"])
      end

      it "returns the region when the number is right length but fails pattern validation" do
        expect(PicoPhone::PhoneNumber.new("+33000000000").possible_countries).to eq(["FR"])
      end

      it "disambiguates NANP numbers to the correct country" do
        expect(PicoPhone::PhoneNumber.new("+15102745656").possible_countries).to eq(["US"])
      end

      it "returns all matching regions for an ambiguous calling code" do
        expect(PicoPhone::PhoneNumber.new("+78005553535").possible_countries).to match_array(["RU", "KZ"])
      end
    end

    describe "#valid_countries" do
      it "returns the correct region for a valid number" do
        expect(PicoPhone::PhoneNumber.new("+33123456789").valid_countries).to eq(["FR"])
      end

      it "returns an empty array when the number is right length but fails pattern validation" do
        expect(PicoPhone::PhoneNumber.new("+33000000000").valid_countries).to eq([])
      end

      it "disambiguates NANP numbers to the correct country" do
        expect(PicoPhone::PhoneNumber.new("+15102745656").valid_countries).to eq(["US"])
      end
    end

    describe "#possible_with_reason" do
      it "returns :is_possible for a valid number" do
        expect(PicoPhone::PhoneNumber.new("+15102745656", "US").possible_with_reason).to eq(:is_possible)
      end

      it "returns :too_short for a number with too few digits" do
        expect(PicoPhone::PhoneNumber.new("123", "US").possible_with_reason).to eq(:too_short)
      end

      it "returns :too_long for a number with too many digits" do
        expect(PicoPhone::PhoneNumber.new("123456789000", "US").possible_with_reason).to eq(:too_long)
      end
    end

    describe "#geographical?" do
      it "returns true for a US fixed-line number with a geographic area code" do
        expect(PicoPhone::PhoneNumber.new("+15102745656", "US").geographical?).to be true
      end

      it "returns true for an AU fixed-line number" do
        expect(PicoPhone::PhoneNumber.new("+61212345678", "AU").geographical?).to be true
      end

      it "returns false for an AU mobile number" do
        expect(PicoPhone::PhoneNumber.new("+61435582008", "AU").geographical?).to be false
      end

      it "returns false for a toll-free number" do
        expect(PicoPhone::PhoneNumber.new("+18005551234", "US").geographical?).to be false
      end
    end

    describe "#possible_for_type?" do
      it "returns true when the number length is consistent with the given type" do
        expect(PicoPhone::PhoneNumber.new("+15102745656", "US").possible_for_type?(:fixed_line_or_mobile)).to be true
      end

      it "returns true for an AU mobile number checked against :mobile" do
        expect(PicoPhone::PhoneNumber.new("+61435582008", "AU").possible_for_type?(:mobile)).to be true
      end
    end

    describe "#can_be_internationally_dialled?" do
      it "returns true for a regular phone number" do
        expect(PicoPhone::PhoneNumber.new("+15102745656", "US").can_be_internationally_dialled?).to be true
      end

      it "returns true for a toll-free number that is accessible internationally" do
        expect(PicoPhone::PhoneNumber.new("+18005551234", "US").can_be_internationally_dialled?).to be true
      end
    end

    describe "#match_type" do
      let(:phone) { PicoPhone.parse("+15102745656") }

      it "returns :exact_match when passed the same E.164 string" do
        expect(phone.match_type("+15102745656")).to eq(:exact_match)
      end

      it "returns :exact_match when passed a PhoneNumber parsed from the same number" do
        expect(phone.match_type(PicoPhone.parse("5102745656", "US"))).to eq(:exact_match)
      end

      it "returns :nsn_match when passed the national number as a string (no country code)" do
        expect(phone.match_type("5102745656")).to eq(:nsn_match)
      end

      it "returns :no_match when passed a different number" do
        expect(phone.match_type("+61435582008")).to eq(:no_match)
      end

      it "returns :invalid_number when passed unparseable input" do
        expect(phone.match_type("garbage")).to eq(:invalid_number)
      end
    end

    describe "with invalid input" do
      before { PicoPhone.default_country = "US" }

      context "when initialized with nil" do
        let(:phone) { PicoPhone::PhoneNumber.new(nil) }

        it "returns false for possible?" do
          expect(phone.possible?).to be false
        end

        it "returns false for valid?" do
          expect(phone.valid?).to be false
        end

        it "does not set instance variables on the PhoneNumber class" do
          phone # force initialization
          expect(PicoPhone::PhoneNumber.instance_variable_defined?(:@possible)).to be false
          expect(PicoPhone::PhoneNumber.instance_variable_defined?(:@valid)).to be false
        end
      end

      context "when initialized with a string that cannot be parsed" do
        let(:phone) { PicoPhone::PhoneNumber.new("not a phone number") }

        it "returns false for possible?" do
          expect(phone.possible?).to be false
        end

        it "returns false for valid?" do
          expect(phone.valid?).to be false
        end

        it "does not set instance variables on the PhoneNumber class" do
          phone # force initialization
          expect(PicoPhone::PhoneNumber.instance_variable_defined?(:@possible)).to be false
          expect(PicoPhone::PhoneNumber.instance_variable_defined?(:@valid)).to be false
        end

        it "does not affect subsequently created valid numbers" do
          phone # trigger failed parse
          valid = PicoPhone::PhoneNumber.new("5102745155", "US")
          expect(valid.possible?).to be true
          expect(valid.valid?).to be true
        end
      end
    end
  end
end
