### number of trees in forest (grf default)
#NumTrees <- 500
min_size_group <- 7L
min_node_size <- min_size_group*2L
### for splitting, no early stopping, large trees
ctrl <- ctree_control(testtype = "Univ", minsplit = 2,
  minbucket = 2, splittry = 20, minprob = 0, mincriterion = 0,
  lookahead = TRUE, saveinfo = FALSE)
ctrl$converged = function(mod, data, subset) {
  # The following should be added to avoid nodes with only treated or control samples
  if (length(unique(data$trt[subset])) == 1) return(FALSE)
  ### W - W.hat is not a factor
  if (!is.factor(data$trt)) {
    return(all(table(data$trt[subset] > 0) >= min_size_group))
  } else {
    ### at least min_size_group obs in both treatment arms
    return(all(table(data$trt[subset]) >= min_size_group))
  }
}

prt <- list(replace = FALSE, fraction = .5)
prt_honest <- list(replace = FALSE, fraction = c(0.25, 0.25))

run <- function(
  ### data (with benefits, such as the ground truth)
  d,
  ### fit propensities only when e != .5
  propensities = !identical(unique(predict(d, newdata = d)[, "pfct"]),
    .5),
  marginal_mean = FALSE,
  prognostic_effect = TRUE,
  ### use grf::causal_forest
  causal_forest = FALSE,
  ### use Weibull models for Weibull DGP by default
  Cox = FALSE,
  ### calculate honest trees
  honesty = FALSE,
  ### see progress bar
  TRACE = TRUE,
  ### return object not MSE
  object = FALSE,
  ### stabilize splits in grf::causal_forests
  stabilize.splits = TRUE,
  ### return ATE (trt effect of base model)
  ATE = FALSE,
  ...
) {

  seed <- attributes(d)$runseed

  ### set and re-set seed
  if (!exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
    runif(1)
  if (is.null(seed))
    RNGstate <- get(".Random.seed", envir = .GlobalEnv)
  else {
    R.seed <- get(".Random.seed", envir = .GlobalEnv)
    set.seed(seed)
    RNGstate <- structure(seed, kind = as.list(RNGkind()))
    on.exit(assign(".Random.seed", R.seed, envir = .GlobalEnv))
  }

  # type <- match.arg(type)
  if (causal_forest) stopifnot(attributes(d)$truth$mod %in% c("normal", "weibull")) # SD

  ### standard choice in grf
  mtry <- min(floor(sqrt(ncol(d) - 2) + 20), ncol(d) - 2)

  if (!causal_forest & honesty) {
    perturb <- prt_honest
  } else {
    perturb <- prt
  }

  ### update splittry
  ctrl$splittry <- ncol(d[, grep("^X", colnames(d))])

  ### initialize
  offset <- NULL
  y.hat <- NULL
  fixed <- NULL
  nm <- nmt <- "trt1"

  ### replace treatment indicator by in randomized trial
  W.hat <- if (identical(unique(predict(d, newdata = d)[, "pfct"]), .5)) .5 else NULL
  trt <- d$trt

  if ((causal_forest && !prognostic_effect) | propensities | marginal_mean) {
    ### call causal_forest to compute W.hat and Y.hat
    ### make sure all forests center in the same way
      cf <- causal_forest(X = as.matrix(d[, grep("^X", colnames(d))]),
        Y = d$y, W = (0:1)[d$trt], W.hat = W.hat, # W.hat = W.hat if necessary!
        stabilize.splits = stabilize.splits,
        min.node.size = min_size_group, sample.fraction = prt$fraction,
        mtry = mtry,
        num.trees = NumTrees, honesty = honesty, num.threads = 32L)
      myW.hat <- cf$W.hat
      myY.hat <- cf$Y.hat
  } else if (causal_forest && prognostic_effect) {
    cf <- multi_arm_causal_forest(X = as.matrix(d[, grep("^X", colnames(d))]),
      Y = d$y, W = d$trt, W.hat = W.hat, split.on.intercept = TRUE,
      stabilize.splits = stabilize.splits,
      min.node.size = min_size_group, sample.fraction = prt$fraction,
      mtry = mtry,
      num.trees = NumTrees, honesty = honesty, num.threads = 32L)
  }

  if (propensities & !causal_forest) {
    ### use W.hat of causal forest to center trt
    W.hat <- myW.hat
    d$trt <- (0:1)[d$trt] - W.hat
    ### this is the name of the parameter we care for
    nm <- nmt <- "trt"
  }

  ### estimate marginal mean E(Y|X = x)
  if (marginal_mean & !causal_forest) {
    ### use Y.hat of causal forest to center y
    Y.hat <- myY.hat
    d$y <- d$y - Y.hat
  }

  ### ground truth
  testxdf <- attributes(d)$testxdf
  tau <- predict(d, newdata = testxdf)

  ### Setup up models according to the underlying model
  ### normally distributed response
    if (causal_forest) {
      ret <- predict(cf,
        newdat = testxdf[grep("^X", colnames(testxdf))])$predictions
      return(mean((tau[, "tfct"] - ret)^2))
    } else {
      ### set-up linear model
      if (!prognostic_effect) {
        if (!propensities) {
          d$trt <- (0:1)[d$trt]
        }
        m <- lm(y ~ trt, data = d)
        class(m) <- c("nomu", class(m))
      } else {
        m <- lm(y ~ trt, data = d)
      }
    }


  ### fit forest and partition wrt to BOTH intercept and treatment effect
    rf <- model4you::pmforest(m, data = d, ntree = NumTrees, perturb = perturb,
      mtry = mtry, control = ctrl, trace = TRACE)

  if (object) return(rf)

  ### estimate model coefficients on test set

  cf <- model4you::pmodel(rf, newdata = testxdf)
  mod <- attributes(d)$truth$mod
  if (prognostic_effect) {
    ret <- cf[, nmt]
  } else {
    ret <- c(cf)
  }
  mse <- mean((tau[, "tfct"] - ret)^2)
  return(mse)
}

coef.nomu <- function(object, ...) {
  class(object) <- class(object)[-1L]
  coef(object)["trt"]
}

estfun.nomu <- function(object, ...) {
  class(object) <- class(object)[-1L]
  ef <- tryCatch({estfun(object)[,"trt", drop = FALSE]},
    error = function(e) {
      return(rep(0, length(object$model$y)))
    })
  return(ef)
}

update.nomu <- function(object, ...) {
  class(object) <- class(object)[-1L]
  ret <- update(object, ...)
  class(ret) <- c("nomu", class(ret))
  ret
}


# Specify functions for batchtools

fun.cf <- function(instance, ...) {
  run(instance, causal_forest = TRUE,
    prognostic_effect = FALSE, honesty = FALSE)
}

fun.cfhonest <- function(instance, ...) {
  run(instance, causal_forest = TRUE,
    prognostic_effect = FALSE, honesty = TRUE)
}

fun.cfmob <- function(instance, ...) {
  run(instance, causal_forest = TRUE, propensities = FALSE,
    prognostic_effect = TRUE, honesty = FALSE)
}

fun.cfmobhonest <- function(instance, ...) {
  run(instance, causal_forest = TRUE, propensities = FALSE,
    prognostic_effect = TRUE, honesty = TRUE)
}

fun.mob <- function(instance, ...) {
  mob <- run(instance, propensities = FALSE, causal_forest = FALSE,
    honesty = FALSE, ...)
  return(mob)
}

fun.mobhonest <- function(instance, ...) {
  mob <- run(instance, propensities = FALSE,
    causal_forest = FALSE, honesty = TRUE, ...)
  return(mob)
}

fun.hybrid <- function(instance, ...) {
  mob <- run(instance, propensities = TRUE, causal_forest = FALSE,
    honesty = FALSE, ...)
  return(mob)
}

fun.hybridhonest <- function(instance, ...) {
  mob <- run(instance,  propensities = TRUE, causal_forest = FALSE,
      honesty = TRUE, ...)
  return(mob)
}

fun.equalized <- function(instance, ...) {
  mob <- run(instance, propensities = TRUE, marginal_mean = TRUE,
    causal_forest = FALSE, honesty = FALSE, ...)
  return(mob)
}


fun.equalizedhonest <- function(instance, ...) {
  mob <- run(instance, propensities = TRUE, marginal_mean = TRUE,
    causal_forest = FALSE, honesty = TRUE, ...)
  return(mob)
}

fun.mobcf <- function(instance, ...) {
    mob <- run(instance, propensities = TRUE, marginal_mean = TRUE,
      prognostic_effect = FALSE, causal_forest = FALSE, honesty = FALSE,
     ...)
    return(mob)
  }


fun.mobcfhonest <- function(instance, ...) {
  mob <- run(instance, propensities = TRUE, marginal_mean = TRUE,
    prognostic_effect = FALSE, causal_forest = FALSE, honesty = TRUE,
   ...)
  return(mob)
}

# Average Treatment Effect Methods: get coef from base model
# original treatment indicator
fun.bm <- function(instance, ...) {
 run(instance, propensities = FALSE, causal_forest = FALSE,
    honesty = FALSE, ATE = TRUE, ...)
}

# orthogonalized treatment indicator
fun.bmhybrid <-  function(instance, ...) {
  run(instance, propensities = TRUE, causal_forest = FALSE,
  honesty = FALSE, ATE = TRUE, ...)
}

# DOUBLE ML
library(DoubleML)
library(mlr3)




fun.doubleml <- function(job, data, instance, ...) {
  fun.doubleml_hte(instance, ...)
}

fun.doubleml_hte <- function(instance,
                             learner_outcome = mlr3::lrn("regr.ranger", num.trees = NumTrees, min.node.size = 5),
                             learner_prop    = mlr3::lrn("classif.ranger", num.trees = NumTrees, min.node.size = 5, predict_type = "prob"),
                             learner_tau     = mlr3::lrn("regr.ranger", num.trees = NumTrees, min.node.size = 5),
                             n_folds = 5,
                             prop_clip = 1e-3,
                             ...) {
  # Extract training data
  X <- as.data.frame(instance[, grep("^X", names(instance))])
  y <- instance$y
  d <- as.numeric(as.character(instance$trt))
  n <- nrow(X)

  folds <- sample(rep(1:n_folds, length.out = n))

  # Cross-fitted nuisance predictions
  m1_hat <- m0_hat <- e_hat <- numeric(n)

  # n_folds CROSS-VALIDATION
  for (k in 1:n_folds) {
    idx_tr <- which(folds != k)
    idx_te <- which(folds == k)

    # Training split
    Xtr <- X[idx_tr, , drop = FALSE]
    ytr <- y[idx_tr]
    dtr <- d[idx_tr]

    # Outcome regressions
    task_m1 <- mlr3::TaskRegr$new("m1", backend = data.frame(y = ytr[dtr==1], Xtr[dtr==1,]), target = "y")
    task_m0 <- mlr3::TaskRegr$new("m0", backend = data.frame(y = ytr[dtr==0], Xtr[dtr==0,]), target = "y")

    fit_m1 <- learner_outcome$clone()$train(task_m1)
    fit_m0 <- learner_outcome$clone()$train(task_m0)

    m1_hat[idx_te] <- fit_m1$predict_newdata(X[idx_te, ])$response
    m0_hat[idx_te] <- fit_m0$predict_newdata(X[idx_te, ])$response

    # Propensity score
    task_e <- mlr3::TaskClassif$new("e", backend = data.frame(trt = factor(dtr), Xtr), target = "trt")
    fit_e <- learner_prop$clone()$train(task_e)
    e_hat[idx_te] <- fit_e$predict_newdata(X[idx_te, ])$prob[, "1"]
  }

  # Clip propensity scores
  e_hat <- pmin(pmax(e_hat, prop_clip), 1 - prop_clip)

  # DR pseudo-outcome
  pseudo <- m1_hat - m0_hat +
    d * (y - m1_hat) / e_hat -
    (1 - d) * (y - m0_hat) / (1 - e_hat)

  # Optional weights
  w <- e_hat * (1 - e_hat)

  # --- Second-stage regression: create Task with a weights column and assign role ---
  df_tau <- data.frame(pseudo = pseudo, X, stringsAsFactors = FALSE)
  # add weights column (name "weights" matches examples in mlr3 book)
  df_tau$weights <- w

  task_tau <- mlr3::TaskRegr$new("tau", backend = df_tau, target = "pseudo")

  # Assign the weights column the learner-weights role; fallback if set_col_roles not available
  tryCatch({
    # preferred API
    task_tau$set_col_roles("weights", roles = "weights_learner")
  }, error = function(e) {
    # fallback: manipulate col_roles list directly (older/newer mlr3 compat)
    task_tau$col_roles$weights_learner <- "weights"
  })

  # Train without passing row_weights (mlr3 will pick up weights from task if learner supports it)
  fit_tau <- learner_tau$clone()$train(task_tau)

  # Predict HTEs on test set
  testxdf <- attributes(instance)$testxdf
  Xtest <- as.data.frame(testxdf[, grep("^X", names(testxdf))])
  tau_hat <- fit_tau$predict_newdata(Xtest)$response

  # Ground truth (if available in simulation)
  tau_true <- predict(instance, newdata = testxdf)[, "tfct"]

  # MSE
  mse <- mean((tau_true - tau_hat)^2)

  return(mse)

  # return(list(
  #   tau_hat = tau_hat,
  #   tau_true = tau_true,
  #   mse = mse,
  #   model = fit_tau
  # ))
}


fun.doubleml_ate <- function(instance, learner = "mlr3::lrn('regr.ranger')", ...) {
  # Extract X, y, treatment
  X <- as.data.frame(instance[, grep("^X", names(instance))])
  y <- instance$y
  d <- as.numeric(as.character(instance$trt))  # convert factor 0/1

  # Create DoubleMLData object
  dml_data <- DoubleMLData$new(data = cbind(X, y = y, d = d),
                               y_col = "y",
                               d_cols = "d")

  # Define learners for nuisance functions
  lml <- mlr3::lrn("regr.ranger", num.trees = 500, min.node.size = 5)
  gml <- mlr3::lrn("classif.ranger", num.trees = 500, min.node.size = 5, predict_type = "prob")

  # Initialize DoubleMLPLR (partially linear regression)
  dml_model <- DoubleMLPLR$new(dml_data, ml_g = lml, ml_m = gml, n_folds = 5)

  # Fit the model
  dml_model$fit()

  # Predict treatment effects on test set
  testxdf <- attributes(instance)$testxdf
  Xtest <- as.data.frame(testxdf[, grep("^X", names(testxdf))])
  dtest <- as.numeric(as.character(testxdf$trt))
  ytest <- testxdf$y

  # DoubleML does not directly return ITEs, but ATE and model object.
  # For evaluation, we compare ATE to ground truth tau.
  tau_true <- predict(instance, newdata = testxdf)[, "tfct"]
  tau_hat <- rep(dml_model$coef, length(tau_true))  # constant ATE

  # Return MSE between estimated ATE and ground truth treatment effect
  mse <- mean((tau_true - tau_hat)^2)
  return(mse)
}
