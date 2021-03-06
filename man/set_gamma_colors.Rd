% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/TS_plots.R
\name{set_gamma_colors}
\alias{set_gamma_colors}
\title{Prepare the colors to be used in the gamma time series}
\usage{
set_gamma_colors(x, cols = NULL, option = "D", alpha = 1)
}
\arguments{
\item{x}{Object of class \code{TS_fit}, fit by \code{\link{TS}}.}

\item{cols}{Colors to be used to plot the time series of fitted topic 
proportions.}

\item{option}{A \code{character} string indicating the color option
from \code{\link[viridis]{viridis}} to use if "cols == NULL". Four 
options are available: "magma" (or "A"), "inferno" (or "B"), "plasma" 
(or "C"), "viridis" (or "D", the default option) and "cividis" (or "E").}

\item{alpha}{Numeric value [0,1] that indicates the transparency of the 
colors used. Supported only on some devices, see 
\code{\link[grDevices]{rgb}}.}
}
\value{
Vector of \code{character} hex codes indicating colors to use.
}
\description{
Based on the inputs, create the set of colors to be used in
  the time series of the fitted gamma (topic proportion) values.
}
\examples{
\donttest{
  data(rodents)
  document_term_table <- rodents$document_term_table
  document_covariate_table <- rodents$document_covariate_table
  LDA_models <- LDA_set(document_term_table, topics = 2)[[1]]
  data <- document_covariate_table
  data$gamma <- LDA_models@gamma
  weights <- document_weights(document_term_table)
  TSmod <- TS(data, gamma ~ 1, nchangepoints = 1, "newmoon", weights)
  set_gamma_colors(TSmod)
}

}
