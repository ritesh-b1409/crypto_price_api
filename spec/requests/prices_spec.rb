require "rails_helper"

RSpec.describe "GET /prices/:symbol" do
  it "returns 404 for a symbol we don't recognize" do
    get "/prices/notacoin"

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)["error"]).to match(/Unknown symbol/)
  end

  it "returns 404 when the symbol is known but nothing has been fetched yet" do
    get "/prices/btc"

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)["error"]).to match(/No price recorded/)
  end

  it "returns the last stored price for a known, recorded symbol" do
    CryptoPrice.record_price!(symbol: "btc", price: 65000.5, fetched_at: 30.seconds.ago)

    get "/prices/btc"

    body = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    expect(body["symbol"]).to eq("btc")
    expect(body["price"]).to eq(65000.5)
    expect(body["stale"]).to be(false)
  end

  it "flags the price as stale once it's older than the fallback window" do
    CryptoPrice.record_price!(symbol: "btc", price: 65000.5, fetched_at: 2.days.ago)

    get "/prices/btc"

    expect(JSON.parse(response.body)["stale"]).to be(true)
  end

  it "is case-insensitive on the symbol" do
    CryptoPrice.record_price!(symbol: "btc", price: 65000.5)

    get "/prices/BTC"

    expect(response).to have_http_status(:ok)
  end
end
