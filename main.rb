# Malika Liyanage 101231500
require 'net/http'
require 'json'
require 'date'
require 'gosu'
require "open-uri"

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
# TODO: - Add private and public methods
# TODO: - Make sure weather updates if location updates
#
class WeatherInformation
  include JSONFileOperations
  WEATHER_API_URL = "https://api.met.no/weatherapi/locationforecast/1.9/.json?lat=%{lat}&lon=%{lon}" 
  WEATHER_JSON_FILE_NAME = "forecast.json"
  LOCATION_API_URL = "https://freegeoip.app/json/"
  LOCATION_JSON_FILE_NAME = "location.json"
  LOCATION_INFORMATION_EXPIRY_TIME_LIMIT = 600
  WEATHER_ICON_URL = "https://api.met.no/weatherapi/weathericon/1.1/?symbol=%{symbol_id}&is_night=%{is_night}&content_type=image/png"
  WEATHER_ICON_NAME = "weather_symbol.png"

  attr_reader :userLocationInfo

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
      weatherNextUpdate = DateTime.iso8601(@userWeatherInfo["product"]["time"][0]["to"])
      # Adds five minutes to the update time
      # enabling the request server to be updated properly
      weatherNextUpdate += Rational(5 * 60, 86400)
      mustUpdate = dateTimeNow >= weatherNextUpdate
    end
    return mustUpdate
  end

  def getUserWeather
    checkWeatherFile

    if (reupdateUserWeather?)
      url = WEATHER_API_URL % {
        lat: @userLocationInfo["latitude"],
        lon: @userLocationInfo["longitude"]
      }
      apiUri = URI(url)
      response = Net::HTTP.get(apiUri)

      @userWeatherInfo = JSON.parse(response)
      @userWeatherInfo["product"]["time"] = @userWeatherInfo["product"]["time"].shift(2)
      fetchDateTimeInfo = {"fetch_date_time" => DateTime.now.iso8601(3).to_s}
      @userWeatherInfo.merge!(fetchDateTimeInfo)
      updateFile(WEATHER_JSON_FILE_NAME, @userWeatherInfo)
      downloadWeatherIcon
    end

    forecastArray = @userWeatherInfo["product"]["time"]
    return forecastArray
  end

  def downloadWeatherIcon
    unless (@userWeatherInfo.nil?)
      symbolId = @userWeatherInfo["product"]["time"][1]["location"]["symbol"]["number"]
      iconURL = WEATHER_ICON_URL % {
        symbol_id: symbolId,
        is_night: isNight ? "1" : "0"
      }
      open(iconURL) do |image|
        File.open(WEATHER_ICON_NAME, "wb") do |file|
          file.write(image.read)
        end
      end
    end
  end

  def isNight
    currentHour = Time.now.hour
    return currentHour > 20 || currentHour < 6
  end

end

module ZOrder
  BACKGROUND, MIDDLE, TOP = *0..2
end

class ForecastApp < Gosu::Window
  WIN_WIDTH = 640
  WIN_HEIGHT = 480

  def initialize
    super(WIN_WIDTH, WIN_HEIGHT, false)
    self.caption = "Weather Forecast"
    @background = Gosu::Color::WHITE
    @uiFont = Gosu::Font.new(18)
    @primaryFontColor = Gosu::Color.argb(0xff_000000)
    @infoFontLevelOne = Gosu::Font.new(29)
    @infoFontLevelTwo = Gosu::Font.new(23)

    @currentWeatherInfo = WeatherInformation.new
    @weatherForecast = @currentWeatherInfo.getUserWeather
    @userLocation = currentLocationString
    @currentForecastIndex = 0
    @weatherIcon = Gosu::Image.new("weather_symbol.png")
    updateUserTime

  end

  def update
    updateUserTime
    if (@currentWeatherInfo.reupdateUserWeather?)
      @weatherForecast = @currentWeatherInfo.getUserWeather
    end
  end

  def draw
    # Drawing Background
    Gosu.draw_rect(0, 0, WIN_WIDTH, WIN_HEIGHT, @background, ZOrder::BACKGROUND, mode=:default)
    # Users Local Time
    @uiFont.draw_text("Time: #{@userTime}",10, 10, ZOrder::MIDDLE, 1.0, 1.0, @primaryFontColor)
    # Draws Current Forecast's Temperature
    @infoFontLevelOne.draw_text_rel(
      "#{@weatherForecast[@currentForecastIndex]["location"]["temperature"]["value"]}°C", 
      WIN_WIDTH / 2, 
      WIN_HEIGHT / 2, 
      ZOrder::MIDDLE, 
      0.5, 
      0.5, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws Users Current Location Address
    @infoFontLevelTwo.draw_text_rel(
      "#{@userLocation}", 
      WIN_WIDTH / 2, 
      WIN_HEIGHT / 2 + 30, 
      ZOrder::MIDDLE, 
      0.5, 
      0.5, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    @weatherIcon.draw_rot(
      WIN_WIDTH / 2,
      WIN_HEIGHT / 2 - 40,
      ZOrder::MIDDLE,
      0,
      0.5,
      0.5,
      2,
      2
    )
  end

  def updateUserTime
    @userTime = DateTime.now.strftime("%H:%M:%S")
  end
  
  def currentLocationString
    locationInfo = @currentWeatherInfo.userLocationInfo
    return "#{locationInfo["city"]} #{locationInfo["region_name"]}, #{locationInfo["country_name"]}"
  end

end

window = ForecastApp.new
window.show
