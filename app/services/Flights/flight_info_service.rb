module Flights
  class FlightInfoService
    API_KEY = ENV.fetch('API_KEY', nil)
    BASE_URL = 'http://api.aviationstack.com/v1/flights'.freeze

    attr_reader :incoming_flight_number, :airline_iata, :airline_icao, :flight_number

    def initialize(incoming_flight_number:)
      @incoming_flight_number = incoming_flight_number
      @flight_number = nil
      @airline_iata = nil
      @airline_icao = nil
    end

    def fetch_flight_info
      extract_prefix
      extract_numbers

      uri = URI(BASE_URL)
      uri.query = URI.encode_www_form(build_flight_params)

      response = Net::HTTP.get_response(uri)
      api_response = JSON.parse(response.body)

      if api_response['data'].empty?
        build_fail_response("No route found for flight number #{incoming_flight_number}")
      elsif api_response['pagination']['count'] == 1
        build_single_route_response(api_response['data'].first)
      else
        build_multiple_route_response(api_response['data'])
      end
    rescue StandardError => e
      build_fail_response(e.message)
    end

    private

    def extract_prefix
      non_numeric_part = if incoming_flight_number[/\A(\d*[A-Za-z]+)/, 1].length < 2
                           incoming_flight_number[0..1]
                         else
                           incoming_flight_number[/\A(\d*[A-Za-z]+)/, 1]
                         end
      if non_numeric_part.length == 2
        @airline_iata = non_numeric_part.upcase
      elsif non_numeric_part.length == 3
        @airline_icao = non_numeric_part.upcase
      end
    end

    def extract_numbers
      prefix = extract_prefix
      @flight_number = incoming_flight_number.sub(/^#{prefix}/, '').rjust(4, '0')
    end

    def build_flight_params
      {
        access_key: API_KEY,
        flight_number: flight_number,
        airline_iata: airline_iata,
        airline_icao: airline_icao
      }.compact
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
  end
end
