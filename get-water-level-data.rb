#!/usr/bin/env ruby

# Name:        get-water-level-data.rb
# Version:     v1.0.0
# Description: Simple, single-file script grabs and collects water level data
#              via the NOAA CO-OPS API into separate station-by-station CSV
#              files.
#
#              By default, this will add a "Unix Time" column, translated from
#              the "Date Time" column.
#
#              Settings must be edited in-file under the Configs section.
#
# Author:      dm.kishi@gmail.com
# Created:     2016-09-25
# Modified:    2016-10-10

require 'csv'
require 'date'
require 'net/http'



################################################################################
#                                   CONFIGS                                    #
################################################################################
# Add a "Unix Time" column, translated from the "Date Time" column.
ADD_UNIX_TIMESTAMP = true

# Date format in dashless ISO 8601, e.g. "20160131".
DATE_RANGE = { first: 20150701, last: 20160630 }

STATIONS = {
  alameda:      9414750,
  bolinas:      9414958,
  coyote_creek: 9414575,
  martinez:     9415102,
  point_reyes:  9415020,
  port_chicago: 9415144,
  redwood_city: 9414523,
  richmond:     9414863,
  sf:           9414290
}

# "MLLW" or "NAVD", uppercase
DATUM = 'MLLW'

# "gmt" or "lst", lowercase. LST or Local Standard Time is the local time at the
# station.
TIME_ZONE = 'lst'

# "english" or "metric", lowercase.
UNITS = 'english'



################################################################################
#                                     LIB                                      #
################################################################################
class String
  # Remove first line from string.
  # From <https://grosser.it/2011/01/05/ruby-remove-first-line-from-a-string/>
  def remove_first_line!
    first_newline = (index("\n") || size - 1) + 1
    slice!(0, first_newline).sub("\n",'')
  end
end


class Date
  # Return string formated like "1/31/2016"
  def pretty_date
    self.strftime('%-m/%-e/%Y')
  end


  # Return string in dashless ISO 8601 format, e.g. "20160131"
  def dashless_iso8601
    self.iso8601.gsub('-', '')
  end


  # 2001-01-31 returns 2001-01-31
  def first_day_of_month
    Date.new(self.year, self.month, 1)
  end


  # 2001-01-31 returns 2001-01-31
  def last_day_of_month
    Date.new(self.year, self.month, -1)
  end
end


# Return an array of hashes containing a pair of dates, a start date and an
# end date, for each month, from the `begin_date` to the `end_date`. The start
# date is the first day of the month except for the first set and the end date
# is the last day of the month except for the last set.
#
# The NOAA API's maximum retrieval period for data intervals of 6-minutes, the
# finest available, is 31 days, so we make requests for single month periods
# at a time, then aggregate them into a single data-set.
#
# Example output, where first_date = 20160102, last_date = 20160922:
#   [{:begin_date=>"20160102", :end_date=>"20160131"},
#    {:begin_date=>"20160201", :end_date=>"20160229"},
#     ...
#    {:begin_date=>"20160901", :end_date=>"20160922"}]
def get_month_list(first_date, last_date)
  abort 'Bad dates' unless last_date >= first_date

  first_date = Date.iso8601(first_date.to_s)
  last_date  = Date.iso8601(last_date.to_s)
  month_list = []
  this_date  = first_date

  while this_date.first_day_of_month <= last_date
    # Only on the first iteration, enter `first_date` as is, otherwise enter the
    # first day of the month.
    begin_date = month_list.empty? ?
                 first_date :
                 this_date.first_day_of_month

    # Only on the last iteration, enter `last_date` as is, otherwise enter the
    # last day of the month.
    end_date = (this_date.year == last_date.year &&
                this_date.month == last_date.month ) ?
               last_date :
               this_date.last_day_of_month

    month_list << { begin_date: begin_date, end_date: end_date }

    this_date = this_date.next_month
  end

  month_list
end


class NOAA_COOP_API
  @@uri = URI('https://tidesandcurrents.noaa.gov/api/datagetter')

  def initialize(station_id)
    @station_id = station_id
  end


  def get_data(begin_date, end_date)
    params = {
      product:    'water_level',
      format:     'csv',
      datum:      DATUM,
      time_zone:  TIME_ZONE,
      units:      UNITS,
      station:    @station_id,
      begin_date: begin_date.dashless_iso8601,
      end_date:   end_date.dashless_iso8601
    }

    @@uri.query = URI.encode_www_form(params)
    res = Net::HTTP.get_response(@@uri)

    if !res.is_a?(Net::HTTPSuccess)
      if res.code != '301' || res.code != '302'
        puts "HTTP ERROR: #{res.code} #{res.message}"
        exit
      end
      puts 'WARNING: There was an HTTP redirect while connecting to the NOAA ' +
           'CO-OPS API. The base URL may need to be updated.'
    elsif is_error_message(res.body)
      puts "ERROR: #{res.body}"
      exit
    end

    res.body
  end


  # Check if API response body is an error message or not.
  def is_error_message(data)
    # Error messages seems to be flanked by two linebreaks and as that is not
    # expected in CSVs, we'll simply search that.
    #
    # Example error message:
    #   "\n\n Wrong Datum: Datum cannot be null or empty \n\n"
    data.include? '\n\n'
  end
end



################################################################################
#                                     MAIN                                     #
################################################################################
MONTH_LIST = get_month_list(DATE_RANGE[:first], DATE_RANGE[:last])

STATIONS.each do |station_name, station_id|
  filename      = "#{station_name}--#{DATUM}--#{DATE_RANGE[:first]}-#{DATE_RANGE[:last]}.csv"
  nooa_coop_api = NOAA_COOP_API.new(station_id)

  # Create empty file (overwrite is fine)
  puts "Populating \"#{filename}\":"
  File.open(filename, 'w') {}

  MONTH_LIST.each_with_index do |month, i|
    puts "  - Getting #{month[:begin_date].pretty_date} → #{month[:end_date].pretty_date}"

    res = nooa_coop_api.get_data(month[:begin_date], month[:end_date])
    csv = CSV.parse(res, headers: true)

    if ADD_UNIX_TIMESTAMP
      csv.each do |row|
        row['Unix Time'] = DateTime.parse(row['Date Time']).to_time.to_i
      end
    end

    # Keep CSV header only on first iteration
    raw = csv.to_s
    raw.remove_first_line! unless i == 0

    # Append to file
    File.open(filename, 'a') { |f| f << raw }
  end
end
