% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/TS_plots.R
\name{trace_plot}
\alias{trace_plot}
\title{Produce the trace plot panel for the TS diagnostic plot of a 
  parameter}
\usage{
trace_plot(x, ylab = "parameter value")
}
\arguments{
\item{x}{Vector of parameter values drawn from the posterior distribution,
indexed to the iteration by the order of the vector.}

\item{ylab}{\code{character} value used to label the y axis.}
}
\value{
\code{NULL}.
}
\description{
Produce a trace plot for the parameter of interest (rho or 
  eta) as part of \code{\link{TS_diagnostics_plot}}. A horizontal line 
  is added to show the median of the posterior.
}
\examples{
 trace_plot(rnorm(100, 0, 1))

}
