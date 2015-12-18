# Avoiding Flight Delays with Supervised Ranking

Dan Garant, John Lalor, Adam Nelson

## Repository structure

* **code** contains R and Python scripts that are were used to prepare data and execute models. Python was primarily used for data preparation, and R was primarily used for training and using models.
* **data** contains CSV files of features used when fitting models. *flight-pairs.csv* and *flight-pairs-30-2.csv* sub-sampled versions of the feature files used for the 1-day and 30-day tasks, respectively.
* **writeup** contains the LaTeX source code for our report, which is also in compiled form in the root of the repository, *report.pdf*.
* **results** contains tables of results that were used to generate Figures 4 and 5 in our report.

## R dependencies

We used a wide variety of R packages to fit and evaluate machine learning models, which can be installed by running the following command in an R shell:
	
	install.packages("e1071", "plyr", "nnet", "rpart", "ranger", "caret", "kernlab", "tgp", "gbm", "mgcv", "ggplot2", "stringr")

## Running the models

To reproduce Figures 1-3, issue the following command from the root of the repository:

	Rscript code/exploratory-analysis.R
	
Results will appear in Rplots.pdf and in `writeup/figures/`

To reproduce the results used to generate Figures 4 and 5, issue the following commands:

	Rscript code/one-day-horizon-models.R
	Rscript code/thirty-day-horizon-models.R
	
Results will appear at `results/one-day-horizon-results.R` and `results/thirty-day-horizon-results.R`