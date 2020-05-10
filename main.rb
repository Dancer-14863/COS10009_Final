# Malika Liyanage 101231500
require 'net/http'
require 'json'
require 'date'

module JSONFileOperations
  ##
  # Clears the contents of a file
  #
  # @param [String] filename Name of the file to be cleared
  #
  def clearFile(filename)
    # Removes any existing content in the file
    File.open(filename, "w").truncate(0)
  end

  ##
  # Appends data to a file. If the file already
  # exists in the system, its contents are cleared using the 
  # clearFile method
  #
  # @param [String] filename Name of the file
  # @param [Any]    data     Data to be written
  #
  def updateFile(filename, data)
    # If the file already exists, its existing contents
    # are cleared
    if (File.exists?(filename))
      clearFile(filename)
    end

    File.open(filename,"a").write(data.to_json)
  end

  ##
  # Reads data from file.As this method will be mainly
  # used for reading from json file, only the first line needs
  # to be read
  #
  # @param [String]  filename Name of the file
  # @return [String] data in the file
  def readFromFile(filename)
    data = File.open(filename, "r").read
    return data
  end

end

##
# TODO: - Add catch statements if the api call fails
#
class WeatherInformation
  include JSONFileOperations
  WEATHER_API_URL = "https://api.met.no/weatherapi/locationforecast/1.9/.json?lat=%{lat}&lon=%{lon}" 
  WEATHER_JSON_FILE_NAME = "forecast.json"
  LOCATION_API_URL = "https://freegeoip.app/json/"
  LOCATION_JSON_FILE_NAME = "location.json"
  LOCATION_INFORMATION_EXPIRY_TIME_LIMIT = 300

  attr_reader :userLocationInfo, :userWeatherInfo

  def initialize
    getUserLocation
  end

  def checkLocationFile
    if (File.exists?(LOCATION_JSON_FILE_NAME))
      fileData = readFromFile(LOCATION_JSON_FILE_NAME)
      @userLocationInfo = JSON.parse(fileData)
    end
  end

  def reupdateUserLocation?
    mustUpdate = true

    unless (@userLocationInfo.nil?)
      dateTimeNow = DateTime.iso8601(DateTime.now.to_s)
      fetchDateTime = DateTime.iso8601(@userLocationInfo["fetch_date_time"])
      timeDifferenceSeconds = ((dateTimeNow - fetchDateTime) * 24 * 60 * 60).to_i
      mustUpdate = timeDifferenceSeconds > LOCATION_INFORMATION_EXPIRY_TIME_LIMIT
    end

    return mustUpdate
  end

  def getUserLocation
    checkLocationFile

    if (reupdateUserLocation?)
      apiUri =  URI(LOCATION_API_URL)
      response = Net::HTTP.get(apiUri)

      fetchTimeInfo = {:fetch_date_time => DateTime.now.iso8601(3)}
      @userLocationInfo = JSON.parse(response)
      @userLocationInfo.merge!(fetchTimeInfo)
      updateFile(LOCATION_JSON_FILE_NAME, @userLocationInfo)
    end
  end

  def getUserWeather
    if (reupdateUserLocation?)
      getUserLocation
    end

    url = WEATHER_API_URL % {
      lat: @userLocationInfo["latitude"],
      lon: @userLocationInfo["longitude"]
    }
    apiUri = URI(url)
    response = Net::HTTP.get(apiUri)

    @userWeatherInfo = JSON.parse(response)
    updateFile(WEATHER_JSON_FILE_NAME, @userWeatherInfo)
  end

  ##
  # Removes unwanted information from weather data object
  # The weather api returns location weather forecasts in
  # one hour, three hour and six hour intervals. Only the information 
  # in one hour intervals is needed, the rest are removed by this method
  #
  def filterWeatherData(weatherData)
  end

end

def main
  currentWeatherInfo = WeatherInformation.new
  puts currentWeatherInfo.userLocationInfo
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
