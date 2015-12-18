dat <- read.csv("../data/features2-shuf.csv", nrows=500000)
pair_id <<- 0
grouped.flights <- dlply(dat, .(Month, DayofMonth, Origin, Dest), function(df) { 
  if(nrow(df) == 2) { 
    pair_id <<- pair_id + 1
    df$pair_id <- pair_id
    return(df)
  }
})

# write pairs out in a random order
app <<- FALSE
a_ply(sample(length(grouped.flights)), 1, function(idx) {
  if(!is.null(grouped.flights[[idx]])) {
    write.table(grouped.flights[[idx]], file="../data/flight-pairs.csv", sep=",", row.names=FALSE, append=app, col.names=!app)
    app <<- TRUE
  }
})