#' Dotplot of Potential Scale Reduction Factor (Rhat)
#'
#' Plot a dotplot of Potential Scale Reduction Factor (Rhat), proposed by Gelman and Rubin (1992). The version from the second edition of Bayesian Data Analysis (Gelman, Carlin, Stein and Rubin) is used.
#'
#' Notice that at least two chains are required.
#'
#' @references Fernández-i-Marín, Xavier (2016) ggmcmc: Analysis of MCMC Samples and Bayesian Inference. Journal of Statistical Software, 70(9), 1-20. doi:10.18637/jss.v070.i09
#' @references Gelman, Carlin, Stern and Rubin (2003) Bayesian Data Analysis. 2nd edition. Chapman & Hall/CRC, Boca Raton.
#' @references Gelman, A and Rubin, DB (1992) Inference from iterative simulation using multiple sequences, _Statistical Science_, *7*, 457-511.
#' @param D Data frame whith the simulations
#' @param family Name of the family of parameters to plot, as given by a character vector or a regular expression. A family of parameters is considered to be any group of parameters with the same name but different numerical value between square brackets (as beta[1], beta[2], etc).
#' @param scaling Value of the upper limit for the x-axis. By default, it is 1.5, to help contextualization of the convergence. When 0 or NA, the axis are not scaled.
#' @param greek Logical value indicating whether parameter labels have to be parsed to get Greek letters. Defaults to false.
#' @return A \code{ggplot} object.
#' @export
#' @examples
#' data(linear)
#' ggs_Rhat(ggs(s))
ggs_Rhat <- function(D, family=NA, scaling=1.5, greek=FALSE) {
  if (attributes(D)$nChains<2) {
    stop("At least two chains are required")
  }
  # Manage subsetting a family of parameters
  if (!is.na(family)) {
    D <- get_family(D, family=family)
  }
  # The computations follow BDA, pg 296-297, and the notation tries to be
  # consistent with it
  # Compute between-sequence variance using psi.. and psi.j
  psi.dot <- D %>%
    dplyr::group_by(Parameter, Chain) %>%
    dplyr::summarize(psi.dot=mean(value))
  psi.j <- D %>%
    dplyr::group_by(Parameter) %>%
    dplyr::summarize(psi.j=mean(value))
  b.df <- dplyr::inner_join(psi.dot, psi.j, by="Parameter")
  B <- b.df %>%
    dplyr::group_by(Parameter) %>%
    dplyr::summarize(B=var(psi.j-psi.dot)*attributes(D)$nIterations)
  B <- unique(B)
  # Compute within-sequence variance using s2j
  s2j <- D %>%
    dplyr::group_by(Parameter, Chain) %>%
    dplyr::summarize(s2j=var(value))
  W <- s2j %>%
    dplyr::group_by(Parameter) %>%
    dplyr::summarize(W=mean(s2j))
  # Merge BW and compute the weighted average (wa, var.hat+) and the Rhat
  BW <- dplyr::inner_join(B, W, by="Parameter") %>%
    dplyr::mutate(
      wa= (((attributes(D)$nIterations-1)/attributes(D)$nIterations )* W) +
        ((1/ attributes(D)$nIterations)*B),
      Rhat=sqrt(wa/W))
  # For parameters that do not vary, Rhat is Nan. Move it to NA
  BW$Rhat[is.nan(BW$Rhat)] <- NA
  # Plot
  f <- ggplot(BW, aes(x=Rhat, y=Parameter)) + geom_point() +
    xlab(expression(hat("R"))) + ggtitle("Potential Scale Reduction Factors")
  if (greek) {
    f <- f + scale_y_discrete(labels = parse(text = as.character(BW$Parameter)))
  }
  # If scaling, add the scale
  if (!is.na(scaling)) {
    # Use the maximum of Rhat if it is larger than the prespecified value
    scaling <- ifelse(scaling > max(BW$Rhat, na.rm=TRUE), scaling, max(BW$Rhat, na.rm=TRUE))
    f <- f + xlim(min(BW$Rhat, na.rm=TRUE), scaling)
  }
  return(f)
}
