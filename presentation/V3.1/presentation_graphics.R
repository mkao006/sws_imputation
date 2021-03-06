library(earth)
library(forecast)
library(FAOSTAT)
library(lattice)
library(lme4)
library(data.table)
library(splines)
## source("../../support_functions/ensembleImpute.R")
source("../../support_functions/computeYield.R")
dataPath = "../../sua_data/"
dataFile = dir(dataPath)

## dataFile = dataFile[1:10]
## NOTE (Michael): Need to check how we are going to handle
##                 unimputed value with SWS.
##
## NOTE (Michael): Try to implement wavelet decomposition oppose to
##                 spline decomposition.



grape.dt = data.table(read.csv(paste0(dataPath, "grapesSUA.csv"),
    stringsAsFactors = FALSE))

## append regional and country information
regionTable.dt =
    data.table(FAOregionProfile[!is.na(FAOregionProfile$FAOST_CODE),
                                c("FAOST_CODE", "UNSD_SUB_REG",
                                  "UNSD_MACRO_REG")])
setnames(regionTable.dt,
         old = c("FAOST_CODE", "UNSD_SUB_REG", "UNSD_MACRO_REG"),
         new = c("areaCode", "unsdSubReg", "unsdMacroReg"))
countryNameTable.dt =
    data.table(FAOcountryProfile[!is.na(FAOcountryProfile$FAOST_CODE),
                                 c("FAOST_CODE", "ABBR_FAO_NAME")])
countryNameTable.dt[FAOST_CODE == 357,
                    ABBR_FAO_NAME := "Taiwan and China"]
countryNameTable.dt[FAOST_CODE == 107, ABBR_FAO_NAME := "Cote d'Ivoire"]
countryNameTable.dt[FAOST_CODE == 284, ABBR_FAO_NAME := "Aland Islands"]
countryNameTable.dt[FAOST_CODE == 279, ABBR_FAO_NAME := "Curacao"]
countryNameTable.dt[FAOST_CODE == 182, ABBR_FAO_NAME := "Reunion"]
countryNameTable.dt[FAOST_CODE == 282,
                    ABBR_FAO_NAME := "Saint Barthelemy"]
setnames(countryNameTable.dt,
         old = c("FAOST_CODE", "ABBR_FAO_NAME"),
         new = c("areaCode", "areaName"))

## final data frame for processing
grapeRaw.dt = merge(merge(grape.dt, regionTable.dt, by = "areaCode"),
    countryNameTable.dt, by = "areaCode")
grapeRaw.dt[, yieldValue :=
                computeYield(productionValue, areaHarvestedValue)]
grapeRaw.dt = grapeRaw.dt[areaName != "Liechtenstein", ]

## Remove country which contains no information
hasInfo = function(data, productionSymb, productionValue){
    ifelse(all(data[, productionSymb, with = FALSE] == "M") |
           sum(data[, productionValue, with = FALSE], na.rm = TRUE) == 0,
           FALSE, TRUE)
}
grapeRaw.dt[,info := hasInfo(.SD, "productionSymb", "productionValue"),
                by = "areaName"]
grapeRaw.dt = grapeRaw.dt[info == TRUE, ]
grapeRaw.dt[, info := NULL]

grapeRaw.dt[productionSymb %in% c(" ", "*", "", "\\"),
            productionWeight := as.numeric(1)]
grapeRaw.dt[productionSymb == "M",
            productionWeight := as.numeric(0.25)]
grapeRaw.dt[!(productionSymb %in% c(" ", "*", "", "M")),
            productionWeight := as.numeric(0.5)]
grapeRaw.dt[areaHarvestedSymb %in% c(" ", "*", "", "\\"),
            areaHarvestedWeight := as.numeric(1)]
grapeRaw.dt[areaHarvestedSymb == "M",
            areaHarvestedWeight := as.numeric(0.25)]
grapeRaw.dt[!(areaHarvestedSymb %in% c(" ", "*", "", "M")),
            areaHarvestedWeight := as.numeric(0.5)]
grapeRaw.dt[, yieldWeight := productionWeight * areaHarvestedWeight]

setnames(grapeRaw.dt, old = "yieldValue", "obsered yield")

pdf(file = "grapeYieldRaw.pdf", width = 20, height = 15)
print(xyplot(`obsered yield` ~ year|areaName,
             data = grapeRaw.dt, type = c("l", "g"), auto.key = TRUE,
             ylab = NULL, xlab = NULL))
graphics.off()

globalModel = lm(`obsered yield` ~  year, data = grapeRaw.dt)
grapeRaw.dt[, `Global Model` :=
            coef(globalModel)[1] + coef(globalModel)[2] * year]

pdf(file = "grapeYieldGlobal.pdf", width = 20, height = 15)
print(xyplot(`obsered yield` + `Global Model` ~ year|areaName,
             data = grapeRaw.dt, type = c("l", "g"), auto.key = TRUE,
             ylab = NULL, xlab = NULL))
graphics.off()

grapeRaw.dt[, `Country Model` := predict(lm(`obsered yield` ~ year),
                                 newdata = .SD), by = "areaName"]

pdf(file = "grapeYieldCountry.pdf", width = 20, height = 15)
print(xyplot(`obsered yield` + `Country Model` ~ year|areaName,
             data = grapeRaw.dt, type = c("l", "g"), auto.key = TRUE,
             ylab = NULL, xlab = NULL, ylim = c(0, 40)))
graphics.off()

yieldModelRecent = lmer(log(`obsered yield`) ~ (1 + log(year)|areaName),
    data = grapeRaw.dt, weights = yieldWeight)

grapeRaw.dt[, `Linear Mixed Model` :=
            exp(predict(yieldModelRecent, newdata = .SD,
                        allow.new.levels = TRUE))]


yieldModelRecent = lmer(log(`obsered yield`) ~
    (1 + bs(year, degree = 1, df = 2)|areaName),
    data = grapeRaw.dt, weight = yieldWeight)

grapeRaw.dt[, `Linear Mixed Model` :=
            exp(predict(yieldModelRecent, newdata = .SD,
                        allow.new.levels = TRUE))]

pdf(file = "grapeYieldLme.pdf", width = 20, height = 15)
print(xyplot(`obsered yield` + `Linear Mixed Model`~
             year|areaName, data = grapeRaw.dt,
       type = c("l", "g"), auto.key = TRUE, ylab = NULL, xlab = NULL,
             ylim = c(0, 40)))
graphics.off()


yieldModelRecent = lmer(log(`obsered yield`) ~
    (1 + bs(year, degree = 1, df = 3)|areaName),
    data = grapeRaw.dt, weight = yieldbWeight)

grapeRaw.dt[, `Linear Mixed Model (Spline)` :=
            exp(predict(yieldModelRecent, newdata = .SD,
                        allow.new.levels = TRUE))]

pdf(file = "grapeYieldSplineLme.pdf", width = 20, height = 15)
print(xyplot(`obsered yield` + `Linear Mixed Model (Spline)`~
             year|areaName, data = grapeRaw.dt,
       type = c("l", "g"), auto.key = TRUE, ylab = NULL, xlab = NULL,
             ylim = c(0, 40)))
graphics.off()




## peas yield

peasGreen.dt = data.table(read.csv(paste0(dataPath, "peasGreenSUA.csv"),
    stringsAsFactors = FALSE))

## append regional and country information
regionTable.dt =
    data.table(FAOregionProfile[!is.na(FAOregionProfile$FAOST_CODE),
                                c("FAOST_CODE", "UNSD_SUB_REG",
                                  "UNSD_MACRO_REG")])
setnames(regionTable.dt,
         old = c("FAOST_CODE", "UNSD_SUB_REG", "UNSD_MACRO_REG"),
         new = c("areaCode", "unsdSubReg", "unsdMacroReg"))
countryNameTable.dt =
    data.table(FAOcountryProfile[!is.na(FAOcountryProfile$FAOST_CODE),
                                 c("FAOST_CODE", "ABBR_FAO_NAME")])
countryNameTable.dt[FAOST_CODE == 357,
                    ABBR_FAO_NAME := "Taiwan and China"]
countryNameTable.dt[FAOST_CODE == 107, ABBR_FAO_NAME := "Cote d'Ivoire"]
countryNameTable.dt[FAOST_CODE == 284, ABBR_FAO_NAME := "Aland Islands"]
countryNameTable.dt[FAOST_CODE == 279, ABBR_FAO_NAME := "Curacao"]
countryNameTable.dt[FAOST_CODE == 182, ABBR_FAO_NAME := "Reunion"]
countryNameTable.dt[FAOST_CODE == 282,
                    ABBR_FAO_NAME := "Saint Barthelemy"]
setnames(countryNameTable.dt,
         old = c("FAOST_CODE", "ABBR_FAO_NAME"),
         new = c("areaCode", "areaName"))

## final data frame for processing
peasGreenRaw.dt = merge(merge(peasGreen.dt, regionTable.dt, by = "areaCode"),
    countryNameTable.dt, by = "areaCode")
peasGreenRaw.dt[, yieldValue :=
                computeYield(productionValue, areaHarvestedValue)]
peasGreenRaw.dt = peasGreenRaw.dt[!areaName %in% c("Malawi", "Zimbabwe",
    "Lithuania"), ]

## Remove country which contains no information
hasInfo = function(data, productionSymb, productionValue){
    ifelse(all(data[, productionSymb, with = FALSE] == "M") |
           sum(data[, productionValue, with = FALSE], na.rm = TRUE) == 0,
           FALSE, TRUE)
}
peasGreenRaw.dt[,info := hasInfo(.SD, "productionSymb", "productionValue"),
                by = "areaName"]
peasGreenRaw.dt = peasGreenRaw.dt[info == TRUE, ]
peasGreenRaw.dt[, info := NULL]

peasGreenRaw.dt[productionSymb %in% c(" ", "*", "", "\\"),
            productionWeight := as.numeric(1)]
peasGreenRaw.dt[productionSymb == "M",
            productionWeight := as.numeric(0.25)]
peasGreenRaw.dt[!(productionSymb %in% c(" ", "*", "", "M")),
            productionWeight := as.numeric(0.5)]
peasGreenRaw.dt[areaHarvestedSymb %in% c(" ", "*", "", "\\"),
            areaHarvestedWeight := as.numeric(1)]
peasGreenRaw.dt[areaHarvestedSymb == "M",
            areaHarvestedWeight := as.numeric(0.25)]
peasGreenRaw.dt[!(areaHarvestedSymb %in% c(" ", "*", "", "M")),
            areaHarvestedWeight := as.numeric(0.5)]
peasGreenRaw.dt[, yieldWeight := productionWeight * areaHarvestedWeight]

setnames(peasGreenRaw.dt, old = "yieldValue", "obsered yield")

pdf(file = "peasGreenYieldRaw.pdf", width = 20, height = 15)
print(xyplot(`obsered yield` ~ year|areaName,
             data = peasGreenRaw.dt, type = c("l", "g"), auto.key = TRUE,
             ylab = NULL, xlab = NULL))
graphics.off()

globalModel = lm(`obsered yield` ~  year, data = peasGreenRaw.dt)
peasGreenRaw.dt[, `Global Model` :=
            coef(globalModel)[1] + coef(globalModel)[2] * year]

pdf(file = "peasGreenYieldGlobal.pdf", width = 20, height = 15)
print(xyplot(`obsered yield` + `Global Model` ~ year|areaName,
             data = peasGreenRaw.dt, type = c("l", "g"), auto.key = TRUE,
             ylab = NULL, xlab = NULL))
graphics.off()

peasGreenRaw.dt[, `Country Model` := predict(lm(`obsered yield` ~ year),
                                 newdata = .SD), by = "areaName"]

pdf(file = "peasGreenYieldCountry.pdf", width = 20, height = 15)
print(xyplot(`obsered yield` + `Country Model` ~ year|areaName,
             data = peasGreenRaw.dt, type = c("l", "g"), auto.key = TRUE,
             ylab = NULL, xlab = NULL, ylim = c(0, 40)))
graphics.off()

yieldModelRecent = lmer(log(`obsered yield`) ~ (1 + log(year)|areaName),
    data = peasGreenRaw.dt, weights = yieldWeight)

peasGreenRaw.dt[, `Linear Mixed Model` :=
            exp(predict(yieldModelRecent, newdata = .SD,
                        allow.new.levels = TRUE))]


pdf(file = "peasGreenYieldLme.pdf", width = 20, height = 15)
print(xyplot(`obsered yield` + `Linear Mixed Model`~
             year|areaName, data = peasGreenRaw.dt,
       type = c("l", "g"), auto.key = TRUE, ylab = NULL, xlab = NULL,
             ylim = c(0, 40)))
graphics.off()



yieldModelRecent = lmer(log(`obsered yield`) ~
    (1 + bs(year, degree = 1, df = 3)|areaName),
    data = peasGreenRaw.dt, weight = yieldWeight)

peasGreenRaw.dt[, `Linear Mixed Model (Spline)` :=
            exp(predict(yieldModelRecent, newdata = .SD,
                        allow.new.levels = TRUE))]

pdf(file = "peasGreenYieldSplineLme.pdf", width = 20, height = 15)
print(xyplot(`obsered yield` + `Linear Mixed Model (Spline)`~
             year|areaName, data = peasGreenRaw.dt,
       type = c("l", "g"), auto.key = TRUE, ylab = NULL, xlab = NULL,
             ylim = c(0, 40)))
graphics.off()



## Production
## ---------------------------------------------------------------------


peasGreen.dt = data.table(read.csv(paste0(dataPath, "peasGreenSUA.csv"),
    stringsAsFactors = FALSE))

## append regional and country information
regionTable.dt =
    data.table(FAOregionProfile[!is.na(FAOregionProfile$FAOST_CODE),
                                c("FAOST_CODE", "UNSD_SUB_REG",
                                  "UNSD_MACRO_REG")])
setnames(regionTable.dt,
         old = c("FAOST_CODE", "UNSD_SUB_REG", "UNSD_MACRO_REG"),
         new = c("areaCode", "unsdSubReg", "unsdMacroReg"))
countryNameTable.dt =
    data.table(FAOcountryProfile[!is.na(FAOcountryProfile$FAOST_CODE),
                                 c("FAOST_CODE", "ABBR_FAO_NAME")])
countryNameTable.dt[FAOST_CODE == 357,
                    ABBR_FAO_NAME := "Taiwan and China"]
countryNameTable.dt[FAOST_CODE == 107, ABBR_FAO_NAME := "Cote d'Ivoire"]
countryNameTable.dt[FAOST_CODE == 284, ABBR_FAO_NAME := "Aland Islands"]
countryNameTable.dt[FAOST_CODE == 279, ABBR_FAO_NAME := "Curacao"]
countryNameTable.dt[FAOST_CODE == 182, ABBR_FAO_NAME := "Reunion"]
countryNameTable.dt[FAOST_CODE == 282,
                    ABBR_FAO_NAME := "Saint Barthelemy"]
setnames(countryNameTable.dt,
         old = c("FAOST_CODE", "ABBR_FAO_NAME"),
         new = c("areaCode", "areaName"))

## final data frame for processing
peasGreenRaw.dt = merge(merge(peasGreen.dt, regionTable.dt, by = "areaCode"),
    countryNameTable.dt, by = "areaCode")
peasGreenRaw.dt[, yieldValue :=
                computeYield(productionValue, areaHarvestedValue)]
peasGreenRaw.dt = peasGreenRaw.dt[areaName != "Liechtenstein", ]
peasGreenRaw.dt[,info := hasInfo(.SD, "productionSymb", "productionValue"),
                by = "areaName"]
peasGreenRaw.dt = peasGreenRaw.dt[info == TRUE, ]
peasGreenRaw.dt[, info := NULL]

peasGreenRaw.dt[productionSymb %in% c(" ", "*", "", "\\"),
            productionWeight := as.numeric(1)]
peasGreenRaw.dt[productionSymb == "M",
            productionWeight := as.numeric(0.25)]
peasGreenRaw.dt[!(productionSymb %in% c(" ", "*", "", "M")),
            productionWeight := as.numeric(0.5)]
peasGreenRaw.dt[areaHarvestedSymb %in% c(" ", "*", "", "\\"),
            areaHarvestedWeight := as.numeric(1)]
peasGreenRaw.dt[areaHarvestedSymb == "M",
            areaHarvestedWeight := as.numeric(0.25)]
peasGreenRaw.dt[!(areaHarvestedSymb %in% c(" ", "*", "", "M")),
            areaHarvestedWeight := as.numeric(0.5)]
peasGreenRaw.dt[, yieldWeight := productionWeight * areaHarvestedWeight]

peasGreenRaw.dt[productionValue == 0 & productionSymb == "M",
                productionValue := as.numeric(NA)]


peasGreenRaw.dt[, `logged observed production` := log(productionValue)]
peasGreenRaw.dt[, `logged observed area harvested` := log(areaHarvestedValue)]

pdf(file = "peasGreenProductionAreaHarvestedRaw.pdf", width = 20, height = 15)
print(xyplot(`logged observed production` +
      `logged observed area harvested` ~
             year|areaName, type = c("g", "l"),
             data = peasGreenRaw.dt[productionValue != 0 |
                 areaHarvestedValue != 0, ], auto.key = TRUE,
             ylab = NULL, xlab = NULL, scales =  list(y = "free")))
graphics.off()

pdf(file = "peasGreenProductionRaw.pdf", width = 20, height = 15)
print(xyplot(`productionValue` ~ year|areaName,
             data = peasGreenRaw.dt, type = c("l", "g"), auto.key = TRUE,
             ylab = NULL, xlab = NULL, scales = list(y = "free")))
graphics.off()

ensembleImpute = function(x, plot = FALSE){
    missIndex = which(is.na(x))
    T = length(x)
    time = 1:T
    n.miss = length(missIndex)
    n.obs = T - n.miss
    if(n.miss > 0){
        if(n.obs >= 5 & var(x, na.rm = TRUE) != 0){
            ## Start fitting
            meanFit = rep(mean(x, na.rm = TRUE), T)
            meanFitError = 1/sum(abs(x - meanFit), na.rm = TRUE)

            lmFit = predict(lm(formula = x ~ time),
                newdata = data.frame(time = time))
            lmFit[lmFit < 0] = 0
            lmFitError = 1/sum(abs(x - lmFit), na.rm = TRUE)

            x.tmp = na.omit(x)
            time.tmp = time[-attr(x.tmp, "na.action")]
            marsFit = try(predict(earth(x.tmp ~ time.tmp),
                newdata = data.frame(time.tmp = time)))
            if(!inherits(marsFit, "try-error")){
                marsFit[marsFit < 0] = 0
                marsFitError = 1/sum(abs(x - marsFit), na.rm = TRUE)
            } else {
                marsFit = rep(0, T)
                marsFitError = 0
            }


            expFit = exp(predict(lm(formula = log(x + 1) ~ time),
                newdata = data.frame(time = time)))
            ## expFitError = ifelse(n.obs/T >= 0.5 &
            ##     length(na.omit(tail(x, 6))) > 0,
            ##     1/sum(abs(x - expFit), na.rm = TRUE), 0)
            expFitError =
                1/sum(abs(x - expFit), na.rm = TRUE)

            loessFit = try(predict(loess(formula = x ~ time,
                control = loess.control(surface = "direct"),
                span = ifelse(n.obs/T >= 0.5, 0.3,
                    ifelse(n.obs <= 5, 1, 0.75)), degree = 1),
                newdata = data.frame(time)))
            if(!inherits(loessFit, "try-error") &
               sum(abs(x - loessFit), na.rm = TRUE) > 0.1 &
               T >= 5){
                loessFit[loessFit < 0] = 0
                loessFitError = 1/sum(abs(x - loessFit), na.rm = TRUE)
            } else {
                loessFit = rep(0, T)
                loessFitError = 0
            }

            xmax = max(x, na.rm = TRUE)
            x.scaled = x/xmax
            logisticFit = predict(glm(formula = x.scaled ~ time,
                family = "binomial"), newdata = data.frame(time = time),
                type = "response") *
                    xmax
            logisticFitError = 1/sum(abs(x - logisticFit), na.rm = TRUE)

            arimaFit = na.approx(x, na.rm = FALSE)
            nonMissIndex = which(!is.na(arimaFit))
            fit = auto.arima(na.omit(arimaFit))
            arimaFit[nonMissIndex] = fitted(fit)

            if(var(arimaFit, na.rm = TRUE) > 1e-3){
                obs = which(!is.na(arimaFit))
                numberForward =
                    length(which(is.na(arimaFit[max(obs):length(arimaFit)])))
                if(numberForward > 0)
                    arimaFit[(max(obs) + 1):length(arimaFit)] =
                        c(forecast(fit, h = numberForward)$mean)
                numberBackward =
                    length(which(is.na(arimaFit[min(obs):1])))
                if(numberBackward > 0)
                    arimaFit[(min(obs) - 1):1] =
                        c(forecast(auto.arima(rev(arimaFit),
                                              seasonal = FALSE),
                                   h = numberBackward)$mean)
                arimaFit[arimaFit < 0]  = 0
                arimaFitError =
                    arimaFitError = 1/sum(abs(x - arimaFit),
                        na.rm = TRUE)
                    ## mean(c(meanFitError, lmFitError, marsFitError,
                    ##        expFitError[expFitError != 0],
                    ##        loessFitError[loessFitError != 0],
                    ##        logisticFitError), na.rm = TRUE)
            } else {
                arimaFit = rep(0, T)
                arimaFitError = 0
            }


            naiveFit = naiveImputation(x)
            naiveFitError = mean(c(meanFitError, lmFitError, marsFitError,
                           expFitError[expFitError != 0],
                           loessFitError[loessFitError != 0],
                           logisticFitError), na.rm = TRUE)

            ## Construct the ensemble
            weights =
                c(mean = meanFitError,
                  lm = lmFitError,
                  mars = marsFitError,
                  exp = expFitError,
                  loess = loessFitError,
                  logistic = logisticFitError,
                  arima = arimaFitError,
                  naive = naiveFitError)^2/
                    sum(c(mean = meanFitError,
                          lm = lmFitError,
                          mars = marsFitError,
                          exp = expFitError,
                          loess = loessFitError,
                          logisticFitError,
                          arima = arimaFitError,
                          naive = naiveFitError)^2, na.rm = TRUE)
            weights[is.na(weights)] = 0
            finalFit = (meanFit * weights["mean"] +
                        lmFit * weights["lm"] +
                        marsFit * weights["mars"] +
                        expFit * weights["exp"] +
                        loessFit * weights["loess"] +
                        logisticFit * weights["logistic"] +
                        arimaFit * weights["arima"] +
                        naiveFit * weights["naive"])

            if(plot){
                plot(x ~ time,
                     ylim = c(0,
                         max(c(x,
                               lmFit,
                               logisticFit,
                               arimaFit,
                               loessFit
                               ),
                         na.rm = TRUE)),
                     pch = 19)
                lines(meanFit, col = "red")
                lines(lmFit, col = "orange")
                lines(marsFit, col = "maroon")
                lines(expFit, col = "gold")
                lines(loessFit, col = "brown")
                lines(logisticFit, col = "green")
                lines(arimaFit, col = "purple")
                lines(naiveFit, col = "blue")
                lines(finalFit, col = "steelblue", lwd = 3)
                legend("topleft", legend =
                       paste0(c("mean", "linear", "mars", "exponential",
                               "loess", "logistic", "arima",
                               "naive", "final"), " (",
                             round(c(weights, 1), 3) * 100, "%)"),
                       col = c("red", "orange", "maroon", "gold", "brown",
                           "green", "purple", "blue",
                           "steelblue"), lwd = c(rep(1, 8), 3), bty = "n",
                       lty = 1)

            }
            x[missIndex] = finalFit[missIndex]
        } else {
            x = naiveImputation(x)
        }
    }
    round(x, 3)
}

test = c(peasGreenRaw.dt[areaName == "Ireland", productionValue],
    rep(NA, 5))
ensembleImpute(test, plot = TRUE)


## Easy case
pdf(file = "productionEasy.pdf", width = 10)
test = c(peasGreenRaw.dt[areaName == "South Africa", productionValue],
    rep(NA, 5))
missIndex = which(is.na(test))
T = 1:length(test) + min(peasGreenRaw.dt$year) - 1
fit = ensembleImpute(test)
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of green peas in South Africa")
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of green peas in South Africa")
points(T[missIndex], fit[missIndex], col = "red", pch = 19)
lines(T[missIndex], fit[missIndex], col = "red")
ensembleImpute(test, plot = TRUE)
graphics.off()

## Moderate case
pdf(file = "productionModerate.pdf", width = 10)
test = c(peasGreenRaw.dt[areaName == "China", productionValue],
    rep(NA, 5))
missIndex = which(is.na(test))
T = 1:length(test) + min(peasGreenRaw.dt$year) - 1
fit = ensembleImpute(test)
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of green peas in China")
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of green peas in China")
points(T[missIndex], fit[missIndex], col = "red", pch = 19)
lines(T[missIndex], fit[missIndex], col = "red")
ensembleImpute(test, plot = TRUE)
graphics.off()

## Slightly difficult case
pdf(file = "productionDifficult1.pdf", width = 10)
test = c(peasGreenRaw.dt[areaName == "Albania", productionValue],
    rep(NA, 5))
missIndex = which(is.na(test))
T = 1:length(test) + min(peasGreenRaw.dt$year) - 1
fit = ensembleImpute(test)
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of green peas in Albania")
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of green peas in Albania")
points(T[missIndex], fit[missIndex], col = "red", pch = 19)
lines(T[missIndex], fit[missIndex], col = "red")
ensembleImpute(test, plot = TRUE)
graphics.off()

## Slightly difficult case
pdf(file = "productionDifficult2.pdf", width = 10)
test = c(peasGreenRaw.dt[areaName == "Norway", productionValue],
    rep(NA, 5))
missIndex = which(is.na(test))
T = 1:length(test) + min(peasGreenRaw.dt$year) - 1
fit = ensembleImpute(test)
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of green peas in Norway")
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of green peas in Norway")
points(T[missIndex], fit[missIndex], col = "red", pch = 19)
lines(T[missIndex], fit[missIndex], col = "red")
ensembleImpute(test, plot = TRUE)
graphics.off()


## Difficult
pdf(file = "productionHard1.pdf", width = 10)
test = c(peasGreenRaw.dt[areaName == "Serbia", productionValue],
    rep(NA, 5))
missIndex = which(is.na(test))
T = 1:length(test) + min(peasGreenRaw.dt$year) - 1
fit = ensembleImpute(test)
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of green peas in Serbia")
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of green peas in Serbia")
points(T[missIndex], fit[missIndex], col = "red", pch = 19)
lines(T[missIndex], fit[missIndex], col = "red")
ensembleImpute(test, plot = TRUE)
graphics.off()


## Difficult
pdf(file = "productionHard2.pdf", width = 10)
test = c(peasGreenRaw.dt[areaName == "Ireland", productionValue],
    rep(NA, 5))
missIndex = which(is.na(test))
T = 1:length(test) + min(peasGreenRaw.dt$year) - 1
fit = ensembleImpute(test)
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of green peas in Ireland")
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of green peas in Ireland")
points(T[missIndex], fit[missIndex], col = "red", pch = 19)
lines(T[missIndex], fit[missIndex], col = "red")
ensembleImpute(test, plot = TRUE)
graphics.off()



## Impossible
carrot.dt = data.table(read.csv(paste0(dataPath, "carrotsAndTurnipsSUA.csv"),
    stringsAsFactors = FALSE))

## append regional and country information
regionTable.dt =
    data.table(FAOregionProfile[!is.na(FAOregionProfile$FAOST_CODE),
                                c("FAOST_CODE", "UNSD_SUB_REG",
                                  "UNSD_MACRO_REG")])
setnames(regionTable.dt,
         old = c("FAOST_CODE", "UNSD_SUB_REG", "UNSD_MACRO_REG"),
         new = c("areaCode", "unsdSubReg", "unsdMacroReg"))
countryNameTable.dt =
    data.table(FAOcountryProfile[!is.na(FAOcountryProfile$FAOST_CODE),
                                 c("FAOST_CODE", "ABBR_FAO_NAME")])
countryNameTable.dt[FAOST_CODE == 357,
                    ABBR_FAO_NAME := "Taiwan and China"]
countryNameTable.dt[FAOST_CODE == 107, ABBR_FAO_NAME := "Cote d'Ivoire"]
countryNameTable.dt[FAOST_CODE == 284, ABBR_FAO_NAME := "Aland Islands"]
countryNameTable.dt[FAOST_CODE == 279, ABBR_FAO_NAME := "Curacao"]
countryNameTable.dt[FAOST_CODE == 182, ABBR_FAO_NAME := "Reunion"]
countryNameTable.dt[FAOST_CODE == 282,
                    ABBR_FAO_NAME := "Saint Barthelemy"]
setnames(countryNameTable.dt,
         old = c("FAOST_CODE", "ABBR_FAO_NAME"),
         new = c("areaCode", "areaName"))

## final data frame for processing
carrotRaw.dt = merge(merge(carrot.dt, regionTable.dt, by = "areaCode"),
    countryNameTable.dt, by = "areaCode")
carrotRaw.dt[, yieldValue :=
                computeYield(productionValue, areaHarvestedValue)]
carrotRaw.dt = carrotRaw.dt[areaName != "Liechtenstein", ]
carrotRaw.dt[,info := hasInfo(.SD, "productionSymb", "productionValue"),
                by = "areaName"]
carrotRaw.dt = carrotRaw.dt[info == TRUE, ]
carrotRaw.dt[, info := NULL]

carrotRaw.dt[productionSymb %in% c(" ", "*", "", "\\"),
            productionWeight := as.numeric(1)]
carrotRaw.dt[productionSymb == "M",
            productionWeight := as.numeric(0.25)]
carrotRaw.dt[!(productionSymb %in% c(" ", "*", "", "M")),
            productionWeight := as.numeric(0.5)]
carrotRaw.dt[areaHarvestedSymb %in% c(" ", "*", "", "\\"),
            areaHarvestedWeight := as.numeric(1)]
carrotRaw.dt[areaHarvestedSymb == "M",
            areaHarvestedWeight := as.numeric(0.25)]
carrotRaw.dt[!(areaHarvestedSymb %in% c(" ", "*", "", "M")),
            areaHarvestedWeight := as.numeric(0.5)]
carrotRaw.dt[, yieldWeight := productionWeight * areaHarvestedWeight]

carrotRaw.dt[productionValue == 0 & productionSymb == "M",
                productionValue := as.numeric(NA)]


carrotRaw.dt[, `logged observed production` := log(productionValue)]
carrotRaw.dt[, `logged observed area harvested` := log(areaHarvestedValue)]


## Difficult
pdf(file = "productionImpossible.pdf", width = 10)
test = c(carrotRaw.dt[areaName == "Trinidad and Tobago", productionValue],
    rep(NA, 5))
missIndex = which(is.na(test))
T = 1:length(test) + min(peasGreenRaw.dt$year) - 1
fit = ensembleImpute(test)
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of carrots in Trinidad and Tobago")
plot(T, test, type = "b", ylim = c(0, max(test, fit, na.rm = TRUE)),
     xlab = "Year", ylab = "",
     main = "Production of carrots in Trinidad and Tobago")
points(T[missIndex], fit[missIndex], col = "red", pch = 19)
lines(T[missIndex], fit[missIndex], col = "red")
ensembleImpute(test, plot = TRUE)
graphics.off()








test = peasGreenRaw.dt[areaName == "China", productionValue]
artificial = c(test, rep(test[length(test)], 10), rep(NA, 5))
ensembleImpute(artificial, plot = TRUE)
observed = peasGreenRaw.dt[areaName == "China", productionValue]
n.observed = length(test)
artificial = c(test, rep(test[length(test)], 20) + rnorm(20, sd = 1e05),
    1e07 - 2e05 * 1:20 + rnorm(20, sd = 2e05), rep(NA, 5))
n.artificial = length(artificial)


pred = matrix(rep(NA, 5 * 72), nr = 5)
for(i in 20:n.artificial){
    tmp = c(artificial[1:i], rep(NA, n.artificial - i))
    pred[, i - 19] =
        ensembleImpute(tmp[1:(i + 5)])[(i + 1):(i + 5)]
}


plot(1:n.artificial + 1960, c(artificial[1:20], rep(NA, n.artificial - 20)),
     ylim = c(0, 1.5e07), xlab = "", ylab = "")
abline(v = 2009, col = "blue", lty = 2)
for(i in 21:n.artificial){
    points(i + 1960, artificial[i])
    lines((i+1 + 1960):(i+5 + 1960), pred[, i - 20], col = "red")
    Sys.sleep(0.5)
    if(i + 1960 == 2009)
        text(2020, 1.3e07, labels = "Assuming saturation")
    if(i + 1960 == 2030)
        text(2045, 5e06, labels = "Assuming declining demand")
}
points(1993, 1e06, cex = 20)
points(2015, 1e07, cex = 20)
points(2035, 9e06, cex = 20)
text(2020, 1e06, labels = "Transitional period")
lines(x = c(1993, 2020), y = c(1e06, 1.5e06))
lines(x = c(2015, 2020), y = c(1e07, 1.5e06))
lines(x = c(2035, 2020), y = c(9e06, 1.5e06))









########################################################################


## Impossible
commodity.dt = data.table(read.csv(paste0(dataPath,
    "cauliflowersAndBroccoliSUA.csv"),
    stringsAsFactors = FALSE))

## append regional and country information
regionTable.dt =
    data.table(FAOregionProfile[!is.na(FAOregionProfile$FAOST_CODE),
                                c("FAOST_CODE", "UNSD_SUB_REG",
                                  "UNSD_MACRO_REG")])
setnames(regionTable.dt,
         old = c("FAOST_CODE", "UNSD_SUB_REG", "UNSD_MACRO_REG"),
         new = c("areaCode", "unsdSubReg", "unsdMacroReg"))
countryNameTable.dt =
    data.table(FAOcountryProfile[!is.na(FAOcountryProfile$FAOST_CODE),
                                 c("FAOST_CODE", "ABBR_FAO_NAME")])
countryNameTable.dt[FAOST_CODE == 357,
                    ABBR_FAO_NAME := "Taiwan and China"]
countryNameTable.dt[FAOST_CODE == 107, ABBR_FAO_NAME := "Cote d'Ivoire"]
countryNameTable.dt[FAOST_CODE == 284, ABBR_FAO_NAME := "Aland Islands"]
countryNameTable.dt[FAOST_CODE == 279, ABBR_FAO_NAME := "Curacao"]
countryNameTable.dt[FAOST_CODE == 182, ABBR_FAO_NAME := "Reunion"]
countryNameTable.dt[FAOST_CODE == 282,
                    ABBR_FAO_NAME := "Saint Barthelemy"]
setnames(countryNameTable.dt,
         old = c("FAOST_CODE", "ABBR_FAO_NAME"),
         new = c("areaCode", "areaName"))

## final data frame for processing
commodityRaw.dt = merge(merge(commodity.dt, regionTable.dt, by = "areaCode"),
    countryNameTable.dt, by = "areaCode")
commodityRaw.dt[, yieldValue :=
                computeYield(productionValue, areaHarvestedValue)]
commodityRaw.dt = commodityRaw.dt[areaName != "Liechtenstein", ]
commodityRaw.dt[,info := hasInfo(.SD, "productionSymb", "productionValue"),
                by = "areaName"]
commodityRaw.dt = commodityRaw.dt[info == TRUE, ]
commodityRaw.dt[, info := NULL]

commodityRaw.dt[productionSymb %in% c(" ", "*", "", "\\"),
            productionWeight := as.numeric(1)]
commodityRaw.dt[productionSymb == "M",
            productionWeight := as.numeric(0.25)]
commodityRaw.dt[!(productionSymb %in% c(" ", "*", "", "M")),
            productionWeight := as.numeric(0.5)]
commodityRaw.dt[areaHarvestedSymb %in% c(" ", "*", "", "\\"),
            areaHarvestedWeight := as.numeric(1)]
commodityRaw.dt[areaHarvestedSymb == "M",
            areaHarvestedWeight := as.numeric(0.25)]
commodityRaw.dt[!(areaHarvestedSymb %in% c(" ", "*", "", "M")),
            areaHarvestedWeight := as.numeric(0.5)]
commodityRaw.dt[, yieldWeight := productionWeight * areaHarvestedWeight]

commodityRaw.dt[productionValue == 0 & productionSymb == "M",
                productionValue := as.numeric(NA)]


commodityRaw.dt[, `logged observed production` := log(productionValue)]
commodityRaw.dt[, `logged observed area harvested` := log(areaHarvestedValue)]

test = c(commodityRaw.dt[areaName == "the United States of America",
    productionValue])

n = 3
par(mfrow = c(n + 1, 1), mar = rep(0, 4))
plot(test, type = "b")
for(i in 1:n){
    plot(bs(test, df = n)[, i], type = "b", col = "grey")
}


test = c(commodityRaw.dt[areaName == "the United States of America",
    productionValue])

test2 = c(commodityRaw.dt[areaName == "the United States of America",
    areaHarvestedValue])

test3 = c(commodityRaw.dt[areaName == "the United States of America",
    yieldValue])

## MARS/earth
par(mfrow = c(3, 1))
test2.fit = earth(test2 ~ test, )
plot(test2, type = "b")
lines(fitted(test2.fit), col = "red")
test3.fit = earth(test3 ~ test)
plot(test3, type = "b")
lines(fitted(test.fit), col = "red")
plot(test, type = "b")
lines(fitted(test2.fit) * fitted(test3.fit), col = "red")

## Wavelet testing
test = c(commodityRaw.dt[areaName == "the United States of America",
    productionValue])

par(mfrow = c(2, 1))
plot(test, type = "b")
test.wd = wd(c(test, rep(0, 13)), filter.number = 1, family = "DaubExPhase")
plot(test.wd, first.level = 0)



library(wavethresh)
par(mfrow = c(2, 1))
plot(test, type = "b")
test.wp = wp(c(test, rep(0, 13)), filter.number = 1, family = "DaubExPhase")
plot(test.wp, first.level = 0, SmoothedLines = FALSE)

plot(test.wp, first.level = 0, SmoothedLines = TRUE)

par(mfrow = c(test.wp$nlevels, 1), mar = c(rep(0, 4)))
plot(c(test, rep(0, 13)), type = "b")
for(i in 1:(test.wp$nlevels - 1)){
    plot(accessD(test.wp, level = i), type = "h")
}


test.wd = wd(c(test, rep(0, 13)), filter.number = 1, family = "DaubExPhase")
plot(test.wd)

test.wp = wp(c(test, rep(0, 13)), filter.number = 1, family = "DaubExPhase")
MaNoVe(test.wp)




wr(accessD(test.wd, level = 2))

plot(wd(rnorm(1024)))



x <- example.1()$y + rnorm(512, sd=0.2)
xwst <- wst(x)
## xwstT <- threshold(xwst)
xwstTNV <- MaNoVe(xwst)
xTwr <- InvBasis(xwst, xwstTNV)
plot(x)
lines(xTwr)
