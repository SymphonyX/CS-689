library(e1071)
library(plyr)
library(nnet)
library(rpart)

dat <- read.csv("../data/features2-shuf.csv", nrows=5000)

dep.delay.features <- subset(dat, select=-c(ArrDelay, Cancelled, DepartureHour))
dep.delay.features$DayOfWeek <- factor(dep.delay.features$DayOfWeek)

# eliminate any constant features -- typically only necessary when using a subset of the full data
keep.cols <- aaply(colnames(dep.delay.features), 1, function(c) length(unique(dep.delay.features[, c])) > 1)
dep.delay.features <- dep.delay.features[, keep.cols]
dep.delay.features <- dep.delay.features[complete.cases(dep.delay.features), ]

# eliminate factors that have as many levels as rows
drop.factors <- aaply(colnames(dep.delay.features), 1, function(c) 
  is.factor(dep.delay.features[, c]) && length(levels(dep.delay.features[, c])) == nrow(dep.delay.features))
dep.delay.features <- dep.delay.features[, !drop.factors]

# create 70/30 train/test split
row.perm <- sample(nrow(dep.delay.features))
dep.delay.train <- dep.delay.features[row.perm[1:(0.7 * length(row.perm))], ]
dep.delay.test <- dep.delay.features[row.perm[(0.7 * length(row.perm) + 1):length(row.perm)], ]

log.lik <- function(class.probs, actual.class) {
  return(sum(aaply(1:nrow(class.probs), 1, function(i) { 
    log(class.probs[i, as.character(actual.class[i])])
  })))
}

report.results <- function(method.name, class.probs) {
  estim.class <- aaply(class.probs, 1, function(r) names(r)[which.max(r)])
  num.correct <- sum(estim.class == dep.delay.test$DepDelay)
  cat(method.name, ": ", num.correct, "/", nrow(dep.delay.test), " (", round(num.correct/nrow(dep.delay.test), 3), "%)\n", sep="")
  cat(method.name, " log-likelihood: ", log.lik(class.probs, dep.delay.test$DepDelay), "\n", sep="")
}

cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")

# Baseline model #1 -- predict uniform probabilities
unique.outcomes <- unique(dep.delay.test$DepDelay)
baseline.probs <- rep(1./length(unique.outcomes), length(unique.outcomes))
prob.mat <- matrix(rep(baseline.probs, nrow(dep.delay.test)), ncol=length(baseline.probs), byrow=TRUE)
colnames(prob.mat) <- unique.outcomes
report.results("Uniform", prob.mat)

cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")

# Baseline model #2 -- predict from training distribution marginals
mode.delay <- names(which.max(table(dep.delay.train$DepDelay)))
baseline.probs <- prop.table(table(dep.delay.train$DepDelay))
prob.mat <- matrix(rep(baseline.probs, nrow(dep.delay.test)), ncol=length(baseline.probs), byrow=TRUE)
colnames(prob.mat) <- names(baseline.probs)
report.results("Marginal", prob.mat)


cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")

# Multinomial logistic
mmodel <- multinom(DepDelay ~ ., data=dep.delay.train, MaxNWts=5000, maxit=500, trace=FALSE)
class.probs <- predict(mmodel, newdata=dep.delay.test, type="prob")
report.results("Multinomial", class.probs)

cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")

# Decision tree
dtree <- rpart(DepDelay ~ ., data=dep.delay.train, control=rpart.control(cp=0.005, xval=0))
class.probs <- predict(dtree, newdata=dep.delay.test, type="prob")
obs <- predict(dtree, newdata=dep.delay.test, type="matrix")[, 2:(1+ncol(class.probs))]
smooth.obs <- obs + 1
smooth.probs <- prop.table(smooth.obs, margin=1)
colnames(smooth.probs) <- colnames(class.probs)
report.results("Decision tree", smooth.probs)

cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")

# SVM
# parameters set independently with linear search
gamma <- 0.02
zero.weight <- 0.5
cost <- 2.5
svm.model <- svm(DepDelay ~ ., data=dep.delay.train, class.weights=c("[-Inf,0]" = zero.weight), probability=TRUE, gamma=gamma, cost=cost)
class.probs <- attr(predict(svm.model, newdata=dep.delay.test, probability=TRUE), "probabilities")
report.results(paste0("SVM(gamma=", gamma, ", 0-weight=", zero.weight, ", C=", cost, ")"), class.probs)