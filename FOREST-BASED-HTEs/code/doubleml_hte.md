# DoubleML HTE Estimation Issues


**IMPORTANT CLARIFICATION:** There are TWO different functions in the code `run.R`:

1. **`fun.doubleml_hte()` (lines 286-379)**: ✓ **CORRECTLY** implements HTE estimation using DR-learner
2. For purely exploratory work, the function **`fun.doubleml_ate()` (lines 382-417)**: ✗ **CRUDELY** compares ATE to HTEs


## `fun.doubleml_hte()`

This function implements a **DR-learner (Doubly Robust Learner)** approach:

```r
# Step 1: Cross-fitted nuisance estimation (lines 304-328)
for (k in 1:n_folds) {
  # Fit E[Y|X,D=1] and E[Y|X,D=0]
  fit_m1 <- learner_outcome$clone()$train(task_m1)
  fit_m0 <- learner_outcome$clone()$train(task_m0)
  
  # Fit propensity score e(X) = P(D=1|X)
  fit_e <- learner_prop$clone()$train(task_e)
}

# Step 2: Create DR pseudo-outcome (lines 333-336)
pseudo <- m1_hat - m0_hat + 
  d * (y - m1_hat) / e_hat - 
  (1 - d) * (y - m0_hat) / (1 - e_hat)

# Step 3: Regress pseudo-outcome on X to learn τ(X) (line 358)
fit_tau <- learner_tau$clone()$train(task_tau)

# Step 4: Predict individual treatment effects (line 363)
tau_hat <- fit_tau$predict_newdata(Xtest)$response  # ✓ Individual predictions!

# Step 5: Compare to true individual effects (lines 366-369)
tau_true <- predict(instance, newdata = testxdf)[, "tfct"]
mse <- mean((tau_true - tau_hat)^2)
```

### Why this hopefully works

The DR-learner:
- Creates a pseudo-outcome that, when regressed on X, estimates τ(X)
- Actually learns heterogeneous effects as a function of covariates
- Returns **individual-level predictions** that vary across observations
- Is a well-established method for CATE estimation

## True Treatment Effects (Line 411)

```r
tau_true <- predict(instance, newdata = testxdf)[, "tfct"]
```

### What `instance` Is
- `instance` is a data generating process (DGP) object from the `htesim` package
- It was created with specific functions for:
  - `t = tF_div_x1_x2` (treatment effect function)
  - `m = mF_sin_x1_x5` (main effect function)
  - `p = pF_eta_x1_x2` (propensity function)

### What `predict(instance, newdata)` returns
The predict method on a DGP object returns the **true underlying functions** evaluated at new data points, including:
- `"tfct"`: The true treatment effect τ(X) for each individual
- `"pfct"`: The true propensity score
- `"mfct"`: The true main effect

### Evidence from DGP.R
```r
# Setup A example:
htesim::dgp(p = pF_eta_x1_x2, m = mF_sin_x1_x5, t = tF_div_x1_x2, ...)
```

The `t` parameter defines the true heterogeneous treatment effect function. When you call `predict()` with `[, "tfct"]`, you get the true τ(Xi) values.


## Why the basic DoubleML library can't estimate HTEs

### The Fundamental Issue
Standard DoubleML with Partially Linear Regression (PLR) assumes:
- A linear model: Y = θ·D + g(X) + ε
- **θ is constant** across all individuals
- Only g(X) varies with covariates

### To Estimate HTEs with DoubleML
You would need:
1. Use `DoubleMLIRM` (Interactive Regression Model) instead of `DoubleMLPLR`
2. Or implement a CATE (Conditional Average Treatment Effect) estimator
3. Or use a modified approach that allows treatment-covariate interactions

