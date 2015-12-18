library(e1071)
library(plyr)
library(nnet)
library(rpart)
library(ranger)
library(caret)
library(kernlab)
library(tgp)
library(gbm)

# eliminate any constant features -- typically only necessary when using a subset of the full data
drop.const <- function(df) {
  keep.cols <- aaply(colnames(df), 1, function(c) length(unique(df[, c])) > 1)
  df <- df[, keep.cols]
  df <- df[complete.cases(df), ]
  return(df)
}

# eliminate any factor levels that appear only twice
drop.rare.vals <- function(df) {
  common.row <- t(aaply(colnames(df), 1, function(c) {
    if(!is.factor(df[, c])) {
      return(rep(TRUE, nrow(df)))
    } else {
      val.counts <- table(df[, c])
      common.vals <- names(val.counts[val.counts > 2])
      return(df[, c] %in% common.vals)
    }
  }))
  remove.rows <- rowSums(common.row) != ncol(df)
  return(df[!remove.rows, ])
}

# eliminate factors that have as many levels as rows
drop.high.dim <- function(df) {
  drop.factors <- aaply(colnames(df), 1, function(c) 
    is.factor(df[, c]) && length(levels(df[, c])) == nrow(df))
  df <- df[, !drop.factors]  
  return(df)
}

split.train.test <- function(df, check.col.domain=c("Origin", "Dest")) {#, "weatherSummary")) {
  pairs <- unique(df$pair_id)
  row.perm <- sample(length(pairs))
  train.pairs <- pairs[row.perm[1:(0.7 * length(row.perm))]]
  test.pairs <- pairs[row.perm[(0.7 * length(row.perm) + 1):length(row.perm)]]
  train.data <- df[df$pair_id %in% train.pairs, ]
  test.data <- df[df$pair_id %in% test.pairs, ]
  for(col in check.col.domain) {
    test.data <- test.data[test.data[, col] %in% unique(train.data[, col]), ]
  }
  return(list(train=train.data, test=test.data))
}

convert.probs.from.binary <- function(class.probs) {
  mat <- cbind(1-class.probs, class.probs)
  colnames(mat) <- c("NoDelay", "Delay")
  return(mat)
}

runTrial <- function(num.recs, skipRows) {
  perf.results <- data.frame()
  
  dat <- read.csv("data/flight-pairs.csv", nrows=skipRows + num.recs)[(skipRows+1):(skipRows+num.recs), ]
  # for now, converting outcome to binary
  dat$DepDelay <- factor(ifelse(dat$DepDelay != "[-Inf,0]", "Delay", "NoDelay"), levels=c("NoDelay", "Delay"))
  
  dep.delay.features <- subset(dat, select=-c(ArrDelay, DepDelayMinutes, Cancelled, DepartureHour))
  dep.delay.features$DayOfWeek <- factor(dep.delay.features$DayOfWeek)
  dep.delay.features$Origin <- factor(dep.delay.features$Origin)
  dep.delay.features$Month <- factor(dep.delay.features$Month)
  dep.delay.features$Dest <- factor(dep.delay.features$Dest)
  dep.delay.features <- drop.const(dep.delay.features)
  dep.delay.features <- drop.high.dim(dep.delay.features)
  dep.delay.features <- drop.rare.vals(dep.delay.features)
  
  # create 70/30 train/test split
  tt.split <- split.train.test(dep.delay.features)
  dep.delay.train <- tt.split$train
  dep.delay.train <- subset(dep.delay.train, select=-pair_id)
  dep.delay.test <- tt.split$test
  
  log.lik <- function(class.probs, actual.class) {
    return(sum(aaply(1:nrow(class.probs), 1, function(i) { 
      log(class.probs[i, as.character(actual.class[i])])
    })))
  }
  
  report.results <- function(method.name, class.probs) {
    estim.class <- aaply(class.probs, 1, function(r) names(r)[which.max(r)])
    num.correct <- sum(estim.class == dep.delay.test$DepDelay)
    class.accuracy <- num.correct/nrow(dep.delay.test)
    cat(method.name, ": ", num.correct, "/", nrow(dep.delay.test), " (", round(num.correct * 100/nrow(dep.delay.test), 2), "%)\n", sep="")
    ll <- log.lik(class.probs, dep.delay.test$DepDelay)
    cat(method.name, " log-likelihood: ", ll, "\n", sep="")
    
    dep.delay.test$zerodelayprob <- class.probs[, "NoDelay"]
    # evaluate in terms of number of correctly ranked pairs
    pair.results <- daply(dep.delay.test, .(pair_id), function(df) {
      # assuming DepDelay is an ordinal factor
      if(nrow(df) != 2) {
        return(NA)
      } else if(df[1, "DepDelay"] == df[2, "DepDelay"]) {
        return(NA)
      } else if(as.numeric(df[1, "DepDelay"]) < as.numeric(df[2, "DepDelay"]) & 
                df[1, "zerodelayprob"] > df[2, "zerodelayprob"]) {
        return(1)
      }  else if(as.numeric(df[1, "DepDelay"]) > as.numeric(df[2, "DepDelay"]) & 
                 df[1, "zerodelayprob"] < df[2, "zerodelayprob"]) {
        return(1)
      } else {
        return(0)
      }
    })
    num.correct <- sum(pair.results, na.rm=TRUE)
    num.records <- length(pair.results[!is.na(pair.results)])
    cat(method.name, " ranking accuracy: ", num.correct, "/", num.records, " (", round(num.correct * 100 / num.records, 2), "%)\n", sep="")
    return(data.frame(method=method.name, ranking.accuracy=num.correct/num.records, 
                  class.accuracy=class.accuracy, log.likelihood=ll, train.recs=nrow(dep.delay.train)))
  }
  
  cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
  
  # Baseline model #1 -- predict uniform probabilities
  unique.outcomes <- unique(dep.delay.test$DepDelay)
  baseline.probs <- rep(1./length(unique.outcomes), length(unique.outcomes))
  prob.mat <- matrix(rep(baseline.probs, nrow(dep.delay.test)), ncol=length(baseline.probs), byrow=TRUE)
  colnames(prob.mat) <- unique.outcomes
  perf.results <- rbind(perf.results, report.results("Uniform", prob.mat))
  
  cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
  
  # Baseline model #2 -- predict from training distribution marginals
  mode.delay <- names(which.max(table(dep.delay.train$DepDelay)))
  baseline.probs <- prop.table(table(dep.delay.train$DepDelay))
  prob.mat <- matrix(rep(baseline.probs, nrow(dep.delay.test)), ncol=length(baseline.probs), byrow=TRUE)
  colnames(prob.mat) <- names(baseline.probs)
  perf.results <- rbind(perf.results, report.results("Marginal", prob.mat))
  
  cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
  
  # Baseline model #3 -- completely random predictions
  prob.mat <- matrix(runif(0, 1, n=2 * nrow(dep.delay.test)), ncol=2)
  colnames(prob.mat) <- names(baseline.probs)
  perf.results <- rbind(perf.results, report.results("Random", prob.mat))
  
  cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
  
  # Multinomial logistic
  glmmodel <- glm(DepDelay == "Delay" ~ ., data=dep.delay.train, family="binomial")
  class.probs <- predict(glmmodel, newdata=dep.delay.test, type="response")
  class.probs <- convert.probs.from.binary(class.probs)
  perf.results <- rbind(perf.results, report.results("Logistic", class.probs))
  
  cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
  
  # Decision tree
  dtree <- rpart(DepDelay ~ ., data=dep.delay.train, control=rpart.control(cp=0.005, xval=0))
  class.probs <- predict(dtree, newdata=dep.delay.test, type="prob")
  obs <- predict(dtree, newdata=dep.delay.test, type="matrix")[, 2:(1+ncol(class.probs))]
  smooth.obs <- obs + 1
  smooth.probs <- prop.table(smooth.obs, margin=1)
  colnames(smooth.probs) <- colnames(class.probs)
  perf.results <- rbind(perf.results, report.results("Decision tree", smooth.probs))
  
  cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
  
  # SVM
  # parameters set independently with linear search
  gamma <- 0.02
  zero.weight <- 0.5
  cost <- 2.5
  svm.model <- svm(DepDelay ~ ., data=dep.delay.train, class.weights=c("NoDelay" = zero.weight), probability=TRUE, gamma=gamma, cost=cost)
  class.probs <- attr(predict(svm.model, newdata=dep.delay.test, probability=TRUE), "probabilities")
  config.name <- paste0("SVM(gamma=", gamma, ", 0-weight=", zero.weight, ", C=", cost, ")")
  perf.results <- rbind(perf.results, report.results(config.name, class.probs))
  
  cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
  gpmodel <- gausspr(DepDelay ~ ., data=dep.delay.train[1:1000, ])
  class.probs <- predict(gpmodel, newdata=dep.delay.test, type="probabilities")
  perf.results <- rbind(perf.results, report.results("Gaussian process", class.probs))
  
  cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
  rmodel <- ranger(DepDelay ~ ., data=dep.delay.train, probability=TRUE, write.forest=TRUE, num.trees=1000)
  class.probs <- predict(rmodel, data=dep.delay.test, probability=TRUE)$predictions
  perf.results <- rbind(perf.results, report.results("Random forest", class.probs))
  
  cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
  bmodel <- gbm(DepDelay ~ ., data=dep.delay.train, n.trees=1000, distribution="multinomial", cv.folds=5)
  optimal.trees <- gbm.perf(bmodel)
  predictions <- predict(bmodel, newdata=dep.delay.test, n.trees=optimal.trees, type="response")[, , 1]
  perf.results <- rbind(perf.results, report.results(paste0("Boosted classification trees (", optimal.trees, " trees)"), predictions))
  
  return(perf.results)
}

all.results <- NULL
#for(data.size in c(500, 1000, 2000, 3000)) {
for(data.size in c(5000)) {
  for(trial in 1:10) {
    cur.results <- runTrial(data.size, (trial-1)*data.size)
    cur.results$nrecs <- data.size
    all.results <- rbind(cur.results, all.results)
    print(all.results)
  }
}

write.csv(all.results, file="results/one-day-horizon-results.csv")
