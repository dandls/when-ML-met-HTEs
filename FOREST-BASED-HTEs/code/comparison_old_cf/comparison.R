#resnew <- readRDS("../../results/cftest_repl100.rds")
#resold <- readRDS("results_cf_old.rds")
#res <- merge(resold, resnew, by = c("seed", "dim", "algorithm", "ol"))
#saveRDS(res, file = "comparison_res.rds")

res <- readRDS("comparison_res.rds")

pdf("comparisonplot.pdf", width = 4, height = 4)
plot(res$value, res$result.res, xlab = "old", ylab = "new")
abline(0, 1)
dev.off()