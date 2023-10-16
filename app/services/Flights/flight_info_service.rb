module Flights
  class FlightInfoService
    API_KEY = ENV.fetch('API_KEY', nil)
    BASE_URL = 'http://api.aviationstack.com/v1/flights'.freeze

    attr_reader :incoming_flight_number, :carrier_iata, :carrier_icao, :flight_number

    def initialize(incoming_flight_number:)
      @incoming_flight_number = incoming_flight_number
      @carrier_iata = nil
      @carrier_icao = nil
      @flight_number = extract_flight_number
      @full_flight_number = full_flight_number
    end

    def fetch_flight_info
      extract_prefix
      uri = URI(BASE_URL)
      uri.query = URI.encode_www_form(access_key: API_KEY, flight_number: full_flight_number)

      response = Net::HTTP.get_response(uri)
      api_response = JSON.parse(response.body)

      if api_response['results'].nil?
        build_fail_response("No route found for flight number #{full_flight_number}")
      elsif api_response['results'].size == 1
        build_single_route_response(api_response['results'].first)
      else
        build_multiple_route_response(api_response['results'])
      end
    rescue StandardError => e
      build_fail_response(e.message)
    end

    private

    def extract_prefix
      non_numeric_part = incoming_flight_number.scan(/\D/).join

      if non_numeric_part.length == 2
        @carrier_iata = non_numeric_part.upcase
      elsif non_numeric_part.length == 3
        @carrier_icao = non_numeric_part.upcase
      end
    end

    def extract_flight_number
      numeric_part = incoming_flight_number.scan(/\d/).join

      if numeric_part.length == 4
        numeric_part
      elsif numeric_part.length < 4
        numeric_part.rjust(4, '0')
      end
    end

    def build_single_route_response(route_data)
      departure = route_data['departure']
      arrival = route_data['arrival']
      distance = route_data['distance']

      {
        route: {
          departure: {
            iata: departure['iata'],
            icao: departure['icao'],
            city: departure['airport'],
            country: departure['country'],
            latitude: departure['latitude'],
            longitude: departure['longitude']
          },
          arrival: {
            iata: arrival['iata'],
            icao: arrival['icao'],
            city: arrival['airport'],
            country: arrival['country']
          }
        },
        status: 'OK',
        distance: distance,
        error_message: nil
      }
    end

    def build_multiple_route_response(routes_data)
      route_info = routes_data.map do |route_data|
        departure = route_data['departure']
        arrival = route_data['arrival']
        distance = route_data['distance']

        {
          departure: {
            iata: departure['iata'],
            icao: departure['icao'],
            city: departure['airport'],
            country: departure['country'],
            latitude: departure['latitude'],
            longitude: departure['longitude']
          },
          arrival: {
            iata: arrival['iata'],
            icao: arrival['icao'],
            city: arrival['airport'],
            country: arrival['country']
          },
          distance: distance
        }
      end

      {
        route: route_info,
        status: 'OK',
        distance: calculate_total_distance(routes_data),
        error_message: nil
      }
    end

    def build_fail_response(error_message)
      {
        route: nil,
        status: 'FAIL',
        distance: 0,
        error_message: error_message
      }
    end

    def calculate_total_distance(routes_data)
      routes_data.sum { |route| route['distance'] }
    end

    def full_flight_number
      if carrier_icao.nil?
        @full_flight_number = "#{carrier_iata}#{flight_number}"
      elsif carrier_iata.nil?
        @full_flight_number = "#{carrier_icao}#{flight_number}"
      end
    end
  end
end
