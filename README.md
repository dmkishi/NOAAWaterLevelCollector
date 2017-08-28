# NOAAWaterLevelCollector

Download 6-minute interval water level data across multiple stations via the [NOAA CO-OPS API](https://tidesandcurrents.noaa.gov/api/) into separate station-by-station CSV files.

Retrieval of NOAA data products of 6-minute intervals are limited to a range of 31 days. This script allows retrievals of arbitrary date ranges by automatically making multiple requests across multiple stations and collecting them into single station-by-station CSV files.

Optionally, the "Date Time" field can be converted to an ISO 8601 format, "2001-12-31T23:55:00" (without time offsets or the "Z" designator for the zero UTC offset are given even if GMT is selected as a time zone), and a "Unix Time" column can be appended. Otherwise, the CSV output are exactly as provided by the NOAA API.

## Usage
`ruby noaa_water_level_collector.rb`
