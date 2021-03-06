\name{swsImputation}
\alias{swsImputation}
\title{The function to perform imputation for area, production and yield
simultaneously.}
\usage{
  swsImputation(data, area, prod, yield, country, region,
    year, n.iter = 1000, tol = 1e-08, EMverbose = FALSE,
    meanType = c("meanlme4", "shocklme4"))
}
\arguments{
  \item{data}{The data.frame or data.table containing the
  data.}

  \item{area}{The column containing the area time series.}

  \item{prod}{The column containing the production time
  series.}

  \item{yield}{The column containing the yield time
  series.}

  \item{country}{The column representing the country name,
  if in code then convert to factor.}

  \item{region}{The column representing the regional
  classification, if in code then convert to factor.}

  \item{year}{The column containing the time information.}

  \item{n.iter}{The number of iteration for lmeIputation.}

  \item{tol}{Tolerance, the stopping rule for the
  Likelihood.}

  \item{meanType}{The type of aggregated model used}
}
\description{
  This function is the implementation which is illustrated
  in the vignette to perform imputation for the three
  related time series of FAO production domain.
}
\seealso{
  \code{\link{lmeImpute}}
}

