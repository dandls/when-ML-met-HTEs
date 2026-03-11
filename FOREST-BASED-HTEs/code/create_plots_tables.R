#### Plot results #####
BERLINRESULTS <- TRUE

if (BERLINRESULTS) {
  dml_study_name <- "doubleml"
  other_study_name <-  "other_methods"
} else {
  resnam <- "all_berlinsettings"
  # resnam <- "all_repl40"
}

res.folder <- "../results"
methodnams <- c("mob", "equalized", "mobcf",
  "cf", "doubleml")

#---- Load data ----
if (BERLINRESULTS) {
  dml_df <- readRDS(file.path(res.folder, paste0(dml_study_name,".rds")))#[1:32,]
  other_df <- readRDS(file.path(res.folder, paste0(other_study_name,".rds")))#[1:320,]
  resall <-  rbind(dml_df, other_df)
} else {
  resall <- readRDS(file.path(res.folder, paste0(resnam,".rds")))
}

methodnams <- methodnams[methodnams %in% unique(resall$algorithm)]

source("def.R") # TODO: here you should specify "study_name
source("setup.R")

#---- Setup by Nie and Wager (2020) ----
res <- resall[resall$setup %in% 1:4,]
HONESTY <- FALSE # set to TRUE to show also the results for honest forests
source("helpers.R")

plot_results(normalB, scB, ylim = c(-.1, 1.1), cexstrip = 1)


### SAVE PLOT (directly from R plot part)

plot_name <- "results_berlinsettings_subsetted"
# Specify the file name and dimensions
# dir.create("plots", showWarnings = FALSE)
png(file.path("../plots", paste0(plot_name,".png")), width = 650, height = 600)
plot_results(normalB, scB, ylim = c(-.1, 50), cexstrip = 1)
dev.off()

### Compare results for cfs 
other_df <- readRDS(file.path(res.folder, paste0( "other_methods",".rds")))
resall <- readRDS(file.path(res.folder, paste0("all_berlinsettings",".rds")))

resall_cf <- resall[resall$algorithm == "cf",]
other_sub_cf <- other_df[other_df$algorithm == "cf" & other_df$setup %in% c(1, 3) & 
         other_df$seed %in% resall$seed,]

cf_results_compared <- merge(resall_cf, other_sub_cf, by = "seed")

png(file.path("../plots", paste0("overlapping_calls", ".png")), width = 500, height = 400)
plot(cf_results_compared$result.res.x, cf_results_compared$result.res.y, 
     xlab = c("rerun"), ylab = "berlin run")
abline(0, 1)
dev.off()

#---- Results table ----
# lev <- c("pF_eta_x1_x2.mF_sin_x1_x5.tF_div_x1_x2" = "Setup A",
#   "0.5.mF_max_x1_x5.tF_log_x1_x2" = "Setup B",
#   "pF_x2_x3.mF_log_x1_x3.1" = "Setup C",
#   "pF_exp_x1_x2.mF_max2_x1_x5.tF_max_x1_x5" = "Setup D")
#
# create_table(dataA = normalB, dataB = NULL, lev, lev)
