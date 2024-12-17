# frozen_string_literal: true

RSpec.describe PicoPhone do
  it "has a version number" do
    expect(PicoPhone::VERSION).not_to be nil
  end

  it "stores a default_country" do
    PicoPhone.default_country = "US"

    expect(PicoPhone.default_country).to eq("US")
  end

  it "stores a default extension prefix" do
    PicoPhone.default_extension_prefix = "ext."

    expect(PicoPhone.instance_variable_get(:@default_extn_prefix)).to eq("ext.")
  end

  describe "possible?" do
    it "returns false for a string that is not a phone number" do
      expect(PicoPhone.possible?("Not a number")).to be false
    end

    it "returns true for a string that contains a phone number among other words" do
      expect(PicoPhone.possible?("This is my phone: 5102745656")).to be true
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
  end
end
