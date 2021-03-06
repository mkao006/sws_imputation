% Generated by roxygen2 (4.0.1): do not edit by hand
\name{imputeProduction}
\alias{imputeProduction}
\title{Function to impute production}
\usage{
imputeProduction(productionValue, productionObservationFlag,
  productionMethodFlag, areaHarvestedValue, areaHarvestedObservationFlag,
  areaHarvestedMethodFlag, yieldValue, yieldObservationFlag, yieldMethodFlag,
  imputationFlag = "I", newMethodFlag, data, byKey, restrictWeights = TRUE,
  maximumWeights = 0.7, ensembleModel = list(defaultMean = defaultMean,
  defaultLm = defaultLm, defaultExp = defaultExp, defaultLogistic =
  defaultLogistic, defaultLoess = defaultLoess, defaultSpline = defaultSpline,
  defaultArima = defaultArima, defaultMars = defaultMars, defaultNaive =
  defaultNaive), flagTable = faoswsFlagTable)
}
\arguments{
\item{productionValue}{The column name corresponding to production
value.}

\item{productionObservationFlag}{The column name corresponding to the
observation flag of production.}

\item{areaHarvestedValue}{The column name corresponding to area
harvested value.}

\item{areaHarvestedObservationFlag}{The column name corresponding to the
observation flag of area harvested.}

\item{yieldValue}{The columne name corresponding to yield value.}

\item{yieldObservationFlag}{The column name corresponding to the observation
flag of yield.}

\item{imputationFlag}{Flag value for new imputation values.}

\item{flagTable}{see data(faoswsFlagTable) in \pkg{faoswsFlag}}

\item{data}{The data.table object containing the data.}

\item{byKey}{The unique key identifier.}

\item{ensembleModel}{A list of models to be used to build the
ensemble.}

\item{restrictWeights}{Whether a maximum weight restriction should
be imposed.}

\item{maximumWeights}{The maximum weight to be imposed, must be
between [0.5, 1].}
}
\description{
This is a wrapper of the ensemble imputation for the production
domain.
}

