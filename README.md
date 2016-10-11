# get-water-level-data.rb

Simple, single-file script grabs and collects water level data via the [NOAA
CO-OPS API](http://tidesandcurrents.noaa.gov/api/) into separate
station-by-station CSV files.

By default, this will add a "Unix Time" column, translated from the "Date Time"
column.

Settings must be edited in-file under the **Configs** section:

```ruby
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
```
