library(ROCR)
library(gmodels)
library(ReporteRs)
library(lift)
library(boot)
library(ggplot2)

dane <- read.table("dataset.csv", sep=",", dec=".", header=T, stringsAsFactors=F)
dane$age_grouped <- cut(dane$age, breaks = c(-Inf, 18, 25, 29, 39, Inf), labels = c("underage", "19-25", "26-29", "30-39", "40+"))
#10 Fold Mean Squared Error (Misclassification error)
t <- split(c(1:nrow(dane)), sample(1:nrow(dane), size=10, replace=FALSE))
c <- sort(c, decreasing = F)
misClasificError <- vector()
area <- vector()
filename <- paste("summary_of_my_logistic_regression_",format(Sys.time(), "%a%b%d%Y%H-%M-%S"),".docx",sep = "")
mydoc <- docx(title=filename)
for (i in 1:10)
{
  val <- dane[t[[i]],]
  train <- dane[-t[[i]],]
  logisticRegression <- glm(purchased ~ sex + age_grouped + as.factor(education), data = train, family = "binomial")
  summary(logisticRegression)
  out <- capture.output(summary(logisticRegression))
  mydoc<-addParagraph(mydoc, out, stylename = "rRawOutput")
  
  #Resulting Proabilities
  profiles <- unique(train[,c("sex", "age_grouped", "education")])
  profiles <- data.frame(profiles, profile=apply(profiles, 1, paste, collapse=", "))
  profiles <- data.frame(profiles, prediction=inv.logit(predict(logisticRegression, profiles)))
  ggplot(profiles, aes(x=profile, y=prediction)) + 
    geom_bar(stat="sum") + 
    theme(axis.text.x = element_text(angle = 90, hjust = 1)) + 
    theme(legend.position="none")+
    scale_x_discrete(limits = profiles$profile[rev(order(profiles$prediction))] )
  probpareto =   ggplot(profiles, aes(x=profile, y=prediction)) + 
    geom_bar(stat="sum") + 
    theme(axis.text.x = element_text(angle = 90, hjust = 1)) + 
    theme(legend.position="none")+
    scale_x_discrete(limits = profiles$profile[rev(order(profiles$prediction))] )
  mydoc = addPlot( doc = mydoc, fun = print, x = probpareto)#, vector.graphic = T, width = 4, height = 4)
  
  #Misclassification Error
  fitted.results <- predict(logisticRegression,newdata=val,type='response')
  fitted.results <- ifelse(fitted.results > 0.5,1,0)
  misClasificError[i] <- mean(fitted.results != val$purchased)
  out <- capture.output(cat("MISCLASSIFICATION ERROR - ITERATION", i), misClasificError[i])
  mydoc <- addParagraph(mydoc, out, stylename = "rRawOutput")
  
  # ROC and AREA UNDER CURVE
  p <- predict(logisticRegression,newdata=val,type='response')
  pr <- prediction(p, val$purchased)
  # TPR = sensitivity, FPR=1-specificity
  prf <- performance(pr, measure = "tpr", x.measure = "fpr")
  plot(prf,main="ROC curve")
  #mydoc = addPlot( doc = mydoc, fun = print, x = rocplot)#, vector.graphic = T, width = 4, height = 4)
  #mydoc <- addParagraph(mydoc, cat("ROC CURVE - ITERATION", i), plot(prf), stylename = "rRawOutput")
  auc <- performance(pr, measure = "auc")
  area[i] <- auc@y.values[[1]]
  out <- capture.output(cat("AREA UNDER CURVE - ITERATION", i), area[i])
  mydoc <- addParagraph(mydoc, out, stylename = "rRawOutput")
  #cat("AREA UNDER CURVE - ITERATION", i, auc, file=filename, sep="n", append=TRUE)
  #LIFT CURVE
  #perf <- performance(pr,"lift","rpp")
  #plot(perf, main="lift curve")
}

MSE <- mean(misClasificError)
out <- capture.output(cat("","","10 Fold Mean Squared Error (Misclassification error)", MSE,sep = '\n'))
mydoc <- addParagraph(mydoc, out, stylename = "rRawOutput")
marea <- mean(area)
out <- capture.output(cat("","","MEAN AREA UNDER THE CURVE", marea,sep = '\n'))
mydoc <- addParagraph(mydoc, out, stylename = "rRawOutput")
writeDoc( mydoc, file = filename)
