# Malika Liyanage 101231500
require 'net/http'
require 'json'
require 'date'

module JSONFileOperations

     def clearFile(filename)
          # Removes any existing content in the file
          file = File.open(filename, "w") do |f|
               f.truncate(0)
          end
          file.close
     end
     
     def updateFile(filename, data)
          # If the file already exists, its existing contents
          # are cleared
          if (File.exists?(filename))
               clearFile(filename)
          end

          file = File.open(filename,"a") do |f|
               f.write(data.to_json)
          end
          file.close
     end

     def readFromFile(filename)
     end

end

class WeatherInformation
     include JSONFileOperations
     WEATHER_API_URL = "https://api.met.no/weatherapi/locationforecast/1.9/.json?lat=%{lat}&lon=%{lon}" 
     WEATHER_JSON_FILE_NAME = "forecast.json"
     LOCATION_API_URL = "https://freegeoip.app/json/"
     LOCATION_JSON_FILE_NAME = "location.json"
     
     attr_reader :userLocationInfo, :userWeatherInfo

     def initialize
          getUserLocation
     end

     def getUserLocation
          apiUri =  URI(LOCATION_API_URL)
          response = Net::HTTP.get(apiUri)
          @userLocationInfo = JSON.parse(response)
          updateFile(WEATHER_JSON_FILE_NAME, @userLocationInfo)
     end

     def getUserWeather
          url = WEATHER_API_URL % {
               lat: @userLocationInfo["latitude"],
               lon: @userLocationInfo["longitude"]
          }
          apiUri = URI(url)
          response = Net::HTTP.get(apiUri)
          @userWeatherInfo = JSON.parse(response)
          updateFile(LOCATION_JSON_FILE_NAME, @userWeatherInfo)
     end

end

def main
     # currentWeatherInfo = WeatherInformation.new
     # currentWeatherInfo.getUserWeather
     #
     # test = DateTime.iso8601("2020-05-03T22:30:38+08:00")
     # test2 = DateTime.now.iso8601(3)
     # test3 = DateTime.iso8601(test2)
     # puts test
     # puts test3
     # puts ((test-test3)*24*60*60).to_i

     # if (test < test3)
     #      puts "nice"
     # else
     #      puts "uh-oh"
     # end
end

main
