module Api
  module V1
    class FlightInfoController < ApplicationController
      def index
        flight_info_service = Flights::FlightInfoService.new(incoming_flight_number: params.require(:flight_number))
        flight_info = flight_info_service.fetch_flight_info

        if flight_info[:status] == 'OK'
          render json: flight_info
        else
          render json: flight_info, status: :bad_request
        end
      end
    end
  end
end
