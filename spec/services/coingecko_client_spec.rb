require "rails_helper"

RSpec.describe CoingeckoClient do
  subject(:client) { described_class.new(api_key: "test-key") }

  let(:url) { "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd" }

  describe "#fetch_price" do
    context "when CoinGecko responds successfully" do
      before do
        stub_request(:get, url)
          .to_return(
            status: 200,
            body: { bitcoin: { usd: 65000.42 } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns the price as a float" do
        expect(client.fetch_price("bitcoin")).to eq(65000.42)
      end

      it "sends the API key header" do
        client.fetch_price("bitcoin")
        expect(WebMock).to have_requested(:get, url)
          .with(headers: { "x-cg-demo-api-key" => "test-key" })
      end
    end

    context "when CoinGecko returns a non-success status" do
      before { stub_request(:get, url).to_return(status: 500, body: "boom") }

      it "raises CoingeckoClient::Error" do
        expect { client.fetch_price("bitcoin") }
          .to raise_error(CoingeckoClient::Error, /Unexpected status 500/)
      end
    end

    context "when CoinGecko returns a body with no price for the requested coin" do
      before do
        stub_request(:get, url).to_return(
          status: 200,
          body: {}.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end

      it "raises CoingeckoClient::Error" do
        expect { client.fetch_price("bitcoin") }
          .to raise_error(CoingeckoClient::Error, /No price data/)
      end
    end

    context "when the network request times out" do
      before { stub_request(:get, url).to_timeout }

      it "raises CoingeckoClient::Error rather than the raw Faraday error" do
        expect { client.fetch_price("bitcoin") }
          .to raise_error(CoingeckoClient::Error, /Network error/)
      end
    end

    context "when the connection is refused" do
      before { stub_request(:get, url).to_raise(Faraday::ConnectionFailed.new("refused")) }

      it "raises CoingeckoClient::Error" do
        expect { client.fetch_price("bitcoin") }
          .to raise_error(CoingeckoClient::Error, /Network error/)
      end
    end
  end
end
