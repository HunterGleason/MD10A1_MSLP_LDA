
#Import required packages 
library(raster)
library(ggplot2)
library(ncdf4)
library(doParallel)
library(parallel)
library(MASS)
library(caret)
library(sf)
library(tidyverse)
library(RColorBrewer)
library(candisc)
library(bcmaps)
library(bcmapsdata)


######################################################################################################################################################
######################################################################################################################################################
#Read in gridded annual snow duration over BC derived from M*D10A1 data (see prior study), run PCA on time series and export spatial loadings as CSV##
######################################################################################################################################################
######################################################################################################################################################

#########################
#Declair global varibles#
#########################

#Start and end over which M*D10A1 snow duration data is available
mod_start_year<-2000
mod_end_year<-2018

#Path to gridded M*10A1 derived snow duration Geotiff's (ommiting year)
snow_dir_path <-"RawData/Annual_Snow_Metrics/MD10A1_SD_"

#Path to gridded monthly Reanalysis 2 sea-level pressure
month_slp_pth<-"RawData/mslp.mon.mean.nc"

#Declair start and end year over which to compute principle components for MSLP data
slp_first_year=1979
slp_last_year=2018

#Get Eco_Prov as geometry 
ecoprov <- ecoprovinces()$geometry

bc_boun<-bc_bound()$geometry


#Establish a color ramp
cols <- brewer.pal(11, "BrBG")


#Function for converting time series raster data into a table suitable for S-Mode PCA. Assumes specific formating of tile names and structure. 
rast_to_table<-function(strt_yr, end_yr, dir_string, b_num)
{
  
  #Get first year of snow melt date (Band 2 in image file) as a raster 
  s <- raster(paste(dir_string,strt_yr,'.tif',sep = ""), band=b_num)
  
  
  #Get important image metadata for generating loading images
  mod_rows<-nrow(s)
  mod_cols<-ncol(s)
  s_extent <- extent(s)
  s_rez <- res(s)
  s_crs <- crs(s)
  r <- raster(ncols=mod_cols, nrows=mod_rows)
  extent(r) <- s_extent
  res(r) <- s_rez
  crs(r) <- s_crs
  
  
  
  #For each year 2000-2018, add the year to image stack 's'
  for (year in (strt_yr+1):end_yr){
    
    
    #Get the complete dir path as a string
    path<-paste(dir_string,year,'.tif',sep = "")
    
    #Read in the snow duration raster for the given year
    rast <-raster(path, band=b_num)
    
    #Add the new year to the raster stack 
    s <- stack(s,rast)
  }
  
  
  NAvalue(s) <- -9
  
  #Convert the raster data to a data frame, retain spatial coordinates 
  rast_data <-raster::as.data.frame(s, xy=TRUE)
  
  #rast_data[,c(3:ncol(rast_data))]<-rast_data[,c(3:ncol(rast_data))]/366
  
  
  rast_data <- rast_data[complete.cases(rast_data),]
  
  
  #Transpose the snow duration data frame, (i.e., columns = pixels, rows =  year) 
  rast_data <- t(rast_data)
  
  
  #Get logical of column indexes that have inter-annual varince, (i.e., not missing)
  has_var<-c(apply(rast_data[c(3:nrow(rast_data)),], 2, var) > 0)
  
  
  #Filter out cols(pixels) with varaince == 0
  rast_data<-rast_data[,has_var]
  
  #rast_data[rast_data == -9] <- 1
  
  
  #Get a data frame of the remaining Lat Lon indicies 
  lat_lon = as.data.frame(t(rast_data[c(1:2),]))
  
  #Get data frame without spatial coordinates columns 
  rast_data<-rast_data[c(3:nrow(rast_data)),]
  
  
  rtrn_lst<-list(rast_data,lat_lon,r)
  
  return(rtrn_lst)
  
}

#Get the SDoff data into S-Mode matrix form 
rast_data<-rast_to_table(2000,2018,snow_dir_path,2)


#Run PCA decompostion 
dur_pca <- prcomp(rast_data[[1]], center = TRUE, scale. = TRUE)


#Summarise the PCA results
summary(dur_pca)

#Generate a Scree-plot
std_dev <- dur_pca$sdev
pr_var <- std_dev^2
prop_varex <- (pr_var/sum(pr_var))*100

png("Manuscript/tatolatex/Figures/sdoff_scree.png")

plot(prop_varex, type = "b", xlab = "Principle Component",ylab = "Proportion of Variance Explained (%)")

dev.off()

# ggplot( data=NULL, aes(x=c(1:length(prop_varex)), y=cumsum(prop_varex))) +
#   geom_line(linetype="dashed")+
#   geom_point(size = 3) + 
#   theme_bw() +
#   labs(x = "Principle Component")+
#   labs(y = "Cumulative Proportion of Variance Explained")


#Get PCA scores
mod_scores <- as.data.frame(dur_pca$x)


#Perform k-means cluster analysis on the snow duration PCA results 
set.seed(20)
clusters <- kmeans(x=mod_scores[,c(1:18)], centers = 3, nstart = 10000)


#View score averages by cluster (Two methods, same output)
clusters

mod_scores %>% 
  dplyr::mutate(clus=clusters$cluster) %>%
  dplyr::group_by(clus) %>%
  dplyr::summarise(pc1 = mean(PC1),pc2=mean(PC2),pc3=mean(PC3),pc4=mean(PC4))


#Returns a mean image of snowduration for years specified by yr_vect
get_r_stack<-function(yr_vect,snow_dir_path,mode)
{
  i<-0
  s<-NULL
  for (year in yr_vect)
  {
    if(i==0)
    {
      s <- raster(paste(snow_dir_path,year,'.tif',sep = ""), band=2)
      
      NAvalue(s) <- -9
    }
    else
    {
      #Get the complete dir path as a string
      path<-paste(snow_dir_path,year,'.tif',sep = "")
      
      #Read in the snow duration raster for the given year
      rast <-raster(path, band=2)
      
      NAvalue(s) <- -9
      
      #Add the new year to the raster stack 
      s <- stack(s,rast)
    }
  }
  
  if(mode==1)
  {
    s_mean<-calc(s,mean)
  }
  else
  {
    s_mean<-calc(s,sd)
  }
  
  
  return(s_mean)
}

#Generate year vector over period of record 
years<-c(mod_start_year:mod_end_year)


#Get years for each cluster type
clu_1<-years[clusters$cluster==1]
clu_2<-years[clusters$cluster==2]
clu_3<-years[clusters$cluster==3]

#Get mean image for each cluster
clu_1_r<-get_r_stack(clu_1,snow_dir_path,1)
clu_1_r<-projectRaster(clu_1_r,crs = '+proj=aea +lat_1=50 +lat_2=58.5 +lat_0=45 +lon_0=-126 +x_0=1000000 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs')
clu_2_r<-get_r_stack(clu_2,snow_dir_path,1)
clu_2_r<-projectRaster(clu_2_r,crs = '+proj=aea +lat_1=50 +lat_2=58.5 +lat_0=45 +lon_0=-126 +x_0=1000000 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs')
clu_3_r<-get_r_stack(clu_3,snow_dir_path,1)
clu_3_r<-projectRaster(clu_3_r,crs = '+proj=aea +lat_1=50 +lat_2=58.5 +lat_0=45 +lon_0=-126 +x_0=1000000 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs')




#Plot image for each cluster type
jpeg("Manuscript/tatolatex/Figures/cluster1_mean.jpeg", quality =100)
plot(clu_1_r, main="Cluster 1", xlab="Easting", ylab = "Northing",col = cols)
plot(ecoprov, add=TRUE)
plot(bc_boun, add=TRUE)
dev.off()
jpeg("Manuscript/tatolatex/Figures/cluster2_mean.jpeg", quality =100)
plot(clu_2_r, main="Cluster 2" ,xlab="Easting", ylab = "Northing",col = cols)
plot(ecoprov, add=TRUE)
dev.off()
jpeg("Manuscript/tatolatex/Figures/cluster3_mean.jpeg", quality =100)
plot(clu_3_r, main="Cluster 3", xlab="Easting", ylab = "Northning",col = cols)
plot(ecoprov, add=TRUE)
dev.off()

#clu_comb<-stack(clu_1_r,clu_2_r,clu_3_r)
#plot(clu_comb, main= c("Cluster 1 Mean","Cluster 2 Mean","Cluster 3 Mean"), box=FALSE)



#Function for wrting loading to CSV with x,y,z fields for import to QGIS
grid_spat_load<-function(lat_lon,rast, pca, pc_num)
{
  load<-c(pca$rotation[,pc_num])
  p<-data.frame(lat_lon, name=load)
  coordinates(p)<-~x+y
  r<-rasterize(p,rast,'name',fun=mean)
  writeRaster(r, filename=paste("Manuscript/tatolatex/Figures/","PC",pc_num,"_loading.tif", sep=""), format="GTiff", overwrite=TRUE)
  return(r)
}


#Start parrallel cluster for generating loading images (Optional)
cl<-makeCluster(4)
registerDoParallel(cl)


mod_load_imgs<-foreach(pc=1:4, .packages = 'raster') %dopar% + grid_spat_load(rast_data[[2]],rast_data[[3]],dur_pca,pc)


pc1_ld<-mod_load_imgs[[1]][[1]]
pc1_ld<-projectRaster(pc1_ld,crs = '+proj=aea +lat_1=50 +lat_2=58.5 +lat_0=45 +lon_0=-126 +x_0=1000000 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs')
pc2_ld<-mod_load_imgs[[2]][[1]]
pc2_ld<-projectRaster(pc2_ld,crs = '+proj=aea +lat_1=50 +lat_2=58.5 +lat_0=45 +lon_0=-126 +x_0=1000000 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs')
pc3_ld<-mod_load_imgs[[3]][[1]]
pc3_ld<-projectRaster(pc3_ld,crs = '+proj=aea +lat_1=50 +lat_2=58.5 +lat_0=45 +lon_0=-126 +x_0=1000000 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs')
pc4_ld<-mod_load_imgs[[4]][[1]]
pc4_ld<-projectRaster(pc4_ld,crs = '+proj=aea +lat_1=50 +lat_2=58.5 +lat_0=45 +lon_0=-126 +x_0=1000000 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs')


jpeg("Manuscript/tatolatex/Figures/sdoff_pc1.jpeg", quality = 100)
plot(pc1_ld, main="PC1", xlab="Easting", ylab = "Northing",col=cols)
plot(ecoprov, add=TRUE)
plot(bc_boun, add=TRUE)
dev.off()
jpeg("Manuscript/tatolatex/Figures/sdoff_pc2.jpeg",quality = 100)
plot(pc2_ld, main="PC2", xlab="Easting", ylab = "Northing",col=cols)
plot(ecoprov, add=TRUE)
plot(bc_boun, add=TRUE)
dev.off()
jpeg("Manuscript/tatolatex/Figures/sdoff_pc3.jpeg",quality = 100)
plot(pc3_ld, main="PC3", xlab="Easting", ylab = "Northing",col=cols)
plot(ecoprov, add=TRUE)
plot(bc_boun, add=TRUE)
dev.off()
jpeg("Manuscript/tatolatex/Figures/sdoff_pc4.jpeg",quality = 100)
plot(pc4_ld, main="PC4", xlab="Easting", ylab = "Northing",col=cols)
plot(ecoprov, add=TRUE)
plot(bc_boun, add=TRUE)
dev.off()


#pc_ld_stk<-stack(pc1_ld, pc2_ld,pc3_ld,pc4_ld)
#plot(pc_ld_stk, main = c("PC1","PC2","PC3","PC4"),frame = FALSE)


stopCluster(cl)

#Add a year column 
mod_scores$Year<- (mod_start_year-1) + seq(dim(mod_scores)[1])




##########################################################################################################################################################
##########################################################################################################################################################
#Read in gridded mean monthly sea level pressure derived from NCEP Reanalysis 2 data (see prior study), run PCA on time series and plot spatial loadings.#
##########################################################################################################################################################
##########################################################################################################################################################



#Read in the NCAR Reanlysis Monthly Mean SLP data 
ncin <- nc_open(month_slp_pth)

#print attributes to console 
print(ncin)

#Get each dimension within the ncd file 
lon <- ncvar_get(ncin,"lon")
nlon <- dim(lon)

lat <- ncvar_get(ncin,"lat")
nlat <- dim(lat)

time <- ncvar_get(ncin,"time")

tunits <- ncatt_get(ncin,"time","units")
nt <- dim(time)


#Get the SLP Data 
slp <- ncvar_get(ncin,"mslp")

#Convert time vector to somthing R freindly 
time<-as.Date(time/24, origin='1800-01-01')


#Function for getting mean annual MSLP for specified period, convert to S-Mode matrix (rows = years, cols = pixels)
aggr_slp<-function(slp_first_yr, slp_last_yr,slp_start_date,slp_end_date,slp)
{
  
  slp_mean<-NULL
  
  #For each year in range specified 
  for (yr in c(slp_first_yr:slp_last_yr))
  {
    
    #Establish sub annual time period over which to aggragate 
    srt<-paste(yr,slp_start_date,sep="")
    end<-paste(yr,slp_end_date,sep="")
    
    #Get a vector of time stamps whithin subannual time period specified 
    sub_perd<-time>=srt & time<=end
    
    #Get SLP data corresponding to sub annual time period 
    year<-slp[,,sub_perd]
    
    #Get number of month within the sub-annual time period 
    months<-dim(year)[3]
    
    #Get SLP data as a vector 
    slp_vec_long <- as.vector(year)
    
    #Each column as month, row as a pixel (long form) 
    slp_mat <- matrix(slp_vec_long, nrow=nlon*nlat, ncol=months)
    
    #Calculate row means, tranpose and create data frame 
    if (yr==slp_first_yr)
    {
      slp_mean<-as.data.frame(t(apply(slp_mat,1,mean)))
    }
    
    slp_mean[yr-slp_first_yr+1,]<-t(apply(slp_mat,1,mean))
    
  }
  
  return(slp_mean)
  
}

#Get mean MSLP for summer (Jun - Aug) period 
slp_mean<-aggr_slp(slp_first_year,slp_last_year,"-06-01","-08-01",slp)


#Run PCA on each year of mean SLP over the sub-annual period 
slp_pca <- prcomp(slp_mean, center = TRUE, scale. = TRUE)

#Summarise the MSLP PCA
summary(slp_pca)

#Generate a Scree-plot
std_dev <- slp_pca$sdev
pr_var <- std_dev^2
prop_varex <- (pr_var/sum(pr_var))*100
png("Manuscript/tatolatex/Figures/mslp_scree.jpeg")

plot(prop_varex, type = "b", xlab = "Principle Component",ylab = "Proportion of Variance Explained (%)")

dev.off()


#Get the PCA scores as data frame 
slp_scores<-as.data.frame(slp_pca$x)


#Create a year field 
slp_scores$Year<- (slp_first_year-1) + seq(dim(slp_scores)[1])

#Get observations during and after 2000 (MODIS record start)
sub_slp_scores<-slp_scores[slp_scores$Year>=mod_start_year,]

#Add the sdoff cluster vector to MSLP PC score table 
reg_tab<-as.data.frame(cbind(sub_slp_scores, clusters$cluster))

#Convert to factor 
reg_tab$y_clust<- as.factor(reg_tab$`clusters$cluster`)
reg_tab$`clusters$cluster`<-NULL

#Get a vector of PC's that explain 1% or more of total variance
retain<-sum(summary(slp_pca)$importance[2,]>=0.01)



#Varibles for keeping track of best model (based of LOOCV classification accuracy)
best_mod_scr<-0.0
best_mod<-NULL
best_idx<-NULL


#Permuate LDA models with 6 inputs 
for (e in c(1:retain))
{
  print(e)
  for (g in c(e:retain))
  {
    for(h in c(g:retain))
    {
      for(i in c(h:retain))
      {
        for (j in c(i:retain))
        {
          for (k in c(j:retain))
          {
            
            if( e!=g & e!=h & e!=i & e!=j &  e!=k & g!=h & g!=i & g!=j & g!=k & h!=i & h!=j & h!=k & i!=j & i!=k & j!=k)
            {
              
              f<-paste0("PC",e,"+","PC",g,"+","PC",h,"+","PC",i,"+","PC",j,"+","PC",k, collapse = "+")
              f<-paste("reg_tab$y_clust ~",f)
              
              
              test <- lda(as.formula(f), data = reg_tab, CV=TRUE)
              
              
              mu<-mean(reg_tab$y_clust== test$class)
              
              if(mu>best_mod_scr)
              {
                best_mod_scr<-mu
                best_mod<-f
                
              }
            }
          }
        }
      }
    }
  }
}


model<-lda(as.formula(best_mod),data = reg_tab, CV=TRUE)

error<-mean(reg_tab$y_clust == model$class)

error

#Fit and print the LDA model results 
model<-lda(as.formula(best_mod),data = reg_tab)
model


x=lm(cbind(PC1,PC6,PC14,PC15,PC17,PC24)~y_clust, reg_tab)
lda_can<-candisc(x, term="y_clust")

coef_std<-as.data.frame(lda_can$coeffs.std)
lda_can$coeffs.raw


png("Manuscript/tatolatex/Figures/loadingplot.png")
plot(Can2~Can1, data = as.data.frame(coef_std), xlim=c(-1.2,1.2), ylim=c(-1.2,1.2), xlab = "LD1 Coefficient", ylab="LD2 Coefficient", main="LDA Loading Plot")
text(coef_std$Can1,coef_std$Can2, labels = row.names(coef_std), pos = 3)
abline(v=0, lty=2)
abline(h=0, lty=2)
dev.off()



png("Manuscript/tatolatex/Figures/scoreplot.jpeg")
plot(model, main = "LDA Score Plot")
dev.off()

#Generate confusionMatrix
model<-lda(as.formula(best_mod),data = reg_tab, CV=TRUE)
ob<-reg_tab$y_clust
yhat<-model$class
table(ob,yhat)


#Get PCA loadings 
slp_loadings <- slp_pca$rotation

#Manually specify model vector
m_vect<-c(1,6,14,15,17,24)

#Get a specific loading, reshape to orignal geospatial extent 
loading_lst<-list()
cnt<-1


#Generate a list of MSLP loading rasters for each model input
for (ld in m_vect)
{
  
  pc_load <- slp_loadings[,ld]
  pc_load_mat <- matrix(pc_load, nrow = nlat, byrow = TRUE)
  pc_load_ras <- raster(pc_load_mat)
  extent(pc_load_ras) <- c(-180.0, 180.0, -90.0, 90.0)
  res(pc_load_ras) <- c((360.0/nlon),(180.0/nlat) )
  crs(pc_load_ras) <- "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"
  
  loading_lst[[cnt]]<-pc_load_ras
  cnt<-cnt+1
  
}


#Make plots of loading rasters ...

#download.file("http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/physical/ne_10m_coastline.zip", destfile = 'coastlines.zip')

#unzip(zipfile = "coastlines.zip", exdir = 'ne-coastlines-10m')

coastlines <- st_read("ne-coastlines-10m/ne_10m_coastline.shp")$geometry

jpeg("Manuscript/tatolatex/Figures/mslp_pc1.jpeg",quality = 100)
plot(loading_lst[[1]], main = "MSLP PC1",xlab = 'Longitude',ylab='Latitude', box=FALSE,col = cols,xlim=c(-180,180), ylim=c(-90,90), asp=2)
plot(coastlines, add=TRUE)
dev.off()

jpeg("Manuscript/tatolatex/Figures/mslp_pc6.jpeg", quality = 100)
plot(loading_lst[[2]], main = "MSLP PC6",xlab = 'Longitude',ylab='Latitude', box=FALSE,col = cols,xlim=c(-180,180), ylim=c(-90,90), asp=2)
plot(coastlines, add=TRUE)
dev.off()

jpeg("Manuscript/tatolatex/Figures/mslp_pc14.jpeg", quality = 100)
plot(loading_lst[[3]], main = "MSLP PC14",xlab = 'Longitude',ylab='Latitude', box=FALSE,col = cols,xlim=c(-180,180), ylim=c(-90,90), asp=2)
plot(coastlines, add=TRUE)
dev.off()

jpeg("Manuscript/tatolatex/Figures/mslp_pc15.jpeg", quality = 100)
plot(loading_lst[[4]], main = "MSLP PC15",xlab = 'Longitude',ylab='Latitude', box=FALSE,col = cols,xlim=c(-180,180), ylim=c(-90,90), asp=2)
plot(coastlines, add=TRUE)
dev.off()

jpeg("Manuscript/tatolatex/Figures/mslp_pc17.jpeg", quality = 100)
plot(loading_lst[[5]], main = "MSLP PC17",xlab = 'Longitude',ylab='Latitude', box=FALSE,col = cols,xlim=c(-180,180), ylim=c(-90,90), asp=2)
plot(coastlines, add=TRUE)
dev.off()

jpeg("Manuscript/tatolatex/Figures/mslp_pc24.jpeg", quality = 100)
plot(loading_lst[[6]], main = "MSLP PC24",xlab = 'Longitude',ylab='Latitude', box=FALSE,col = cols,xlim=c(-180,180), ylim=c(-90,90), asp=2)
plot(coastlines, add=TRUE)
dev.off()



# 
# #View Loading on Map
# # plot(pc_load_ras)
# # mapview::mapView(pc_load_ras)
# out<-'/home/huntergleason/Dropbox/FLNRO/Projects/LDA_MOD_SnowDur/Figures/slp_loadings/SLP_PC17.tif'
# writeRaster(loading_lst[[6]], filename=out, format="GTiff", overwrite=TRUE)
# 
# 
# mean_pc1pc24<-mean(loading_lst[[1]],loading_lst[[6]])
# mean_pc14pc17<-mean(loading_lst[[3]],loading_lst[[5]])
# 
# diff<-mean_pc1pc24-mean_pc14pc17
# 
# plot(abs(diff),box=FALSE, main = "LD1 Sea Level Pressure Contrast")
# plot(coastlines, add=TRUE)
# pol <- rasterToPolygons(abs(diff), fun=function(x){x>quantile(abs(diff),.95)}, dissolve = TRUE)
# plot(pol, add=TRUE)
# 
# diff<-loading_lst[[1]]-loading_lst[[5]]
# 
# plot(abs(diff),box=FALSE, main = "LD2 Sea Level Pressure Contrast")
# plot(coastlines, add=TRUE)
# pol <- rasterToPolygons(abs(diff), fun=function(x){x>quantile(abs(diff),.95)}, dissolve = TRUE)
#plot(pol, add=TRUE)
