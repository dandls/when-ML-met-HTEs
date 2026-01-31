dfo <- readRDS("~/Documents/Hiwi/blood_loss_paper/paper1/results/other_methods.rds")
dfo <- dfo %>% dplyr::filter(algorithm != "doubleml")
saveRDS(dfo, file = "~/Documents/Hiwi/blood_loss_paper/paper1/results/other_methods.rds")


dfml <- readRDS("~/Documents/Hiwi/blood_loss_paper/paper1/results/test.rds")
dfml <- dfml %>% dplyr::filter(algorithm == "doubleml")
saveRDS(dfml, file = "~/Documents/Hiwi/blood_loss_paper/paper1/results/doubleml.rds")


head(dfo)

df <- rbind(dfo, dfml)
