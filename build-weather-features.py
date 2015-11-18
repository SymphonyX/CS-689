import argparse
import calendar
from datetime import datetime
import os
import json
import csv
import sqlite3

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("weather_file", help="A JSON file containing weather data")
    parser.add_argument("--flight_file", default="../data/ontime.sqlite3", 
            help="A sqlite database containing flights to annotate with weather data")
    parser.add_argument("--airport-id-map", default="../data/airport-id-map.csv", 
            help="A CSV file containing a map from airport ID to three-letter code")
    parser.add_argument("--output_file", default="../data/airport-weather.csv",
            help="A CSV file to write weather information to.")
    args = parser.parse_args()

    # maps airline code to three-letter code
    airport_id_map = dict()
    with open(args.airport_id_map, "r") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            airport_id_map[row["Id"]] = row["Code"]

    # airport-centric weather data
    weather_data = dict()
    if os.path.exists(args.weather_file):
        with open(args.weather_file, "r") as handle:
            weather_data = json.load(handle)

    conn = sqlite3.connect(args.flight_file)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    with open(args.output_file, "w+") as handle:
        writer = csv.writer(handle)
        writer.writerow(["airport", "hour", "precipIntensity", "temperature", "dewPoint", 
                "visibility", "apparentTemperature", "pressure", "windSpeed", 
                "precipProbability", "humidity", "windBearing", "weatherSummary", "meanPrecipIntensityLast3Hours"])
        for flight in c.execute('select * from ontime'): 
            dep_time = get_departure_time(flight)
            weather_features = get_weather_features(flight, weather_data, airport_id_map)
            if weather_features:
                writer.writerow([flight["Origin"], dep_time.strftime("%Y-%m-%d %H")] + weather_features)
    
def get_departure_time(flight):
    return datetime(int(flight["Year"]), int(flight["Month"]), int(flight["DayofMonth"]), 
                           int(flight["CRSDepTime"]) / 100, int(flight["CRSDepTime"]) % 100)

def get_weather_features(flight, weather_data, airport_id_map):
    weather_records = weather_data.get(airport_id_map[flight["Origin"]]) 
    search_time = get_departure_time(flight)
    search_timestamp = calendar.timegm(search_time.utctimetuple())
    if not weather_records:
        return None
    matching_records = [w for w in weather_records if w["hourly_extent"][0] <= search_timestamp 
                            and w["hourly_extent"][1] >= search_timestamp]
    if matching_records:
        hourly_data = matching_records[0]["full_response"]["hourly"]["data"]
        for i in range(len(hourly_data)-1):
            if hourly_data[i+1]["time"] > search_timestamp:
                past_three_hours = hourly_data[max(i-3, 0):i]
                current = hourly_data[i]
                if past_three_hours:
                    mean_precip_intensity = sum([r["precipIntensity"] for r in past_three_hours]) / len(past_three_hours)
                else:
                    mean_precip_intensity = current["precipIntensity"]
                features = [current["precipIntensity"], current["temperature"], current["dewPoint"], 
                            current["visibility"], current["apparentTemperature"], current["pressure"], 
                            current["windSpeed"] if "windSpeed" in current else 0, 
                            current["precipProbability"], current["humidity"], 
                            current["windBearing"] if "windBearing" in current else 0, 
                            current["summary"], mean_precip_intensity]
                return features
    else:
        return None

if __name__ == "__main__":
    main()



