Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :flight_info, only: :index
    end
  end
end
