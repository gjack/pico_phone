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
  end
end
