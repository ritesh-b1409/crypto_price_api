# Runs (via scheduler, see config/schedule.rb) roughly every minute.
# Fetches the latest price for every configured symbol and stores it.
#
# Fallback behavior: each symbol is fetched independently, and any
# failure for a given symbol is rescued and logged WITHOUT touching that
# symbol's stored/cached price. This means CryptoPrice.cached_for always
# keeps returning the last known good value when CoinGecko is down.
class FetchCryptoPriceJob < ApplicationJob
  queue_as :default

  def perform(symbols = default_symbols, client: CoingeckoClient.new)
    Array(symbols).each do |symbol|
      fetch_and_store(client, symbol)
    end
  end

  private

  def fetch_and_store(client, symbol)
    coin_id = CryptoPrice.coin_id_for(symbol)

    if coin_id.nil?
      Rails.logger.warn("[FetchCryptoPriceJob] Unknown symbol '#{symbol}', skipping")
      return
    end

    price = client.fetch_price(coin_id)
    CryptoPrice.record_price!(symbol: symbol, price: price)
    Rails.logger.info("[FetchCryptoPriceJob] Updated #{symbol} => #{price}")
  rescue CoingeckoClient::Error => e
    Rails.logger.warn(
      "[FetchCryptoPriceJob] Failed to fetch '#{symbol}': #{e.message}. " \
      "Serving last known price instead."
    )
  end

  def default_symbols
    Rails.application.config.x.coingecko_symbol_map.keys
  end
end
