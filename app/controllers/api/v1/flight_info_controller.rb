module Api
  module V1
    class FlightInfoController < ApplicationController
      def index
        flight_number = params.require(:flight_number)
        if flight_number.length > 7
          render json: { error: 'Invalid flight number' }, status: :unprocessable_entity
          return
        end

        flight_info_service = Flights::FlightInfoService.new(incoming_flight_number: flight_number)
        flight_info = flight_info_service.fetch_flight_info

        if flight_info[:status] == 'OK'
          render json: flight_info
        else
          render json: flight_info, status: :not_found
        end
      end
    end
  end
end
