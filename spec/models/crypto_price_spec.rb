require "rails_helper"

RSpec.describe CryptoPrice do
  describe ".coin_id_for" do
    it "maps a known symbol to its CoinGecko id" do
      expect(described_class.coin_id_for("btc")).to eq("bitcoin")
    end

    it "is case-insensitive" do
      expect(described_class.coin_id_for("BTC")).to eq("bitcoin")
    end

    it "returns nil for an unknown symbol" do
      expect(described_class.coin_id_for("not_a_coin")).to be_nil
    end
  end

  describe "caching behavior" do
    describe ".cached_for" do
      it "returns nil when nothing has ever been recorded for the symbol" do
        expect(described_class.cached_for("btc")).to be_nil
      end

      it "does not cache a nil result (skip_nil), so a later record shows up immediately" do
        expect(described_class.cached_for("btc")).to be_nil

        described_class.record_price!(symbol: "btc", price: 65000.0)

        expect(described_class.cached_for("btc")[:price]).to eq(65000.0)
      end

      it "serves from the database on a cache miss and populates the cache" do
        described_class.record_price!(symbol: "btc", price: 65000.0)
        Rails.cache.delete(described_class.cache_key_for("btc", "usd"))

        expect(described_class.cached_for("btc")[:price]).to eq(65000.0)
        expect(Rails.cache.exist?(described_class.cache_key_for("btc", "usd"))).to be(true)
      end

      it "serves from the cache without hitting the database on a cache hit" do
        described_class.record_price!(symbol: "btc", price: 65000.0)

        expect(described_class).not_to receive(:find_by)

        expect(described_class.cached_for("btc")[:price]).to eq(65000.0)
      end
    end

    describe ".record_price!" do
      it "writes to the database" do
        described_class.record_price!(symbol: "btc", price: 65000.0)

        expect(described_class.find_by(symbol: "btc").price.to_f).to eq(65000.0)
      end

      it "writes through to the cache immediately" do
        described_class.record_price!(symbol: "btc", price: 65000.0)

        cached = Rails.cache.read(described_class.cache_key_for("btc", "usd"))
        expect(cached[:price]).to eq(65000.0)
      end

      it "upserts rather than duplicating rows for the same symbol" do
        described_class.record_price!(symbol: "btc", price: 65000.0)
        described_class.record_price!(symbol: "btc", price: 66000.0)

        expect(described_class.where(symbol: "btc").count).to eq(1)
        expect(described_class.find_by(symbol: "btc").price.to_f).to eq(66000.0)
      end
    end
  end
end
