# This script creates the number of flights arriving and departing from an airport within hourly blocks

library(plyr)
library(RSQLite)
sqlite <- dbDriver("SQLite")
ontimeDb <- dbConnect(sqlite, "../data/ontime.sqlite3")
dat <- dbGetQuery(ontimeDb, "select * from ontime")

dat$departure_dt <- with(dat, ISOdatetime(Year, Month, DayofMonth, floor(CRSDepTime / 100), CRSDepTime %% 100, 0))
# ISOdatetime can be added to a number of seconds - estelapsedtime is in minutes
dat$arrival_dt <- dat$CRSElapsedTime * 60 + dat$departure_dt
dat$dep_hour_group <- strftime(dat$departure_dt, format="%Y-%m-%d %H")
dat$arr_hour_group <- strftime(dat$arrival_dt, format="%Y-%m-%d %H")

hourly_departures <- ddply(dat, .(Origin, dep_hour_group), summarize, num_departures=length(Origin))
hourly_departures <- rename(hourly_departures, c("Origin"="airport", "dep_hour_group"="hour"))

hourly_arrivals <- ddply(dat, .(Dest, arr_hour_group), summarize, num_arrivals=length(Dest))
hourly_arrivals <- rename(hourly_arrivals, c("Dest"="airport", "arr_hour_group"="hour"))

airport_volume <- merge(hourly_departures, hourly_arrivals, all=TRUE)
airport_volume$num_departures <- ifelse(is.na(airport_volume$num_departures), 0, airport_volume$num_departures)
airport_volume$num_arrivals <- ifelse(is.na(airport_volume$num_arrivals), 0, airport_volume$num_arrivals)

write.csv(airport_volume, "../data/airport-volume.csv", quote=FALSE, row.names=FALSE)

