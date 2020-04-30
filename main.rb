# Malika Liyanage 101231500
require 'net/http'
require 'json'

class WeatherInformation
     attr_reader :userLocationInfo, :userWeatherInfo 

     def initialize
          @locationURL = "https://freegeoip.app/json/"
          @weatherURL = "https://api.met.no/weatherapi/locationforecast/1.9/.json?lat=%{lat}&lon=%{lon}" 
          fetchUserLocation
     end

     def fetchUserLocation
          # base_url =  URI(@locationURL)
          # response = Net::HTTP.get(base_url)
          # @userLocationInfo = JSON.parse(response)
     end

     def fetchUserWeather
          # url = @weatherURL % {
          #      lat: @userLocationInfo["latitude"],
          #      lon: @userLocationInfo["longitude"]
          # }
          # uri = URI(url)
          # response = Net::HTTP.get(uri)
          # @userWeatherInfo = JSON.parse(response)
     end

end

def main
     newWeatherInstance = WeatherInformation.new()
     newWeatherInstance.fetchUserWeather
     puts newWeatherInstance.userWeatherInfo

end

main
