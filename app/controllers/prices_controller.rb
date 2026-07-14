class PricesController < ApplicationController
  # GET /prices/:symbol
  def show
    symbol = params[:symbol].to_s.downcase

    unless CryptoPrice.coin_id_for(symbol)
      return render json: { error: "Unknown symbol '#{symbol}'" }, status: :not_found
    end

    data = CryptoPrice.cached_for(symbol)

    if data.nil?
      return render json: { error: "No price recorded yet for '#{symbol}'" }, status: :not_found
    end

    render json: {
      symbol: symbol,
      price: data[:price],
      vs_currency: data[:vs_currency],
      fetched_at: data[:fetched_at].iso8601,
      stale: data[:fetched_at] < Rails.application.config.x.price_stale_ttl.ago
    }
  end
end
