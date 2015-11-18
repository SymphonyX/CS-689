library(plyr)
library(RSQLite)
sqlite <- dbDriver("SQLite")
ontimeDb <- dbConnect(sqlite, "../data/ontime.sqlite3")
dat <- dbGetQuery(ontimeDb, "select * from ontime")

small.dat <- subset(dat, select=c("Year", "Month", "DayofMonth", "DayOfWeek", 
            "UniqueCarrier", "Origin", "Dest", "CRSDepTime", "CRSArrTime", "Distance", 
            "CRSElapsedTime", "DepDelay", "ArrDelay", "Cancelled"))

small.dat$DepDelay <- cut(small.dat$DepDelay, breaks=c(-Inf, 0, 10, 30, 60, Inf), include.lowest=TRUE)
small.dat$ArrDelay <- cut(small.dat$ArrDelay, breaks=c(-Inf, 0, 10, 30, 60, Inf), include.lowest=TRUE)
small.dat$DepartureHour <- with(small.dat, ISOdatetime(Year, Month, DayofMonth, floor(CRSDepTime / 100), CRSDepTime %% 100, 0))
small.dat$DepartureHour <- strftime(small.dat$DepartureHour, format="%Y-%m-%d %H")

airport_volume <- read.csv("../data/airport-volume.csv")
features <- merge(small.dat, airport_volume, by.x=c("Origin", "DepartureHour"), by.y=c("airport", "hour"), all.x=TRUE)

airport_weather <- read.csv("../data/airport-weather.csv")
features <- merge(features, airport_weather, by.x=c("Origin", "DepartureHour"), by.y=c("airport", "hour"), all.x=TRUE)

write.csv(features, "../data/features2.csv", quote=FALSE, row.names=FALSE)

