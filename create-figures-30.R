library(ggplot2)
library(plyr)
library(stringr)

d <- read.csv("thirty-day-horizon-results-2.csv")
d$method <- str_replace(d$method, "Boosted classification.+", "Boosted classification")
d$method <- str_replace(d$method, "SVM.+", "SVM")

d.summ <- ddply(d, .(method, nrecs), summarize, ranking.acc.median=median(ranking.accuracy))

g <- ggplot(subset(d, !(method %in% c("Uniform", "Marginal", "Random"))), aes(x=nrecs, y=ranking.accuracy)) + 
    geom_boxplot(aes(x=factor(nrecs), fill=method)) + 
    labs(x="Sample Size", y="Ranking Accuracy") + geom_hline(yintercept=0.5, color="blue", size=2) + 
    theme_bw(base_size=16) + theme(legend.position="top") + guides(fill=guide_legend(title="Method", ncol=3))
print(g)
png("writeup/figures/performance-by-sample-size-30.png", width=800, height=400)
print(g)
dev.off()


