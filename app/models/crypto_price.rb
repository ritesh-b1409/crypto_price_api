class CryptoPrice < ApplicationRecord
  validates :symbol, :vs_currency, :price, :fetched_at, presence: true
  validates :symbol, uniqueness: { scope: :vs_currency }

  def self.coin_id_for(symbol)
    Rails.application.config.x.coingecko_symbol_map[symbol.to_s.downcase]
  end

  def self.cached_for(symbol, vs_currency: "usd")
    symbol = symbol.to_s.downcase

    Rails.cache.fetch(cache_key_for(symbol, vs_currency),
                       expires_in: Rails.application.config.x.price_cache_ttl,
                       skip_nil: true) do
      record = find_by(symbol: symbol, vs_currency: vs_currency)
      serialize(record) if record
    end
  end

  def self.record_price!(symbol:, price:, vs_currency: "usd", fetched_at: Time.current)
    record = find_or_initialize_by(symbol: symbol.to_s.downcase, vs_currency: vs_currency)
    record.price = price
    record.fetched_at = fetched_at
    record.save!

    Rails.cache.write(cache_key_for(record.symbol, vs_currency),
                       serialize(record),
                       expires_in: Rails.application.config.x.price_cache_ttl)
    record
  end

  def self.cache_key_for(symbol, vs_currency)
    "crypto_price:#{symbol.to_s.downcase}:#{vs_currency}"
  end

  def self.serialize(record)
    {
      price: record.price.to_f,
      vs_currency: record.vs_currency,
      fetched_at: record.fetched_at
    }
  end
end
