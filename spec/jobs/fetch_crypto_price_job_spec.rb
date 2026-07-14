require "rails_helper"

RSpec.describe FetchCryptoPriceJob do
  let(:client) { instance_double(CoingeckoClient) }

  describe "job logic" do
    it "fetches and stores a price for every configured symbol" do
      allow(client).to receive(:fetch_price).with("bitcoin").and_return(65000.0)
      allow(client).to receive(:fetch_price).with("ethereum").and_return(3200.0)
      allow(client).to receive(:fetch_price).with("solana").and_return(150.0)
      allow(client).to receive(:fetch_price).with("dogecoin").and_return(0.15)
      allow(client).to receive(:fetch_price).with("tether").and_return(1.0)

      described_class.perform_now(client: client)

      expect(CryptoPrice.find_by(symbol: "btc").price.to_f).to eq(65000.0)
      expect(CryptoPrice.find_by(symbol: "eth").price.to_f).to eq(3200.0)
    end

    it "only fetches the symbols it's given when a subset is passed in" do
      allow(client).to receive(:fetch_price).with("bitcoin").and_return(65000.0)

      described_class.perform_now(%w[btc], client: client)

      expect(client).not_to have_received(:fetch_price).with("ethereum")
      expect(CryptoPrice.find_by(symbol: "btc")).to be_present
    end

    it "skips unknown symbols without raising" do
      allow(client).to receive(:fetch_price)

      expect { described_class.perform_now(%w[not_a_real_coin], client: client) }
        .not_to raise_error
      expect(client).not_to have_received(:fetch_price)
    end

    it "continues on to the next symbol after one fails" do
      allow(client).to receive(:fetch_price).with("bitcoin")
        .and_raise(CoingeckoClient::Error, "timeout")
      allow(client).to receive(:fetch_price).with("ethereum").and_return(3200.0)

      described_class.perform_now(%w[btc eth], client: client)

      expect(CryptoPrice.find_by(symbol: "eth").price.to_f).to eq(3200.0)
    end
  end

  describe "fallback logic" do
    before do
      # Seed an existing "last known good" price, as if a prior successful
      # run had already happened.
      CryptoPrice.record_price!(symbol: "btc", price: 60000.0, fetched_at: 5.minutes.ago)
    end

    it "does not overwrite the stored price when the API call fails" do
      allow(client).to receive(:fetch_price).with("bitcoin")
        .and_raise(CoingeckoClient::Error, "CoinGecko is down")

      described_class.perform_now(%w[btc], client: client)

      expect(CryptoPrice.find_by(symbol: "btc").price.to_f).to eq(60000.0)
    end

    it "leaves the cached value intact so reads keep serving the last known price" do
      allow(client).to receive(:fetch_price).with("bitcoin")
        .and_raise(CoingeckoClient::Error, "CoinGecko is down")

      described_class.perform_now(%w[btc], client: client)

      expect(CryptoPrice.cached_for("btc")[:price]).to eq(60000.0)
    end

    it "logs a warning instead of raising when the API call fails" do
      allow(client).to receive(:fetch_price).with("bitcoin")
        .and_raise(CoingeckoClient::Error, "CoinGecko is down")
      allow(Rails.logger).to receive(:warn)

      expect { described_class.perform_now(%w[btc], client: client) }.not_to raise_error
      expect(Rails.logger).to have_received(:warn).with(/Serving last known price/)
    end

    it "resumes overwriting the stored price once the API recovers" do
      allow(client).to receive(:fetch_price).with("bitcoin").and_return(61234.0)

      described_class.perform_now(%w[btc], client: client)

      expect(CryptoPrice.find_by(symbol: "btc").price.to_f).to eq(61234.0)
    end
  end
end
