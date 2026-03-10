#resnew <- readRDS("../../results/cftest_repl100.rds")
#resold <- readRDS("results_cf_old.rds")
#res <- merge(resold, resnew, by = c("seed", "dim", "algorithm", "ol"))
#saveRDS(res, file = "comparison_res.rds")

res <- readRDS("comparison_res.rds")

pdf("comparisonplot.pdf", width = 5, height = 4)
plot(res$value, res$result.res, xlab = "old", ylab = "new")
abline(0, 1)
dev.off()




berlinres <- readRDS("../../results/other_methods.rds")
berlinres <- berlinres[berlinres$algorithm == "cf", ]
names(berlinres)[ncol(berlinres)] <- "result.res.berlin"

compseed <- berlinres$seed[which(berlinres$seed %in% res$seed)]
compres <- merge(res[res$seed %in% compseed,], berlinres, by = c("seed", "algorithm"), all.x = TRUE)

pdf("comparisonplot_berlin.pdf", width = 5, height = 4)
plot(compres$result.res, compres$result.res.berlin, xlab = "old", ylab = "new berlin")
abline(0, 1)
dev.off()

which(compres$result.res == compres$results.res.berlin)

# no clear differences!!
pdf("comparisonplot_berlin_all.pdf", width = 10, height = 4)
par(mfrow = c(1,2))
boxplot(res$result.res[res$setup.x == "A"], ylim = c(0, 0.5), main = "Setup A, old")
boxplot(berlinres$result.res.berlin[berlinres$setup == 1], ylim = c(0, 0.5), main = "Setup A, new berlin")
dev.off()

