#' @title Conduct a set of Time Series analyses on a set of LDA models
#'
#' @description This is a wrapper function that expands the main Time Series
#'   analyses function (\code{\link{TS}}) across the LDA models (estimated
#'   using \code{\link[topicmodels]{LDA}} or \code{\link{LDA_set}} and the 
#'   Time Series models, with respect to both continuous time formulas and the 
#'   number of discrete changepoints. This function allows direct passage of
#'   the control parameters for the parallel tempering MCMC through to the 
#'   main Time Series function, \code{\link{TS}}, via the 
#'   \code{ptMCMC_controls} argument. \cr \cr
#'   \code{check_TS_on_LDA_inputs} checks that the inputs to 
#'   \code{TS_on_LDA} are of proper classes for a full analysis.
#'
#' @param LDA_models List of LDA models (class \code{LDA_set}, produced by
#'   \code{\link{LDA_set}}) or a singular LDA model (class \code{LDA},
#'   produced by \code{\link[topicmodels]{LDA}}).
#'
#' @param document_covariate_table Document covariate table (rows: documents,
#'   columns: time index and covariate options). Every model needs a
#'   covariate to describe the time value for each document (in whatever 
#'   units and whose name in the table is input in \code{timename})
#'   that dictates the application of the change points. 
#'   In addition, all covariates named within specific models in
#'   \code{formula} must be included. Must be a conformable to a data table,
#'   as verified by \code{\link{check_document_covariate_table}}. 
#'
#' @param formulas Vector of \code{\link[stats]{formula}}(s) for the 
#'   continuous (non-change point) component of the time series models. Any 
#'   predictor variable included in a formula must also be a column in the
#'   \code{document_covariate_table}. Each element (formula) in the vector
#'   is evaluated for each number of change points and each LDA model.
#'
#' @param nchangepoints Vector of \code{integer}s corresponding to the number 
#'   of change points to include in the time series models. 0 is a valid input 
#'   corresponding to no change points (\emph{i.e.}, a singular time series
#'   model), and the current implementation can reasonably include up to 6 
#'   change points. Each element in the vector is the number of change points 
#'   used to segment the data for each formula (entry in \code{formulas}) 
#'   component of the TS model, for each selected LDA model.
#'
#' @param timename \code{character} element indicating the time variable
#'   used in the time series. Defaults to \code{"time"}. The variable must be
#'   integer-conformable or a \code{Date}. If the variable named
#'   is a \code{Date}, the input is converted to an integer, resulting in the
#'   timestep being 1 day, which is often not desired behavior.
#'
#' @param weights Optional class \code{numeric} vector of weights for each 
#'   document. Defaults to \code{NULL}, translating to an equal weight for
#'   each document. When using \code{multinom_TS} in a standard LDATS 
#'   analysis, it is advisable to weight the documents by their total size,
#'   as the result of \code{\link[topicmodels]{LDA}} is a matrix of 
#'   proportions, which does not account for size differences among documents.
#'   For most models, a scaling of the weights (so that the average is 1) is
#'   most appropriate, and this is accomplished using \code{document_weights}.
#'
#' @param control A \code{list} of parameters to control the fitting of the
#'   Time Series model including the parallel tempering Markov Chain 
#'   Monte Carlo (ptMCMC) controls. Values not input assume defaults set by 
#'   \code{\link{TS_control}}.
#'
#' @return \code{TS_on_LDA}: \code{TS_on_LDA}-class \code{list} of results 
#'   from \code{\link{TS}} applied for each model on each LDA model input.
#'   \cr \cr
#'   \code{check_TS_inputs}: An error message is thrown if any input
#'   is not proper, else \code{NULL}.
#'
#' @examples
#' \donttest{
#'   data(rodents)
#'   document_term_table <- rodents$document_term_table
#'   document_covariate_table <- rodents$document_covariate_table
#'   LDAs <- LDA_set(document_term_table, topics = 2:3, nseeds = 2)
#'   LDA_models <- select_LDA(LDAs)
#'   weights <- document_weights(document_term_table)
#'   formulas <- c(~ 1, ~ newmoon)
#'   mods <- TS_on_LDA(LDA_models, document_covariate_table, formulas,
#'                     nchangepoints = 0:1, timename = "newmoon", weights)
#' }
#'
#' @export
#'
TS_on_LDA <- function(LDA_models, document_covariate_table, formulas = ~ 1, 
                      nchangepoints = 0, timename = "time", weights = NULL, 
                      control = list()){
  check_TS_on_LDA_inputs(LDA_models, document_covariate_table, formulas, 
                         nchangepoints, timename, weights, control)
  control <- do.call("TS_control", control)
  mods <- expand_TS(LDA_models, formulas, nchangepoints)
  nmods <- nrow(mods)
  TSmods <- vector("list", nmods)

  for(i in 1:nmods){
    print_model_run_message(mods, i, LDA_models, control)
    formula_i <- mods$formula[[i]]
    nchangepoints_i <- mods$nchangepoints[i]
    data_i <- prep_TS_data(document_covariate_table, LDA_models, mods, i)
    TSmods[[i]] <- TS(data_i, formula_i, nchangepoints_i, timename, weights, 
                      control)
  }
  package_TS_on_LDA(TSmods, LDA_models, mods)

}

#' @title Prepare the model-specific data to be used in the TS analysis
#'   of LDA output
#' 
#' @description Append the estimated topic proportions from a fitted LDA model 
#'   to the document covariate table to create the data structure needed for 
#'   \code{\link{TS}}.
#'
#' @param document_covariate_table Document covariate table (rows: documents,
#'   columns: time index and covariate options). Every model needs a
#'   covariate to describe the time value for each document (in whatever 
#'   units and whose name in the table is input in \code{timename})
#'   that dictates the application of the change points. 
#'   In addition, all covariates named within specific models in
#'   \code{formula} must be included. Must be a conformable to a data table,
#'   as verified by \code{\link{check_document_covariate_table}}. 
#'
#' @param LDA_models List of LDA models (class \code{LDA_set}, produced by
#'   \code{\link{LDA_set}}) or a singular LDA model (class \code{LDA},
#'   produced by \code{\link[topicmodels]{LDA}}).
#'
#' @param mods The \code{data.table} created by \code{\link{expand_TS}} that 
#'   contains each of the models (defined by the LDA model to use and the and
#'   formula number of changepoints for the TS model). Indexed here by 
#'   \code{i}.
#'
#' @param i \code{integer} index referencing the row in \code{mods} to use.
#'
#' @return Class \code{data.frame} object including [1] the time variable
#'   (indicated in \code{control}), [2] the predictor variables (required by
#'   \code{formula}) and [3], the multinomial response variable (indicated
#'   in \code{formula}), ready for input into \code{TS}.
#'
#' @examples
#' \donttest{
#'   data(rodents)
#'   document_term_table <- rodents$document_term_table
#'   document_covariate_table <- rodents$document_covariate_table
#'   LDAs <- LDA_set(document_term_table, topics = 2:3, nseeds = 2)
#'   LDA_models <- select_LDA(LDAs)
#'   weights <- document_weights(document_term_table)
#'   formulas <- c(~ 1, ~ newmoon)
#'   mods <- expand_TS(LDA_models, formulas = ~1, nchangepoints = 0)
#'   data1 <- prep_TS_data(document_covariate_table, LDA_models, mods)
#' }
#'
#' @export
#'
prep_TS_data <- function(document_covariate_table, LDA_models, mods, i = 1){
  check_document_covariate_table(document_covariate_table, LDA_models)
  check_LDA_models(LDA_models)
  if(is(LDA_models, "LDA")){
    LDA_models <- c(LDA_models)
    class(LDA_models) <- c("LDA_set", "list")
  }
  data_i <- document_covariate_table
  data_i$gamma <- LDA_models[[mods$LDA[i]]]@gamma
  data_i
}

#' @title Select the best Time Series model
#'
#' @description Select the best model of interest from an
#'   \code{TS_on_LDA} object generated by \code{\link{TS_on_LDA}}, based on
#'   a set of user-provided functions. The functions default to choosing the 
#'   model with the lowest AIC value. \cr \cr
#'   Presently, the set of functions should result in a singular selected
#'   model. If multiple models are chosen via the selection, only the first
#'   is returned.
#'
#' @param TS_models An object of class \code{TS_on_LDA} produced by
#'   \code{\link{TS_on_LDA}}.
#'
#' @param control A \code{list} of parameters to control the fitting of the
#'   Time Series model including the parallel tempering Markov Chain 
#'   Monte Carlo (ptMCMC) controls. Values not input assume defaults set by 
#'   \code{\link{TS_control}}.
#'
#' @return A reduced version of \code{TS_models} that only includes the 
#'   selected TS model. The returned object is a single TS model object of
#'   class \code{TS_fit}.
#'
#' @examples
#' \donttest{
#'   data(rodents)
#'   document_term_table <- rodents$document_term_table
#'   document_covariate_table <- rodents$document_covariate_table
#'   LDAs <- LDA_set(document_term_table, topics = 2:3, nseeds = 2)
#'   LDA_models <- select_LDA(LDAs)
#'   weights <- document_weights(document_term_table)
#'   formulas <- c(~ 1, ~ newmoon)
#'   mods <- TS_on_LDA(LDA_models, document_covariate_table, formulas,
#'                     nchangepoints = 0:1, timename = "newmoon", weights)
#'   select_TS(mods)
#' }
#'
#' @export
#'
select_TS <- function(TS_models, control = list()){
  if (!("TS_on_LDA" %in% class(TS_models))){
    stop("TS_models must be of class TS_on_LDA")
  }
  check_control(control)
  control <- do.call("TS_control", control)
  measurer <- control$measurer
  selector <- control$selector
  TS_measured <- vapply(TS_models, measurer, 0) %>%
                  matrix(ncol = 1)
  TS_selected <- apply(TS_measured, 2, selector) 
  which_selected <- which(TS_measured %in% TS_selected)
  if (length(which_selected) > 1){
    warning("Selection results in multiple models, returning first")
    which_selected <- which_selected[1]
  }
  out <- TS_models[[which_selected]]
  class(out)  <- c("TS_fit", "list") 
  out
}

#' @title Package the output of TS_on_LDA
#'
#' @description Set the class and name the elements of the results list 
#'   returned from applying \code{\link{TS}} to the combination of TS models
#'   requested for the LDA model(s) input.
#'
#' @param TSmods list of results from \code{\link{TS}} applied for each model 
#'   on each LDA model input.
#'
#' @param LDA_models List of LDA models (class \code{LDA_set}, produced by
#'   \code{\link{LDA_set}}) or a singular LDA model (class \code{LDA},
#'   produced by \code{\link[topicmodels]{LDA}}).
#'
#' @param models \code{data.frame} object returned from 
#'   \code{\link{expand_TS}} that contains the combinations of LDA models, 
#'   and formulas and nchangepoints used in the TS models.
#'
#' @return Class \code{TS_on_LDA} list of results from \code{\link{TS}} 
#'   applied for each model on each LDA model input.
#'
#' @examples
#' \donttest{
#'   data(rodents)
#'   document_term_table <- rodents$document_term_table
#'   document_covariate_table <- rodents$document_covariate_table
#'   LDAs <- LDA_set(document_term_table, topics = 2:3, nseeds = 2)
#'   LDA_models <- select_LDA(LDAs)
#'   weights <- document_weights(document_term_table)
#'   mods <- expand_TS(LDA_models, c(~ 1, ~ newmoon), 0:1)
#'   nmods <- nrow(mods)
#'   TSmods <- vector("list", nmods)
#'   for(i in 1:nmods){
#'     formula_i <- mods$formula[[i]]
#'     nchangepoints_i <- mods$nchangepoints[i]
#'     data_i <- prep_TS_data(document_covariate_table, LDA_models, mods, i)
#'     TSmods[[i]] <- TS(data_i, formula_i, nchangepoints_i, "newmoon", 
#'                       weights, TS_control())
#'   }
#'   package_TS_on_LDA(TSmods, LDA_models, mods)
#' }
#'
#' @export
#'
package_TS_on_LDA <- function(TSmods, LDA_models, models){
  check_LDA_models(LDA_models)
  if(is(LDA_models, "LDA")){
    LDA_models <- c(LDA_models)
    class(LDA_models) <- c("LDA_set", "list")
  }
  nmodels <- nrow(models)
  nms <- rep(NA, nmodels)
  for (i in 1:nmodels){
    nms[i] <- paste0(names(LDA_models)[models$LDA[i]], ", ", 
                     deparse(models$formula[[i]]), ", ", 
                     models$nchangepoints[i], " changepoints")
  }
  names(TSmods) <- nms
  class(TSmods) <- list("TS_on_LDA", "list")
  TSmods
}


#' @title Print a set of Time Series models fit to LDAs
#'
#' @description Convenience function to print only the names of a 
#'   \code{TS_on_LDA}-class object generated by \code{\link{TS_on_LDA}}.
#'
#' @param x Class \code{TS_on_LDA} object to be printed.
#'
#' @param ... Not used, simply included to maintain method compatibility.
#'
#' @return \code{character} \code{vector} of the names of \code{x}'s models.
#'
#' @examples
#' \donttest{
#'   data(rodents)
#'   document_term_table <- rodents$document_term_table
#'   document_covariate_table <- rodents$document_covariate_table
#'   LDAs <- LDA_set(document_term_table, topics = 2:3, nseeds = 2)
#'   LDA_models <- select_LDA(LDAs)
#'   weights <- document_weights(document_term_table)
#'   formulas <- c(~ 1, ~ newmoon)
#'   mods <- TS_on_LDA(LDA_models, document_covariate_table, formulas,
#'                     nchangepoints = 0:1, timename = "newmoon", weights)
#'   print(mods)
#' }
#'
#' @export
#'
print.TS_on_LDA <- function(x, ...){
  print(names(x))
}

#' @title Print the message to the console about which combination of the 
#'   Time Series and LDA models is being run
#'
#' @description If desired, print a message at the beginning of every model
#'   combination stating the TS model and the LDA model being evaluated.
#'
#' @param models \code{data.frame} object returned from 
#'   \code{\link{expand_TS}} that contains the combinations of LDA models, 
#'   and formulas and nchangepoints used in the TS models.
#'
#' @param i \code{integer} index of the row to use from \code{models}.
#'
#' @param LDA_models List of LDA models (class \code{LDA_set}, produced by
#'   \code{\link{LDA_set}}) or a singular LDA model (class \code{LDA},
#'   produced by \code{\link[topicmodels]{LDA}}).
#'
#' @param control A \code{list} of parameters to control the fitting of the
#'   Time Series model including the parallel tempering Markov Chain 
#'   Monte Carlo (ptMCMC) controls. Values not input assume defaults set by 
#'   \code{\link{TS_control}}. Of particular importance here is 
#'   the \code{logical}-class element named \code{quiet}.
#'
#' @return \code{NULL}.
#'
#' @examples
#' \donttest{
#'   data(rodents)
#'   document_term_table <- rodents$document_term_table
#'   document_covariate_table <- rodents$document_covariate_table
#'   LDAs <- LDA_set(document_term_table, topics = 2:3, nseeds = 2)
#'   LDA_models <- select_LDA(LDAs)
#'   weights <- document_weights(document_term_table)
#'   formulas <- c(~ 1, ~ newmoon)
#'   nchangepoints <- 0:1
#'   mods <- expand_TS(LDA_models, formulas, nchangepoints)
#'   print_model_run_message(mods, 1, LDA_models, TS_control())
#' }
#'
#' @export
#'
print_model_run_message <- function(models, i, LDA_models, control){
  control <- do.call("TS_control", control)
  equation <- deparse(models$formula[[i]])
  chngpt_msg <- paste0("with ", models$nchangepoints[i], " changepoints ")
  reg_msg <- paste0("and equation ", equation)
  ts_msg <- paste0(chngpt_msg, reg_msg)
  lda_msg <- names(LDA_models)[models$LDA[i]]
  msg <- paste0("Running TS model ", ts_msg, " on LDA model ", lda_msg, "\n")
  messageq(msg, control$quiet)
}

#' @title Expand the TS models across the factorial combination of
#'   LDA models, formulas, and number of change points
#' 
#' @description Expand the completely crossed combination of model inputs: 
#'   LDA model results, formulas, and number of change points. 
#'   
#' @param LDA_models List of LDA models (class \code{LDA_set}, produced by
#'   \code{\link{LDA_set}}) or a singular LDA model (class \code{LDA},
#'   produced by \code{\link[topicmodels]{LDA}}).
#'
#' @param formulas Vector of \code{\link[stats]{formula}}(s) for the 
#'   continuous (non-change point) component of the time series models. Any 
#'   predictor variable included in a formula must also be a column in the
#'   \code{document_covariate_table}. Each element (formula) in the vector
#'   is evaluated for each number of change points and each LDA model.
#'
#' @param nchangepoints Vector of \code{integer}s corresponding to the number 
#'   of change points to include in the time series models. 0 is a valid input 
#'   corresponding to no change points (\emph{i.e.}, a singular time series
#'   model), and the current implementation can reasonably include up to 6 
#'   change points. Each element in the vector is the number of change points 
#'   used to segment the data for each formula (entry in \code{formulas}) 
#'   component of the TS model, for each selected LDA model.
#'
#' @return Expanded \code{data.frame} table of the three values (columns) for
#'   each unique model run (rows): [1] the LDA model (indicated
#'   as a numeric element reference to the \code{LDA_models} object), [2] the 
#'   regressor formula, and [3] the number of changepoints.
#' 
#' @examples
#' \donttest{
#'   data(rodents)
#'   document_term_table <- rodents$document_term_table
#'   document_covariate_table <- rodents$document_covariate_table
#'   LDAs <- LDA_set(document_term_table, topics = 2:3, nseeds = 2)
#'   LDA_models <- select_LDA(LDAs)
#'   weights <- document_weights(document_term_table)
#'   formulas <- c(~ 1, ~ newmoon)
#'   nchangepoints <- 0:1
#'   expand_TS(LDA_models, formulas, nchangepoints)
#' }
#'
#' @export
#'
expand_TS <- function(LDA_models, formulas, nchangepoints){
  check_LDA_models(LDA_models)
  check_nchangepoints(nchangepoints)
  if (is(LDA_models, "LDA")) {
    LDA_models <- c(LDA_models)
    class(LDA_models) <- c("LDA_set", "list")
  }
  if (!is(formulas, "list")) {
    if (is(formulas, "formula")) {
      formulas <- c(formulas)
    } else{
      stop("formulas does not contain formula(s)")
    }
  } else if (!all(vapply(formulas, is, TRUE, "formula"))) {
      stop("formulas does not contain all formula(s)")
  }
  formulas
  
  out <- formulas
  for (i in seq_along(formulas)) {
    tformula <- paste(as.character(formulas[[i]]), collapse = "")
    out[[i]] <- as.formula(paste("gamma", tformula))
  }
  formulas <- out
  nmods <- length(LDA_models)
  mods <- 1:nmods
  out <- expand.grid(mods, formulas, nchangepoints, stringsAsFactors = FALSE)
  colnames(out) <- c("LDA", "formula", "nchangepoints") 
  out
}

#' @title Check that nchangepoints vector is proper
#' 
#' @description Check that the vector of numbers of changepoints is 
#'   conformable to integers greater than 1.
#'   
#' @param nchangepoints Vector of the number of changepoints to evaluate.
#' 
#' @return An error message is thrown if \code{nchangepoints} is not proper,
#'   else \code{NULL}.
#' 
#' @examples
#'   check_nchangepoints(0)
#'   check_nchangepoints(2)
#'
#' @export
#'
check_nchangepoints <- function(nchangepoints){
  if (!is.numeric(nchangepoints) || any(nchangepoints %% 1 != 0)){
    stop("nchangepoints must be integer-valued")
  }
  if (any(nchangepoints < 0)){
    stop("nchangepoints must be non-negative")
  }
  return()
}

#' @title Check that weights vector is proper
#' 
#' @description Check that the vector of document weights is numeric and 
#'   positive and inform the user if the average weight isn't 1. 
#'   
#' @param weights Vector of the document weights to evaluate, or \code{TRUE}
#'   for triggering internal weighting by document sizes.
#' 
#' @return An error message is thrown if \code{weights} is not proper,
#'   else \code{NULL}.
#' 
#' @examples
#'   check_weights(1)
#'   wts <- runif(100, 0.1, 100)
#'   check_weights(wts)
#'   wts2 <- wts / mean(wts)
#'   check_weights(wts2)
#'   check_weights(TRUE)
#' 
#' @export
#'
check_weights <- function(weights){
  if(is.logical(weights)){
    if(weights){
      return()
    } else{
      stop("if logical, weights need to be TRUE")
    }   
  }
  if(!is.null(weights)){
    if (!is.numeric(weights)){
      stop("weights vector must be numeric")
    }
    if (any(weights <= 0)){
      stop("weights must be positive")
    }
    if (round(mean(weights)) != 1){
      warning("weights should have a mean of 1, fit may be unstable")
    }
  }
  return()
}

#' @title Check that LDA model input is proper
#' 
#' @description Check that the \code{LDA_models} input is either a set of 
#'   LDA models (class \code{LDA_set}, produced by
#'   \code{\link{LDA_set}}) or a singular LDA model (class \code{LDA},
#'   produced by \code{\link[topicmodels]{LDA}}). 
#'   
#' @param LDA_models List of LDA models or singular LDA model to evaluate.
#' 
#' @return An error message is thrown if \code{LDA_models} is not proper,
#'   else \code{NULL}.
#'
#' @examples
#'   data(rodents)
#'   document_term_table <- rodents$document_term_table
#'   document_covariate_table <- rodents$document_covariate_table
#'   LDAs <- LDA_set(document_term_table, topics = 2, nseeds = 1)
#'   LDA_models <- select_LDA(LDAs)
#'   check_LDA_models(LDA_models)
#'
#' @export
#'
check_LDA_models <- function(LDA_models){
  if(("LDA_set" %in% class(LDA_models)) == FALSE){
    if(is(LDA_models, "LDA") == FALSE){
      stop("LDA_models is not an LDA object or LDA_set object")
    }
  }
  return()
}

#' @title Check that the document covariate table is proper
#' 
#' @description Check that the table of document-level covariates is 
#'   conformable to a data frame and of the right size (correct number of 
#'   documents) for the document-topic output from the LDA models.
#'   
#' @param document_covariate_table Document covariate table to evaluate.
#'
#' @param LDA_models Reference LDA model list (class \code{LDA_set}) that 
#'   includes as its first element a properly fitted \code{LDA} model with 
#'   a \code{gamma} slot with the document-topic distribution. 
#' 
#' @param document_term_table Optional input for checking when
#'   \code{LDA_models} is \code{NULL}
#' 
#' @return An error message is thrown if \code{document_covariate_table} is 
#'   not proper, else \code{NULL}.
#'
#' @examples
#'   data(rodents)
#'   check_document_covariate_table(rodents$document_covariate_table)
#'
#' @export
#'
check_document_covariate_table <- function(document_covariate_table, 
                                           LDA_models = NULL,
                                           document_term_table = NULL){
  dct_df <- tryCatch(data.frame(document_covariate_table),
                     warning = function(x){NA}, error = function(x){NA})
  if(is(LDA_models, "LDA")){
    LDA_models <- c(LDA_models)
    class(LDA_models) <- c("LDA_set", "list")
  }
  if (length(dct_df) == 1 && is.na(dct_df)){
    stop("document_covariate_table is not conformable to a data frame")
  }
  if (!is.null(LDA_models)){
    if (nrow(data.frame(document_covariate_table)) != 
        nrow(LDA_models[[1]]@gamma)){
      stop("number of documents in covariate table is not equal to number of 
        documents observed")
    }
  } else if (!is.null(document_term_table)){
    if (nrow(data.frame(document_covariate_table)) != 
        nrow(data.frame(document_term_table))){
      stop("number of documents in covariate table is not equal to number of 
        documents observed")
    }
  }
  return()
}

#' @title Check that the time vector is proper
#' 
#' @description Check that the vector of time values is included in the 
#'   document covariate table and that it is either a integer-conformable or
#'   a \code{date}. If it is a \code{date}, the input is converted to an 
#'   integer, resulting in the timestep being 1 day, which is often not 
#'   desired behavior. 
#'   
#' @param document_covariate_table Document covariate table used to query
#'   for the time column.
#'
#' @param timename Column name for the time variable to evaluate.
#' 
#' @return An error message is thrown if \code{timename} is 
#'   not proper, else \code{NULL}.
#'
#' @examples
#'   data(rodents)
#'   check_timename(rodents$document_covariate_table, "newmoon")
#'
#' @export
#'
check_timename <- function(document_covariate_table, timename){
  if (!("character" %in% class(timename))){
    stop("timename is not a character value")
  }
  if (length(timename) > 1){
    stop("timename can only be one value")
  }
  covariate_names <- colnames(document_covariate_table)
  if ((timename %in% covariate_names) == FALSE){
    stop("timename not present in document covariate table")
  }
  time_covariate <- document_covariate_table[ , timename]
  if (!(is.Date(time_covariate)) & 
      (!is.numeric(time_covariate) || !all(time_covariate %% 1 == 0))){
    stop("covariate indicated by timename is not an integer or a date")
  }
  return()
}

#' @title Check that formulas vector is proper and append the response 
#'   variable
#' 
#' @description Check that the vector of formulas is actually formatted
#'   as a vector of \code{\link[stats]{formula}} objects and that the 
#'   predictor variables are all included in the document covariate table. 
#'   
#' @param formulas Vector of the formulas to evaluate.
#'
#' @param document_covariate_table Document covariate table used to evaluate
#'   the availability of the data required by the formula inputs.
#'
#' @param control A \code{list} of parameters to control the fitting of the
#'   Time Series model including the parallel tempering Markov Chain 
#'   Monte Carlo (ptMCMC) controls. Values not input assume defaults set by 
#'   \code{\link{TS_control}}.
#' 
#' @return An error message is thrown if \code{formulas} is 
#'   not proper, else \code{NULL}.
#' 
#' @examples
#'   data(rodents)
#'   check_formulas(~ 1, rodents$document_covariate_table)
#'
#' @export
#'
check_formulas <- function(formulas, document_covariate_table, 
                           control = list()){
  check_document_covariate_table(document_covariate_table)
  check_control(control)
  control <- do.call("TS_control", control)
  # response <- control$response
  dct <- document_covariate_table
  if (!is(formulas, "list")) {
    if (is(formulas, "formula")) {
      formulas <- c(formulas)
    } else{
      stop("formulas does not contain formula(s)")
    }
  } else if (!all(vapply(formulas, is, TRUE, "formula"))) {
      stop("formulas does not contain all formula(s)")
  }
  resp <- unlist(lapply(lapply(formulas, terms), attr, "response"))
  pred <- unlist(lapply(lapply(formulas, terms), attr, "term.labels"))
  if (any(resp != 0)) {
    stop("formula inputs should not include response variable")
  }
  if (!all(pred %in% colnames(dct))) {
    misses <- pred[which(pred %in% colnames(dct) == FALSE)]
    mis <- paste(misses, collapse = ", ")
    stop(paste0("formulas include predictors not present in data: ", mis))
  }
  return()
}

#' @rdname TS_on_LDA
#'
#' @export
#'
check_TS_on_LDA_inputs <- function(LDA_models, document_covariate_table, 
                            formulas = ~ 1, nchangepoints = 0,  
                            timename = "time", weights = NULL,
                            control = list()){
  check_LDA_models(LDA_models)
  check_document_covariate_table(document_covariate_table, LDA_models)
  check_timename(document_covariate_table, timename)
  check_formulas(formulas, document_covariate_table, control)  
  check_nchangepoints(nchangepoints)
  check_weights(weights)
  check_control(control)
}
