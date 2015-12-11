library(stringr)
library(caret)
library(kernlab)
library(ggplot2)
library(plyr)

fulldat <- read.csv("../data/features2-shuf.csv", nrows=200000)
dat <- fulldat[1:1000, ]
carriers <- read.csv("../data/carriers.csv")

# are there statistically significant patterns in delays?
gpmodel <- gausspr(DepDelayMinutes ~ UniqueCarrier, data=dat, variance.model=TRUE)

carrier.dat <- dat[!duplicated(dat[, "UniqueCarrier", drop=FALSE]), ]
carrier.dat$estmean <- predict(gpmodel, carrier.dat)
carrier.dat$estsd <- predict(gpmodel, carrier.dat, type="sdeviation")

carrier.dat <- merge(carrier.dat, carriers, by.x="UniqueCarrier", by.y="Code")
carrier.dat$Description <- str_replace(carrier.dat$Description, "\\(Merged.+", "")
carrier.dat$CarrierName <- factor(carrier.dat$Description, levels=carrier.dat$Description[order(carrier.dat$estmean)])

g <- ggplot(carrier.dat, aes(x=CarrierName, y=estmean, 
                             ymin=estmean-estsd, ymax=estmean+estsd, color=CarrierName)) + 
  geom_errorbar(size=2) + guides(color="none") + 
  theme_bw(base_size=16) + theme(axis.text.x=element_text(angle=45))
print(g)

# does airport size affect flight delays? (doesn't look like it)
gpmodel <- gausspr(DepDelayMinutes ~ num_arrivals + num_departures, data=dat, variance.model=TRUE)

volume.dat <- dat[!duplicated(dat[, c("num_arrivals", "num_departures"), drop=FALSE]), ]
volume.dat$estmean <- predict(gpmodel, volume.dat)
volume.dat$estsd <- predict(gpmodel, volume.dat, type="sdeviation")
g <- ggplot(volume.dat, aes(x=num_arrivals, y=estmean, 
                            ymin=estmean-estsd, ymax=estmean+estsd)) + 
  geom_errorbar(size=2) + theme_bw(base_size=16) + theme(axis.text.x=element_text(angle=45))
print(g)
g <- ggplot(volume.dat, aes(x=num_departures, y=estmean, 
                            ymin=estmean-estsd, ymax=estmean+estsd)) + 
  geom_errorbar(size=2) + theme_bw(base_size=16) + theme(axis.text.x=element_text(angle=45))
print(g)

# does weather affect flight delays?
predictors <- c("Pressure"="pressure", "Apparent Temp." = "apparentTemperature", 
                "Temp" = "temperature", 
                "Dew Point" = "dewPoint", "Precip. Intensity" = "precipIntensity",
                "Wind Speed" = "windSpeed", 
                "Humidity" = "humidity", 
                "Wind Bearing" = "windBearing", 
                "Recent Precip. Intensity" = "meanPrecipIntensityLast3Hours")

# create a dataset of 'median' weather characteristics to 
# assess independent effects of specific features
median.weather <- data.frame(fulldat)
for(predictor in predictors) {
  median.weather[, predictor] <- median(median.weather[, predictor], na.rm=TRUE)
}
gam.formula <- as.formula(paste("DepDelayMinutes ~ ", paste(paste0("s(", predictors, ", bs=\"cs\")"), collapse="+")))
weather.model <- gam(gam.formula, data=fulldat)

for(i in 1:length(predictors)) {
  predictor <- predictors[i]
  pred.name  <- names(predictors)[i]
  # hold other features at their median value
  cur.dat <- median.weather 
  cur.dat[, predictor] <- fulldat[, predictor]
  
  # keep unique values of this predictor
  cur.dat <- cur.dat[!duplicated(cur.dat[, predictor, drop=FALSE]), ]
  preds <- predict(weather.model, cur.dat, se.fit=TRUE, type="response")
  
  cur.dat$predictions <- preds$fit
  cur.dat$predictionse <- preds$se.fit
  
  g <- ggplot(cur.dat, aes_string(x=predictor, y="predictions")) + 
    geom_line(color="blue") +
    geom_ribbon(aes(ymin=predictions+predictionse, ymax=predictions-predictionse), alpha=0.1) + 
    theme_bw(base_size=16) + 
    labs(x=pred.name, y=paste0("E[Minutes Dep. Delay|", pred.name, "]"))
  print(g)
  png(paste0("writeup/figures/", predictor, ".png"), width=600, height=300)
  print(g)
  dev.off()
}

# is there an interaction between wind bearing and airport?
# look at three top origins
origin.flights <- ddply(fulldat, .(Origin), summarize, num.flights=length(Origin))
top.origins <- origin.flights[order(-origin.flights$num.flights), ][1:30, "Origin"]
airports <- read.csv("../data/airport-id-map.csv")

for(i in 1:3) {
  cur.origin <- subset(fulldat, Origin == top.origins[i])
  origin.name <- airports[airports$Id == top.origins[i], "Code"]
  gam <- gam(DepDelayMinutes ~ s(windBearing, bs="cs"), data=cur.origin)
  preds <- predict(gam, se.fit=TRUE)
  cur.origin$prediction <- preds$fit
  cur.origin$predictionse <- preds$se.fit
  g <- ggplot(cur.origin, aes(x=windBearing, y=prediction)) + 
    geom_line(color="blue") +
    geom_ribbon(aes(ymin=prediction-predictionse, ymax=prediction+predictionse), alpha=0.1) +
    theme_bw(base_size=16) + 
    labs(x="Wind Bearing", y=paste0("E[Minutes Dep. Delay|Wind Bearing]"))
  print(g)
  png(paste0("writeup/figures/windBearing-", origin.name, ".png"), width=600, height=300)
  print(g)
  dev.off()    
}


# does origin affect flight delays? (doesn't look like it)
dat.top.origins <- subset(fulldat, Origin %in% top.origins)[1:1000, ]
origin.dat <- dat.top.origins[!duplicated(dat.top.origins[, "Origin", drop=FALSE]), ]
origin.dat$estmean <- predict(gpmodel, origin.dat)
origin.dat$estsd <- predict(gpmodel, origin.dat, type="sdeviation")
gpmodel <- gausspr(DepDelayMinutes ~ Origin, data=dat.top.origins, variance.model=TRUE)

g <- ggplot(origin.dat, aes(x=factor(Origin), y=estmean, ymin=estmean-estsd, ymax=estmean+estsd)) + 
  geom_errorbar(size=2) + theme_bw(base_size=16)
print(g)