#!/usr/bin/env ruby
# coding: utf-8

# <bitbar.title>GeoIPWeather</bitbar.title>
# <bitbar.version>v0.1.1</bitbar.version>
# <bitbar.author>Taylor Zane</bitbar.author>
# <bitbar.author.github>taylorzane</bitbar.author.github>
# <bitbar.desc>Your weather in the menu bar 🌤</bitbar.desc>
# <bitbar.image>http://i.imgur.com/vrT6vfb.png</bitbar.image>
# <bitbar.dependencies>ruby</bitbar.dependencies>
# <bitbar.abouturl>https://github.com/taylorzane</bitbar.abouturl>

### USER VARIABLES
UNITS = 'C' # This can be: (F)ahrenheit, (C)elsius, (K)elvin
API_KEY = '8b4824b451d5db1612156837df880f55' # you can also get your own at http://openweathermap.org/

require 'json'
require 'net/http'

def no_data(message = nil)
  if message
    puts message
  else
    puts 'Cannot get weather.'
  end
  exit
end

def location
  location_uri = URI('http://ipinfo.io/json')

  begin
  	location_data = Net::HTTP.get location_uri
  rescue
  	no_data
  end

  location_json = JSON.parse location_data

  zip = nil
  country = nil
  lat = nil
  lng = nil

  if location_json['postal']
    zip = location_json['postal']
  else
    no_data
  end

  if location_json['country']
    country = location_json['country']
  else
    no_data
  end

  if location_json['loc']
    loc = location_json['loc'].split(',')
    lat = loc.first
    lng = loc.last
  else
    no_data
  end
  [zip, country, lat, lng]
end

def weather(zip_code, country, lat, lng)
  temperature_unit =
    case UNITS.upcase
    when 'F'
      '&units=imperial'
    when 'C'
      '&units=metric'
    else
      ''
    end

  temperature_symbol =
    case UNITS.upcase
    when 'F'
      '℉'
    when 'C'
      '℃'
    else
      'K'
    end

  weather_uri =
    URI('http://api.openweathermap.org/data/2.5/weather' \
        "?lat=#{lat}&lon=#{lng}" \
        "&appid=#{API_KEY}" \
        "#{temperature_unit}")

  weather_data = Net::HTTP.get(weather_uri)

  no_data unless weather_data

  weather_json = JSON.parse weather_data

  no_data weather_json['message'] if weather_json['cod'] == '404'

  temperature = weather_json['main']['temp'].round

  city = weather_json['name']
  country = weather_json['sys']['country']

  # puts "#{city}, #{country}: #{temperature}#{temperature_symbol}"
  puts "#{temperature}#{temperature_symbol} | size=13"
  puts "---"
  puts "#{city}, #{country}"
  puts "Show details | href=https://www.google.com/search?q=weather"
  puts "Stockholm details | href=https://www.yr.no/en/forecast/daily-table/2-2673730/Sweden/Stockholm/Stockholm%20Municipality/Stockholm"
  puts "Refresh | refresh=true"
end

weather(*location)
