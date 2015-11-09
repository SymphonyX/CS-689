import argparse
import requests_cache
import requests
import csv
import json
import os
from collections import defaultdict
from time import strptime
from datetime import datetime
import calendar

requests_cache.install_cache("weather_cache")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("flight_file", help="A CSV file containing flights to annotate with weather data")
    parser.add_argument("airports_file", help="A CSV file containing geographic information about airports")
    parser.add_argument("--weather-file", dest="weather_file", 
        default="weather.json", help="A JSON containing weather data")
    args = parser.parse_args()

    api_key = os.environ["FORECAST_API_KEY"]

    airports = dict()
    with open(args.airports_file, "r") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            airports[row["iata"]] = row

    # airport-centric weather data
    weather_data = dict()
    if os.path.exists(args.weather_file):
        with open(args.weather_file, "r") as handle:
            weather_data = json.load(handle)

    # organize flights by origin
    flights = defaultdict(list)
    with open(args.flight_file, "r") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            flights[row["Origin"]].append(row)

    # sort flights by departure time
    for origin in flights.keys():
        flights[origin] = sorted(flights[origin], key=lambda f: f["FlightDate"])

        num_flights = len(flights[origin])
        print("Processing {0} flights from origin {1}".format(num_flights, origin))
        for flight in flights[origin]:
            num_requests = get_weather(flight, weather_data, airports, api_key)
        print("\t{0}/{1} requests from cache".format(num_flights-num_requests, num_flights))

    # re-write weather data
    with open(args.weather_file, "w+") as handle:
        json.dump(weather_data, handle)
    

def get_weather(flight, weather_data, airports, api_key):
    # Request weather from the beginning of the day
    # returns 1 if a request was made, 0 if served from cache

    req_time = datetime(int(flight["Year"]), int(flight["Month"]), int(flight["DayofMonth"]), 0, 0)
    weather_records = weather_data.get(flight["Origin"]) 
    if weather_records:
        search_time = datetime(int(flight["Year"]), int(flight["Month"]), int(flight["DayofMonth"]), 
                               int(flight["CRSDepTime"]) / 100, int(flight["CRSDepTime"]) % 100)
        search_timestamp = calendar.timegm(search_time.utctimetuple())
        matching_records = [w for w in weather_records if w["hourly_extent"][0] <= search_timestamp 
                                and w["hourly_extent"][1] >= search_timestamp]
        if matching_records:
            return 0
    else:
        weather_data[flight["Origin"]] = []

    airport = airports[flight["Origin"]]
    req_url = "https://api.forecast.io/forecast/{0}/{1},{2},{3}".format(api_key, airport["lat"], airport["long"], req_time.isoformat())
    resp = requests.get(req_url)
    full_response = resp.json()
    hourly_records = full_response["hourly"]["data"]
    weather_data[flight["Origin"]].append({ "hourly_extent" : [hourly_records[0]["time"], hourly_records[-1]["time"]],
                                    "full_response" : full_response })
    return 1
     
         


if __name__ == "__main__":
    main()


