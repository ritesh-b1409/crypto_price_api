Rails.application.routes.draw do
  get "prices/:symbol", to: "prices#show", constraints: { symbol: /[a-zA-Z0-9]+/ }
end
