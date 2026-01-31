#### Plot results #####

dml_study_name <- "doubleml"
other_study_name <-  "other_methods"
res.folder <- "results"
source("def.R") # TODO: here you should specify "study_name
source("setup.R")

#---- Load data ----
res.folder = "results"
dml_df <- readRDS(file.path(res.folder, paste0(dml_study_name,".rds")))
other_df <- readRDS(file.path(res.folder, paste0(other_study_name,".rds")))
resall <-  rbind(dml_df, other_df)

#---- Setup by Nie and Wager (2020) ----
res <- resall[resall$setup %in% 1:4,]
HONESTY <- FALSE # set to TRUE to show also the results for honest forests
source("helpers.R")

plot_results(normalB, scB, ylim = c(-.1, 1.61), cexstrip = 1)


### SAVE PLOT (directly from R plot part)

# plot_name <- "name"
# # Specify the file name and dimensions
# dir.create("plots", showWarnings = FALSE)
# png(file.path("plots", paste0(plot_name,".png")), width = 800, height = 600)
# plot_results(normalB, scB, ylim = c(-.1, 1.61), cexstrip = 1)
# dev.off()

#---- Results table ----
# lev <- c("pF_eta_x1_x2.mF_sin_x1_x5.tF_div_x1_x2" = "Setup A",
#   "0.5.mF_max_x1_x5.tF_log_x1_x2" = "Setup B",
#   "pF_x2_x3.mF_log_x1_x3.1" = "Setup C",
#   "pF_exp_x1_x2.mF_max2_x1_x5.tF_max_x1_x5" = "Setup D")
#
# create_table(dataA = normalB, dataB = NULL, lev, lev)
