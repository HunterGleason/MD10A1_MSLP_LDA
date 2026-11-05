####Load Library####
pkgs <- c("terra","data.table","MASS")


CheckInstallPackages <- function(pkgs) {
  x <- lapply(pkgs, function(pkg) {
    if (!require(pkg, character.only = TRUE)) {
      install.packages(pkg, repos = "http://cran.rstudio.com")
      library(pkg, character.only = TRUE)
    }
  })
}


####Compute mean fall sea level pressure from annual output of DL_Fall_ERA5_MSLP_annual.py####
#Read in annual ERA5 monthly mean MSLP GRIB file
WORK_DIR <- readline(prompt="Enter path to cloned MD10A1_MSLP_LDA working directory, e.g.,'/home/user/Downloads/MD10A1_MSLP_LDA/', no quotes:")
setwd(WORK_DIR)

year<-readline(prompt="Enter hydrologic (Sep-Sep) year to run, e.g., 2020, make sure 'DL_Fall_ERA5_MSLP_annual.py' has been run and the output GRIB for the given year is in the Data directory:")

#Read GRIB using GDAL
fall_slp <- rast(paste0("Data/",year,"fall_era5_download.grib"),lyrs=c(1,2,3))

#Compute fall (Sep-Oct-Nov) mean sea level pressure 
fall_slp_mean <- as.data.frame(mean(fall_slp))

#Select average column 
fall_slp <- fall_slp_mean$mean

####Scale and center current years fall MSLP data####

#Scale the data using scaling from analysis, saved as local CSV
scale_center <- fread("Data/scale_center.csv")

#Load principle component eigenvectors from analysis, saved as local CSV 
loadings<-fread("Data/slp_loadings.csv")

#Center the current years fall MSLP data
centered<-fall_slp-scale_center[2,]

#Scale the current years fall MSLP data
scaled<-centered/scale_center[1,]

#Transpose and change class to data.frame
scaled<-t(scaled)
scaled<-as.data.frame(scaled)

####Compute ERA5 principle component scores using eigenvectors form analysis####
PC1_Score<-sum(scaled$V1*loadings$PC1)
PC2_Score<-sum(scaled$V1*loadings$PC2)
PC3_Score<-sum(scaled$V1*loadings$PC3)
PC8_Score<-sum(scaled$V1*loadings$PC8)
PC10_Score<-sum(scaled$V1*loadings$PC10)
PC11_Score<-sum(scaled$V1*loadings$PC11)

message(paste("PC1 score is: ",PC1_Score,sep=''))
message(paste("PC2 score is: ",PC2_Score,sep=''))
message(paste("PC3 score is: ",PC3_Score,sep=''))
message(paste("PC8 score is: ",PC8_Score,sep=''))
message(paste("PC10 score is: ",PC10_Score,sep=''))
message(paste("PC11 score is: ",PC11_Score,sep=''))

#Create a new observation from current year PC scores 
OBS<-as.data.frame(cbind(PC1_Score,PC2_Score,PC3_Score,PC8_Score,PC10_Score,PC11_Score))
colnames(OBS)<-c('PC1','PC2','PC3','PC8','PC10','PC11')

#Load the LDA matrix from analysis 
LDA_Matrix<-read.csv("Data/LDA_Matrix.csv")

#Fit the LDA model from analysis 
lda_mod<-lda(formula = as.formula('k_clust~PC1+PC2+PC3+PC8+PC10+PC11'),data=LDA_Matrix)

#Make LDA prediction for current years observation 
yhat<-predict(lda_mod,OBS)

#Print results
message(paste("LD1 Score: "),yhat$x,sep='')
message(paste("LD1 Cluster 1 Posterior: "),yhat$posterior[1],sep='')
message(paste("LD1 Cluster 2 Posterior: "),yhat$posterior[2],sep='')
message(paste('Predicted Snow Off Cluster: Cluster ',yhat$class,' (See Gleason et al. 2020 Figure 4 for regional cluster SDoff differences)',sep=''))
