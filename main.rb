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
  LOCATION_INFORMATION_EXPIRY_TIME_LIMIT = 600

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

      fetchDateTimeInfo = {"fetch_date_time" => DateTime.now.iso8601(3).to_s}
      @userLocationInfo = JSON.parse(response)
      @userLocationInfo.merge!(fetchDateTimeInfo)
      updateFile(LOCATION_JSON_FILE_NAME, @userLocationInfo)
    end
  end

  def checkWeatherFile
    if (File.exists?(WEATHER_JSON_FILE_NAME))
      fileData = readFromFile(WEATHER_JSON_FILE_NAME)
      @userWeatherInfo = JSON.parse(fileData)
    end
  end

  def reupdateUserWeather?
    mustUpdate = true

    unless (@userWeatherInfo.nil?)
      dateTimeNow = DateTime.iso8601(DateTime.now.to_s)
      weatherNextUpdate = DateTime.iso8601(@userWeatherInfo["meta"]["model"]["nextrun"])
      mustUpdate = dateTimeNow > weatherNextUpdate
    end

    return mustUpdate
  end

  def getUserWeather
    checkWeatherFile

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
    filterWeatherData
    fetchDateTimeInfo = {"fetch_date_time" => DateTime.now.iso8601(3).to_s}
    @userWeatherInfo.merge!(fetchDateTimeInfo)
    updateFile(WEATHER_JSON_FILE_NAME, @userWeatherInfo)
  end

  ##
  # Removes unwanted information from weather data object
  # The weather api returns location weather forecasts in
  # one hour, three hour and six hour intervals. Only the information 
  # in one hour intervals is needed, the rest are removed by this method
  #
  def filterWeatherData
    @userWeatherInfo["product"]["time"] = 
      @userWeatherInfo["product"]["time"].select{ |data| data["to"] == data["from"] }
  end

end

def main
  currentWeatherInfo = WeatherInformation.new
  currentWeatherInfo.getUserWeather
end

main
