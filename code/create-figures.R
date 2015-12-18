library(ggplot2)
library(plyr)
library(stringr)

d1 <- read.csv("one-day-horizon-results.csv")
d1$type <- "One Day Horizon"
d2 <- read.csv("thirty-day-horizon-results.csv")
d2$type <- "One Month Horizon"
d <- rbind(d1, d2)

d$method <- str_replace(d$method, "Boosted classification.+", "Boosted classification")
d$method <- str_replace(d$method, "SVM.+", "SVM")

d.summ <- ddply(d, .(method, nrecs), summarize, ranking.acc.median=median(ranking.accuracy))

g <- ggplot(subset(d, !(method %in% c("Uniform", "Random"))), aes(x=nrecs, y=class.accuracy)) + 
  geom_boxplot(aes(x=factor(nrecs), fill=method)) + 
  labs(x="Sample Size", y="Classification Accuracy") + facet_grid(~type) +
  theme_bw(base_size=16) + theme(legend.position="top") + guides(fill=guide_legend(title="Method", ncol=3))
print(g)
png("writeup/figures/class-performance-by-sample-size.png", width=800, height=400)
print(g)
dev.off()

g <- ggplot(subset(d, !(method %in% c("Uniform", "Marginal", "Random"))), aes(x=nrecs, y=ranking.accuracy)) + 
    geom_boxplot(aes(x=factor(nrecs), fill=method)) + facet_grid(~type) +
    labs(x="Sample Size", y="Ranking Accuracy") + geom_hline(yintercept=0.5, color="blue", size=2) + 
    theme_bw(base_size=16) + theme(legend.position="top") + guides(fill=guide_legend(title="Method", ncol=3))
print(g)
png("writeup/figures/performance-by-sample-size.png", width=800, height=400)
print(g)
dev.off()


for(curtype in c("One Day Horizon", "One Month Horizon")) {
  d5000 <- subset(d, nrecs==5000&type==curtype)
  d5000$method <- str_replace(d5000$method, "Boosted classification", "Boosted\nclassification")
  d5000$method <- str_replace(d5000$method, "Random forest", "Random\nforest")
  d5000$method <- str_replace(d5000$method, "Decision tree", "Decision\ntree")
  d5000$method <- str_replace(d5000$method, "Gaussian process", "Gaussian\nprocess")
  g <- ggplot(subset(d5000, !(method %in% c("Uniform", "Random"))), aes(x=method, y=class.accuracy, fill=method)) + 
    geom_boxplot() + 
    labs(x="Method", y="Classification Accuracy") +
    theme_bw(base_size=16) + theme(legend.position="top") + guides(fill="none")#guide_legend(title="Method", ncol=3))
  print(g)
  png(paste0("writeup/figures/class-performance-sample-5000-", str_replace_all(curtype, "\\s", ""), ".png"), width=500, height=400)
  print(g)
  dev.off()
  
  g <- ggplot(subset(d5000, !(method %in% c("Uniform", "Marginal"))), aes(x=method, y=ranking.accuracy, fill=method)) + 
      geom_boxplot() + labs(x="Method", y="Ranking Accuracy") + geom_hline(yintercept=0.5, color="blue", size=2) + 
      theme_bw(base_size=16) + theme(legend.position="top") + guides(fill="none")#guide_legend(title="Method", ncol=3))
  print(g)
  png(paste0("writeup/figures/performance-sample-5000-", str_replace_all(curtype, "\\s", ""), ".png"), width=500, height=400)
  print(g)
  dev.off()
}