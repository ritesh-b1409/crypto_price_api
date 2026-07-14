namespace :crypto do
  desc "Fetch and store the latest prices for all configured symbols right now"
  task fetch_prices: :environment do
    FetchCryptoPriceJob.perform_now
  end
end
