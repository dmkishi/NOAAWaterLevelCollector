#!/usr/bin/env ruby

# Name:        noaa_water_level_collector.rb
# Version:     v1.1.0
# Description: Download 6-minute interval water level data across multiple
#              stations via the NOAA CO-OPS API into separate station-by-station
#              CSV files.
#
#              Retrieval of NOAA data products of 6-minute intervals are limited
#              to a range of 31 days. This script allows retrievals of arbitrary
#              date ranges by automatically making multiple requests across
#              multiple stations and collecting them into single station-by-
#              station CSV files.
#
#              Optionally, the "Date Time" field can be converted to an ISO 8601
#              format, "2001-12-31T23:55:00" (without time offsets or the "Z"
#              designator for the zero UTC offset are given even if GMT is
#              selected as a time zone), and a "Unix Time" column can be
#              appended. Otherwise, the CSV output are exactly as provided by
#              the NOAA API.
#
#              See the "CONFIGS" area below for detailed configuration notes.
#
#
#              USAGE
#              `ruby noaa_water_level_collector.rb`
#
#
#              RESOURCES
#                - NOAA CO-OPS API: <https://tidesandcurrents.noaa.gov/api/>
#
#
#              TECHNICAL NOTES
#              This is single-file Ruby script independent of external libraries
#              or Ruby gems.
#
#
# Author:      DM Kishi <dm.kishi@gmail.com>
# Website:     https://github.com/dmkishi/NOAAWaterLevelCollector
# Created:     2016-09-25
# Modified:    2017-08-28



################################################################################
#                                                                              #
#                                   CONFIGS                                    #
#                                                                              #
################################################################################
# Date ranges for collecting water levels, formatted like "2001-12-31"
START_DATE = '2015-07-01'
END_DATE   = '2015-07-01'


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


# Datum: choose one below
#
#   OPTION     DESCRIPTION
#   ————    ————————————————————————————————————
#   CRD     → Columbia River Datum
#   MHHW    → Mean Higher High Water
#   MHW     → Mean High Water
#   MTL     → Mean Tide Level
#   MSL     → Mean Sea Level
#   MLW     → Mean Low Water
#   MLLW    → Mean Lower Low Water
#   NAVD    → North American Vertical Datum
#   STND    → Station Datum
DATUM = 'MLLW'
# DATUM = 'NAVD'


# "feet" or "meter"
UNITS = 'feet'


# Time zone: choose any of three below
#
#   OPTION     DESCRIPTION
#   ————    ————————————————————————————————————
#   gmt     → Greenwich Mean Time
#   lst     → Local Standard Time. The time local to the requested station.
#   lst_ldt → Local Standard/Local Daylight Time. The time local to the
#              requested station.
TIME_ZONE = 'lst'


# Convert the "Date Time" column to an ISO 8601 format, from "2001-12-31 23:55"
# to "2001-12-31T23:55:00"?
#
# N.B. No time offsets or the "Z" designator for the zero UTC offset are given
#      even if GMT is selected as a time zone above.
CONVERT_TO_ISO8601 = true


# Append a UNIX timestamp column to the CSV?
ADD_UNIX_TIMESTAMP = true






################################################################################
#                                                                              #
#                              DO NOT EDIT BELOW!                              #
#                                                                              #
################################################################################
require 'csv'
require 'date'
require 'net/http'



################################################################################
#                                 EXTEND CORE                                  #
################################################################################
class String
  # Remove first line from string.
  # <https://grosser.it/2011/01/05/ruby-remove-first-line-from-a-string/>
  def remove_first_line!
    first_newline = (index("\n") || size - 1) + 1
    slice!(0, first_newline).sub("\n",'')
  end
end


class Date
  # Return string in dashless ISO 8601 format, e.g. "20011231"
  def dashless_iso8601
    self.iso8601.gsub('-', '')
  end


  # 2001-12-31 returns 2001-12-01
  def first_day_of_month
    Date.new(self.year, self.month, 1)
  end


  # 2001-12-01 returns 2001-12-31
  def last_day_of_month
    Date.new(self.year, self.month, -1)
  end
end



################################################################################
#                                NOAA_COOP_API                                 #
################################################################################
class NOAA_COOP_API
  BASE_URL         = 'https://tidesandcurrents.noaa.gov/api/datagetter'
  APPLICATION_NAME = 'NoaaWaterLevelCollector'

  def initialize(station_id:,
                 datum:              'MLLW',
                 units:              'feet',
                 time_zone:          'lst',
                 convert_to_iso8601: true,
                 add_unix_timestamp: false)
    @station_id         = station_id
    @datum              = datum
    @units              = units
    @time_zone          = time_zone
    @convert_to_iso8601 = convert_to_iso8601
    @add_unix_timestamp = add_unix_timestamp
  end


  def get_csv(begin_date, end_date)
    uri = URI(BASE_URL)
    uri.query = URI.encode_www_form(
                    product:     'water_level',
                    format:      'csv',
                    datum:       @datum,
                    time_zone:   @time_zone,
                    units:       @units,
                    station:     @station_id,
                    begin_date:  begin_date.dashless_iso8601,
                    end_date:    end_date.dashless_iso8601,
                    application: APPLICATION_NAME
                  )
    res = Net::HTTP.get_response(uri)

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

    csv = CSV.parse(res.body, headers: true)

    if @convert_to_iso8601 || @add_unix_timestamp
      csv.each do |row|
        date_time = DateTime.parse(row['Date Time'])
        row['Date Time'] = date_time.strftime('%FT%T') if @convert_to_iso8601
        row['Unix Time'] = date_time.to_time.to_i if @add_unix_timestamp
      end
    end

    csv
  end


  private


    # Check if API response body is an error message or not.
    def is_error_message(body)
      # Error messages appear to be flanked by two linebreaks and as that is not
      # expected in CSVs, we'll just search for that.
      #
      # Ex. "\n\n Wrong Datum: Datum cannot be null or empty \n\n"
      #
      # NOTE: Escape sequences such as linebreaks, i.e. "\n", must be wrapped in
      #       double-quotes.
      body.include? "\n\n"
    end
end



################################################################################
#                          NOAA WATER LEVEL COLLECTOR                          #
################################################################################
module NoaaWaterLevelCollector
  class << self
    def make_csv(start_date,
                 end_date,
                 stations,
                 datum,
                 units,
                 time_zone,
                 convert_to_iso8601,
                 add_unix_timestamp
                 )
      month_list = get_month_list(start_date, end_date)

      stations.each do |station_name, station_id|
        nooa_coop_api = NOAA_COOP_API.new(
                          station_id:         station_id,
                          datum:              datum,
                          time_zone:          time_zone,
                          units:              units,
                          convert_to_iso8601: convert_to_iso8601,
                          add_unix_timestamp: add_unix_timestamp
                        )

        # Create empty file (overwrite is fine)
        filename = "#{station_name}--#{datum}--#{start_date}-#{end_date}.csv"
        puts "Preparing \"#{filename}\"..."
        File.open(filename, 'w') {}

        month_list.each_with_index do |month, i|
          puts "  - Downloading #{month[:begin_date]} → #{month[:end_date]}"
          csv = nooa_coop_api.get_csv(month[:begin_date], month[:end_date])
          raw_csv = csv.to_s

          # Keep CSV header only on first iteration
          raw_csv.remove_first_line! unless i == 0

          # Append to file
          File.open(filename, 'a') { |f| f << raw_csv }
        end
      end
    end


    private


      # Return an array of hashes containing a pair of dates, a start date and
      # an end date, for each month, from the `begin_date` to the `end_date`.
      # The start date is the first day of the month except for the first set
      # and the end date is the last day of the month except for the last set.
      #
      # The NOAA API's maximum retrieval period for data intervals of 6-minutes,
      # the finest available, is 31 days, so we make requests for single month
      # periods at a time, then aggregate them into a single data-set.
      #
      # Example output, where first_date = 20160102, last_date = 20160922:
      #   [{:begin_date=>"20160102", :end_date=>"20160131"},
      #    {:begin_date=>"20160201", :end_date=>"20160229"},
      #     ...
      #    {:begin_date=>"20160901", :end_date=>"20160922"}]
      def get_month_list(first_date, last_date)
        month_list = []
        this_first_date = first_date

        while this_first_date.first_day_of_month <= last_date
          # Only on the first iteration, enter `first_date` as is, otherwise
          # enter the first day of the month.
          begin_date = month_list.empty? ?
                       first_date :
                       this_first_date.first_day_of_month

          # Only on the last iteration, enter `last_date` as is, otherwise enter
          # the last day of the month.
          end_date = (this_first_date.year == last_date.year &&
                      this_first_date.month == last_date.month ) ?
                      last_date :
                      this_first_date.last_day_of_month

          month_list << { begin_date: begin_date, end_date: end_date }

          this_first_date = this_first_date.next_month
        end

        month_list
      end
  end
end



################################################################################
#                                     MAIN                                     #
################################################################################
# TODO: CLI arguments for date ranges
# ARGV.each do |argv|
#   argv_array = argv.split('=')
#
#   case argv_array.first
#   when '--start-date'
#     argv_start_date = argv_array.last
#   when '--end-date'
#     argv_end_date = argv_array.last
#   end
# end


start_date = Date.iso8601(START_DATE.to_s)
end_date   = Date.iso8601(END_DATE.to_s)
unless end_date >= start_date
  abort 'BAD CONFIG: START_DATE must be before END_DATE'
end


# TODO: Validate stations


datum = DATUM.upcase
unless datum == 'MLLW' || datum == 'NAVD'
  abort 'BAD CONFIG: DATUM must be either "MLLW" or "NAVD"'
end


units =
  case UNITS.downcase
  when 'feet'  then 'english'
  when 'meter' then 'metric'
  else
    abort 'BAD CONFIG: UNITS must be either "feet" or "meter"'
  end


time_zone = TIME_ZONE.downcase
unless time_zone == 'gmt' || time_zone == 'lst' || time_zone == 'lst_ldt'
  abort 'BAD CONFIG: TIME_ZONE must be either "gmt" or "lst"'
end


convert_to_iso8601 =
  case CONVERT_TO_ISO8601
  when true, 'true'   then true
  when false, 'false' then false
  else
    abort 'BAD CONFIG: CONVERT_TO_ISO8601 must be either true or false'
  end


add_unix_timestamp =
  case ADD_UNIX_TIMESTAMP
  when true, 'true'   then true
  when false, 'false' then false
  else
    abort 'BAD CONFIG: ADD_UNIX_TIMESTAMP must be either true or false'
  end


NoaaWaterLevelCollector::make_csv(start_date,
                                  end_date,
                                  STATIONS,
                                  datum,
                                  units,
                                  time_zone,
                                  convert_to_iso8601,
                                  add_unix_timestamp
                                 )
