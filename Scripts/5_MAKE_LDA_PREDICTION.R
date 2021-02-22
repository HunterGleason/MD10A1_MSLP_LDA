# Copyright 2021 Province of British Columbia
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.




####Load Library####
library(rgdal)
library(data.table)
library(MASS)

####Compute mean fall sea level pressure from annual output of DL_Fall_ERA5_MSLP_annual.py####
#Read in annual ERA5 monthly mean MSLP GRIB file
FALL_ERA5_MLSP <- readline(prompt="Enter path to ERA5 Fall Mean Sea Level Pressure GRIB file (output from DL_Fall_ERA5_MSLP_annual.py): ")

#Read GRIB using GDAL
fall_slp <- readGDAL(FALL_ERA5_MLSP,band = c(1,2,3))

#Get MSLP data
fall_slp <- fall_slp@data

#Compute fall (Sep-Oct-Nov) mean sea level pressure 
fall_slp$mean <- (fall_slp[,1]+fall_slp[,2]+fall_slp[,3])/3

#Select average column 
fall_slp <- fall_slp$mean

####Scale and center current years fall MSLP data####

#Scale the data using scaling from analysis, saved as local CSV
scale_center <- fread('RawData/Prediction/scale_center.csv')

#Load principle component eigenvectors from analysis, saved as local CSV 
loadings<-fread('RawData/Prediction/slp_loadings.csv')

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
LDA_Matrix<-read.csv('RawData/Prediction/LDA_Matrix.csv')

#Fit the LDA model from analysis 
lda_mod<-lda(formula = as.formula('k_clust~PC1+PC2+PC3+PC8+PC10+PC11'),data=LDA_Matrix)

#Make LDA prediction for current years observation 
yhat<-predict(lda_mod,OBS)

#Print results
message(paste("LD1 Score: "),yhat$x,sep='')
message(paste("LD1 Cluster 1 Posterior: "),yhat$posterior[1],sep='')
message(paste("LD1 Cluster 2 Posterior: "),yhat$posterior[2],sep='')
message(paste('Predicted Snow Off Cluster: Cluster ',yhat$class,' (See Gleason et al. 2020 Figure 4 for regional cluster SDoff differences)',sep=''))

