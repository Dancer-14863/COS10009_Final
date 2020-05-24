# Malika Liyanage 101231500
require 'json'
require 'date'
require 'gosu'
require 'net/http'
require "open-uri"

# Contains common file operations
# used for this project
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
  API_KEY = "2c4294e1b221ea4d08cde0eeba687d31"
  WEATHER_API_URL = "https://api.openweathermap.org/data/2.5/weather?lat=%{lat}&lon=%{lon}&appid=%{apiKey}"
  WEATHER_JSON_FILE_NAME = "forecast.json"
  LOCATION_API_URL = "https://freegeoip.app/json/"
  LOCATION_JSON_FILE_NAME = "location.json"
  LOCATION_INFORMATION_EXPIRY_TIME_LIMIT = 600
  WEATHER_INFORMATION_EXPIRY_TIME_LIMIT = 3600
  WEATHER_ICON_URL = "http://openweathermap.org/img/wn/%{symbolId}@2x.png"
  WEATHER_ICON_NAME = "weather_symbol.png"

  attr_reader :userLocationInfo

  def initialize
    getUserLocation
  end

  ##
  # Checks if the location save file
  # exists and if it does loads its contents
  # to @userLocationInfo
  def checkLocationFile
    if (File.exists?(LOCATION_JSON_FILE_NAME))
      fileData = readFromFile(LOCATION_JSON_FILE_NAME)
      @userLocationInfo = JSON.parse(fileData)
    end
  end

  ##
  # Checks if the user location information should be updated
  # This is done if
  #   (1) The user location information is nil
  #   (2) The location information has expired
  #
  # @returns [Boolean] Returns true if location info should be updated else
  #                    false
  def reupdateUserLocation?
    mustUpdate = true

    unless (@userLocationInfo.nil?)
      dateTimeNow = DateTime.iso8601(DateTime.now.to_s)
      # This is the datetime when the location information was last fetched
      fetchDateTime = DateTime.iso8601(@userLocationInfo["fetch_date_time"])

      # Gets the difference between the two datetimes in seconds
      timeDifferenceSeconds = ((dateTimeNow - fetchDateTime) * 24 * 60 * 60).to_i

      mustUpdate = timeDifferenceSeconds > LOCATION_INFORMATION_EXPIRY_TIME_LIMIT
    end

    return mustUpdate
  end

  ##
  # Fetches the user location from the api
  def getUserLocation
    checkLocationFile

    if (reupdateUserLocation?)
      # API call
      apiUri =  URI(LOCATION_API_URL)
      response = Net::HTTP.get(apiUri)

      # Gets the current datetime and merges it with response 
      fetchDateTimeInfo = {"fetch_date_time" => DateTime.now.iso8601(3).to_s}
      @userLocationInfo = JSON.parse(response)
      @userLocationInfo.merge!(fetchDateTimeInfo)

      # Saves the response in file
      updateFile(LOCATION_JSON_FILE_NAME, @userLocationInfo)
    end
  end

  ##
  # Checks if the weather save file
  # exists and if it does loads its contents
  # to @userWeatherInfo
  def checkWeatherFile
    if (File.exists?(WEATHER_JSON_FILE_NAME))
      fileData = readFromFile(WEATHER_JSON_FILE_NAME)
      @userWeatherInfo = JSON.parse(fileData)
    end
  end

  ##
  # Checks if the user weather information should be updated
  # This is done if
  #   (1) The user weather information is nil
  #   (2) The weather information has expired
  #
  # @returns [Boolean] Returns true if weather info should be updated else
  #                    false
  def reupdateUserWeather?
    mustUpdate = true

    unless (@userWeatherInfo.nil?)
      dateTimeNow = DateTime.iso8601(DateTime.now.to_s)
      # DateTime at which weather information was fetched
      fetchDateTime = DateTime.iso8601(@userWeatherInfo["fetch_date_time"])

      # Strips the minutes and seconds off the datetimes. This is done
      # as the hours are needed for comparison
      correctedDateTimeNow = DateTime.parse(dateTimeNow.strftime("%Y-%m-%dT%H:00:00%z"))
      correctedFetchDateTime = DateTime.parse(fetchDateTime.strftime("%Y-%m-%dT%H:00:00%z"))

      # Time difference between them in seconds
      timeDifferenceSeconds = ((correctedDateTimeNow - correctedFetchDateTime) * 24 * 60 * 60).to_i

      mustUpdate = timeDifferenceSeconds >= WEATHER_INFORMATION_EXPIRY_TIME_LIMIT
    end
    return mustUpdate
  end

  ##
  # Fetches the user weather from the api
  def getUserWeather
    checkWeatherFile

    if (reupdateUserWeather?)
      # Filling the values in the 
      # string template
      url = WEATHER_API_URL % {
        lat: @userLocationInfo["latitude"],
        lon: @userLocationInfo["longitude"],
        apiKey: API_KEY
      }
      # API call
      apiUri = URI(url)
      response = Net::HTTP.get(apiUri)

      # Gets the current datetime and merges it with response 
      @userWeatherInfo = JSON.parse(response)
      fetchDateTimeInfo = {"fetch_date_time" => DateTime.now.iso8601(3).to_s}
      @userWeatherInfo.merge!(fetchDateTimeInfo)

      # Saves response in file
      updateFile(WEATHER_JSON_FILE_NAME, @userWeatherInfo)

      # Downloads the neccessary weather icon
      downloadWeatherIcon
    end

    return @userWeatherInfo
  end

  ##
  # Downloads related weather icon from the
  # API
  def downloadWeatherIcon
    unless (@userWeatherInfo.nil?)
      # This is a id attached to the response from the api
      # The id corresponds to an image name in the api
      symbolId = @userWeatherInfo["weather"][0]["icon"]
      iconURL = WEATHER_ICON_URL % {
        symbolId: symbolId
      }

      # Downloads image and writes it to a file
      open(iconURL) do |image|
        File.open(WEATHER_ICON_NAME, "wb") do |file|
          file.write(image.read)
        end
      end
    end
  end

end

module ZOrder
  BACKGROUND, MIDDLE, TOP = *0..2
end

# TODO - Refactor color sheme toggle
# TODO - Refactor coordinate
class ForecastApp < Gosu::Window
  WIN_WIDTH = 640
  WIN_HEIGHT = 480
  BUTTON_WIDTH = 100
  BUTTON_HEIGHT = 50

  def initialize
    super(WIN_WIDTH, WIN_HEIGHT, false)
    self.caption = "Weather Forecast"

    @colorShemes = Hash[
      "dark" => [
        [46, 40, 42],
        [230, 230, 230]
      ],
      "light" => [
        [230, 230, 230],
        [46, 40, 42]
      ]
    ]
    @currentScheme = "dark"
    @background = Gosu::Color.rgb(
      @colorShemes[@currentScheme][0][0],
      @colorShemes[@currentScheme][0][1],
      @colorShemes[@currentScheme][0][2]
    )
    @uiFont = Gosu::Font.new(18)
    @primaryFontColor = Gosu::Color.rgb(
      @colorShemes[@currentScheme][1][0],
      @colorShemes[@currentScheme][1][1],
      @colorShemes[@currentScheme][1][2]
    )
    @buttonColor = Gosu::Color.rgb(255, 107, 107)

    # Used for different font levels
    @infoFontLevelOne = Gosu::Font.new(29)
    @infoFontLevelTwo = Gosu::Font.new(23)

    @currentWeatherInfo = WeatherInformation.new
    @weatherForecast = @currentWeatherInfo.getUserWeather
    @userLocation = currentLocationString
    @userWeatherMessage = currentWeatherMessage 
    @weatherIcon = Gosu::Image.new("weather_symbol.png")

    @buttonCoord = [
      WIN_WIDTH - BUTTON_WIDTH - 10,
      10
    ]

    updateUserDateTime
  end

  def update
    Gosu.button_down? Gosu::KB_ESCAPE 
    Gosu.button_down? Gosu::MsLeft 
    updateUserDateTime

    # Checks if the weather information should be updated
    if (@currentWeatherInfo.reupdateUserWeather?)
      puts "Updating Weather Information"
      @weatherForecast = @currentWeatherInfo.getUserWeather
      @userWeatherMessage = currentWeatherMessage 
    end
  end

  def draw
    # Drawing Background
    Gosu.draw_rect(0, 0, WIN_WIDTH, WIN_HEIGHT, @background, ZOrder::BACKGROUND, mode=:default)
    # User Local Date
    @uiFont.draw_text("Date: #{@userDate}",10, 10, ZOrder::MIDDLE, 1.0, 1.0, @primaryFontColor)
    Gosu.draw_rect(
      @buttonCoord[0],
      @buttonCoord[1],
      BUTTON_WIDTH, 
      BUTTON_HEIGHT, 
      @buttonColor, 
      ZOrder::MIDDLE, 
      mode=:default
    )
    @uiFont.draw_text_rel(
      "Toggle",
      (WIN_WIDTH- BUTTON_WIDTH - 10) + BUTTON_WIDTH/ 2,
      (BUTTON_HEIGHT) /2 + 10, 
      ZOrder::TOP, 
      0.5,
      0.5,
      1.0, 
      1.0, 
      @primaryFontColor
    )
    @infoFontLevelTwo.draw_text_rel(
      "#{@userDay}, #{@userTime}", 
      WIN_WIDTH / 2, 
      WIN_HEIGHT / 2 - 110, 
      ZOrder::MIDDLE, 
      0.5, 
      0.5, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws Users Current Location Address
    @infoFontLevelOne.draw_text_rel(
      "#{@userLocation}", 
      WIN_WIDTH / 2, 
      WIN_HEIGHT / 2 - 80, 
      ZOrder::MIDDLE, 
      0.5, 
      0.5, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws the weather icon
    @weatherIcon.draw_rot(
      WIN_WIDTH / 2,
      WIN_HEIGHT / 2,
      ZOrder::MIDDLE,
      0,
      0.5,
      0.5,
      2,
      2
    )
    # Draws Current Forecast's Temperature
    @infoFontLevelOne.draw_text_rel(
      "#{convertToCelcius(@weatherForecast["main"]["temp"])}°C", 
      WIN_WIDTH / 2, 
      WIN_HEIGHT / 2 + 70, 
      ZOrder::MIDDLE, 
      0.5, 
      0.5, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws the weather message
    @infoFontLevelTwo.draw_text_rel(
      "#{@userWeatherMessage}", 
      WIN_WIDTH / 2, 
      WIN_HEIGHT / 2 + 100, 
      ZOrder::MIDDLE, 
      0.5, 
      0.5, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws forecast humidity
    @uiFont.draw_text(
      "Humidity: #{@weatherForecast["main"]["humidity"]}%", 
      10, 
      WIN_HEIGHT - 30, 
      ZOrder::MIDDLE, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws forecast wind speed
    @uiFont.draw_text_rel(
      "Wind: #{@weatherForecast["wind"]["speed"]}m/s", 
      WIN_WIDTH / 2, 
      WIN_HEIGHT - 30, 
      ZOrder::MIDDLE, 
      0.5, 
      0.0, 
      1.0, 
      1.0, 
      @primaryFontColor
    )
    # Draws forecast pressure
    @uiFont.draw_text_rel(
      "Pressure: #{@weatherForecast["main"]["pressure"]}hPa", 
      WIN_WIDTH - 10, 
      WIN_HEIGHT - 30, 
      ZOrder::MIDDLE, 
      1.0,
      0.0,
      1.0, 
      1.0, 
      @primaryFontColor
    )
  end

  ##
  # Adds cursor to window
  def needs_cursor?
    true
  end

  ##
  def updateUserDateTime
    today = DateTime.now
    @userTime = today.strftime("%H:%M:%S")
    @userDate = today.strftime("%F")
    @userDay = today.strftime("%A")
  end
  
  ##
  # Returns the description in the api response
  # capitalizes it as well
  #
  # @return [String] Capitalized version of the description
  def currentWeatherMessage
    return @weatherForecast["weather"][0]["description"].split.map(&:capitalize)*' '
  end
  
  ##
  # Returns a string containing the users location
  # Its in the format
  #   City Region, Country
  # 
  # @return [String] User's current location
  def currentLocationString
    locationInfo = @currentWeatherInfo.userLocationInfo
    return "#{locationInfo["city"]} #{locationInfo["region_name"]}, #{locationInfo["country_name"]}"
  end

  ## 
  # Converts Kelvin temperature to Celcius
  #
  # @return [Float] Temperature in Celcius rouned to 1dp
  def convertToCelcius(temperature)
    return (temperature - 273.15).round(1)
  end

  def button_down(id)
    case id
    when Gosu::KB_ESCAPE
      close
    when Gosu::MsLeft
      if (mouse_over_button?(mouse_x, mouse_y))
        toggleTheme
      end
    else
      super
    end
  end

  def mouse_over_button?(mouse_x, mouse_y)
    if (mouse_x > @buttonCoord[0] && mouse_x < @buttonCoord[0] + BUTTON_WIDTH) && 
        (mouse_y > @buttonCoord[1] && mouse_y < @buttonCoord[1] + BUTTON_HEIGHT)
      true
    else
      false
    end
  end

  def toggleTheme
    @currentScheme == "dark" ? @currentScheme = "light" : @currentScheme = "dark"
    @background = Gosu::Color.rgb(
      @colorShemes[@currentScheme][0][0],
      @colorShemes[@currentScheme][0][1],
      @colorShemes[@currentScheme][0][2]
    )
    @uiFont = Gosu::Font.new(18)
    @primaryFontColor = Gosu::Color.rgb(
      @colorShemes[@currentScheme][1][0],
      @colorShemes[@currentScheme][1][1],
      @colorShemes[@currentScheme][1][2]
    )
  end

end

window = ForecastApp.new
window.show
