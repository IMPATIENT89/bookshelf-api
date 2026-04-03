require "rails_helper"

RSpec.describe Author, type: :model do
  subject { build(:author) }

  describe "associations" do
    it "has_many books with restrict_with_error" do
      pending "requires Book model"
      is_expected.to have_many(:books).dependent(:restrict_with_error)
    end
  end

  describe "validations" do
    describe "first_name" do
      it { is_expected.to validate_presence_of(:first_name) }
      it { is_expected.to validate_length_of(:first_name).is_at_most(100) }
    end

    describe "last_name" do
      it { is_expected.to validate_presence_of(:last_name) }
      it { is_expected.to validate_length_of(:last_name).is_at_most(100) }
    end

    describe "bio" do
      it { is_expected.to validate_length_of(:bio).is_at_most(2000) }
      it { is_expected.not_to validate_presence_of(:bio) }
    end

    describe "birth_year" do
      it { is_expected.to validate_numericality_of(:birth_year).only_integer.is_less_than_or_equal_to(Date.current.year) }
      it { is_expected.to allow_value(nil).for(:birth_year) }
    end

    describe "death_year" do
      it { is_expected.to validate_numericality_of(:death_year).only_integer }
      it { is_expected.to allow_value(nil).for(:death_year) }
    end

    describe "death_year_after_birth_year" do
      it "is valid when death_year equals birth_year" do
        author = build(:author, birth_year: 1950, death_year: 1950)
        expect(author).to be_valid
      end

      it "is valid when death_year is after birth_year" do
        author = build(:author, birth_year: 1950, death_year: 2020)
        expect(author).to be_valid
      end

      it "is invalid when death_year is before birth_year" do
        author = build(:author, birth_year: 1950, death_year: 1940)
        expect(author).not_to be_valid
        expect(author.errors[:death_year]).to include("must be greater than or equal to birth year")
      end

      it "is valid when only birth_year is present" do
        author = build(:author, birth_year: 1950, death_year: nil)
        expect(author).to be_valid
      end

      it "is valid when only death_year is present" do
        author = build(:author, birth_year: nil, death_year: 2020)
        expect(author).to be_valid
      end
    end

    describe "website" do
      it { is_expected.to allow_value("").for(:website) }
      it { is_expected.to allow_value("https://example.com").for(:website) }
      it { is_expected.to allow_value("http://example.com").for(:website) }
      it { is_expected.not_to allow_value("ftp://example.com").for(:website) }
      it { is_expected.not_to allow_value("not-a-url").for(:website) }
    end
  end

  describe "scopes" do
    describe ".by_search" do
      let!(:tolkien) { create(:author, first_name: "John", last_name: "Tolkien") }
      let!(:rowling) { create(:author, first_name: "Joanne", last_name: "Rowling") }
      let!(:king) { create(:author, first_name: "Stephen", last_name: "King") }

      it "matches partial first_name case-insensitively" do
        expect(Author.by_search("jo")).to contain_exactly(tolkien, rowling)
      end

      it "matches partial last_name case-insensitively" do
        expect(Author.by_search("king")).to contain_exactly(king)
      end

      it "returns no results when nothing matches" do
        expect(Author.by_search("xyz")).to be_empty
      end
    end
  end

  describe "#full_name" do
    it "returns first_name and last_name joined by a space" do
      author = build(:author, first_name: "Jane", last_name: "Austen")
      expect(author.full_name).to eq("Jane Austen")
    end
  end

  describe "sanitizable behavior" do
    it "strips leading and trailing whitespace from string fields" do
      author = build(:author, first_name: "  Jane  ", last_name: "  Austen  ")
      author.valid?
      expect(author.first_name).to eq("Jane")
      expect(author.last_name).to eq("Austen")
    end

    it "strips HTML tags from string fields" do
      author = build(:author, first_name: "<b>Jane</b>", last_name: "<em>Austen</em>")
      author.valid?
      expect(author.first_name).to eq("Jane")
      expect(author.last_name).to eq("Austen")
    end

    it "strips HTML tags from bio" do
      author = build(:author, bio: "<script>alert('xss')</script>Some bio text")
      author.valid?
      expect(author.bio).to eq("alert('xss')Some bio text")
    end
  end
end
