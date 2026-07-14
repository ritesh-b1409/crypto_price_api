# Uses the `whenever` gem to write this into cron.
# Generate with: whenever --update-crontab
every 1.minute do
  runner "FetchCryptoPriceJob.perform_later"
end
