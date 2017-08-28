# NOAAWaterLevelCollector

Download 6-minute interval water level data across multiple stations via the [NOAA CO-OPS API](https://tidesandcurrents.noaa.gov/api/) into separate station-by-station CSV files.

Retrieval of NOAA data products of 6-minute intervals are limited to a range of 31 days. This script allows retrievals of arbitrary date ranges by automatically making multiple requests across multiple stations and collecting them into single station-by-station CSV files.

Optionally, the "Date Time" field can be converted to a proper ISO 8601 format, e.g. "2001-12-31T23:55:00+00:00", and a "Unix Time" column can be appended. Otherwise, the CSV output can be exactly as provided by the NOAA.

## Usage
`ruby noaa_water_level_collector.rb`
