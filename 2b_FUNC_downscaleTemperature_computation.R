
rm(list=ls())
library(raster)
library(rgdal)

# path.to.data = "C:/Users/gueguen/Documents/CLIMATE_DOWNSCALING/"
# path.to.SAGA = "C:/Program Files (x86)/SAGA-GIS/"
path.to.data = "/media/gueguen/equipes/emabio/GIS_DATA/CHELSA_DOWNSCALING/"
path.to.SAGA = path.to.data

setwd(path.to.data)
zone_name.clouds = "World" ## DO NOT CHANGE !
zone_name.tempCHELSA = "World" ## DO NOT CHANGE !
zone_name.tempERA = "World" ## DO NOT CHANGE !
proj.res.clouds = 6000 ## DO NOT CHANGE !
proj.res.tempCHELSA = 4000 ## DO NOT CHANGE !
proj.res.tempERA = "100000" ## DO NOT CHANGE !

zone_name = "Bauges" #"Lautaret"
DEM_name = "DEM/DEM_Bauges.img"
DEM_ras = raster(DEM_name)
proj.res = unique(res(DEM_ras))
proj.name = "Mercator"
proj.value = "+proj=merc +lon_0=0 +k=1 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs "
setwd(path.to.SAGA)


###################################################################
### REPROJECT INPUT data (must be a conserving angle projection !!)
###################################################################

### DEM
input.name = DEM_name
output.name = sub(basename(input.name), paste0("DEM_", zone_name, "_", proj.name, "_resolution", proj.res,".sgrd"), input.name)
DEM_name = output.name

if (!file.exists(paste0(path.to.data, output.name)))
{
  cat("\n ==> Reproject DEM into ", proj.name, " projection and .sgrd file \n")

  system.command = paste0("saga_cmd pj_proj4 3 -CRS_PROJ4="
                          , paste0("\"", proj.value, "\"")
                          , " -SOURCE="
                          , paste0("\"", path.to.data, input.name, "\"")
                          , " -GRIDS="
                          , paste0("\"", path.to.data, output.name, "\"")
                          , " -TARGET_USER_SIZE="
                          , unique(proj.res)
                          , " -RESAMPLING=3") ## B-spline interpolation
  
  system(system.command)
}


###################################################################
### CLIP INPUT data
###################################################################

DEM_ras = raster(readGDAL(paste0(path.to.data, sub(extension(DEM_name), ".sdat", DEM_name))))

new.folder.name = paste0("../", zone_name, "_", proj.name, "_resolution", proj.res.clouds, "/")
if (!dir.exists(paste0(path.to.data, "CLOUDS/RAW/", new.folder.name)))
{
  dir.create(paste0(path.to.data, "CLOUDS/RAW/", new.folder.name))
}

### Monthly cloud coverage
for (mm in 1:12)
{
  cat("\n ==> Clip EarthEnv clouds coverage for month ", mm, "\n")
  
  input.name = paste0("CLOUDS/", zone_name.clouds, "_", proj.name, "_resolution", proj.res.clouds, "/")
  input.name = paste0(input.name, "CLOUDS_", zone_name.clouds, "_", proj.name, "_resolution", proj.res.clouds, "_", mm, ".sgrd")
  new.file.name = paste0("CLOUDS_", zone_name, "_", proj.name, "_resolution", proj.res.clouds, "_", mm, ".sgrd")
  output.name = sub(
    basename(input.name),
    paste0(new.folder.name, new.file.name),
    input.name
  )
  
  if (!file.exists(paste0(path.to.data, output.name)))
  {
    system.command = paste0("saga_cmd grid_tools 31 -GRIDS="
                            , paste0("\"", path.to.data, input.name, "\"")
                            , " -CLIPPED="
                            , paste0("\"", path.to.data, output.name, "\"")
                            , " -EXTENT=0 -XMIN="
                            , extent(DEM_ras)[1]
                            , " -XMAX="
                            , extent(DEM_ras)[2]
                            , " -YMIN="
                            , extent(DEM_ras)[3]
                            , " -YMAX="
                            , extent(DEM_ras)[4])
    system(system.command) 
  }
}

###################################################################
### GEOGRAPHICALLY weighted regression
###################################################################

clouds.folder.name = paste0("CLOUDS/", zone_name, "_", proj.name, "_resolution", proj.res.clouds, "/")
new.folder.name = paste0("CLOUDS/", zone_name, "_", proj.name, "_resolution", proj.res, "/")
if (!dir.exists(paste0(path.to.data, new.folder.name)))
{
  dir.create(paste0(path.to.data, new.folder.name))
}

### Monthly cloud coverage in function of DEM
for (mm in 1:12)
{
  cat("\n ==> GWR of EarthEnv clouds coverage in function of DEM for month ", mm, "\n")
  
  predic.name = DEM_name
  
  clouds.file.name = paste0("CLOUDS_", zone_name, "_", proj.name, "_resolution", proj.res.clouds, "_", mm, ".sgrd")
  input.name = paste0(clouds.folder.name, clouds.file.name)
  output.name = sub(proj.res.clouds, proj.res, clouds.file.name)
  output.name.1 = paste0(new.folder.name, sub(extension(output.name), "_regression.sgrd", output.name))
  output.name.2 = paste0(new.folder.name, sub(extension(output.name), "_regression_rescorr.sgrd", output.name))
  
  if (!file.exists(paste0(path.to.data, output.name.1)))
  {
    system.command = paste0("saga_cmd statistics_regression 14 -PREDICTORS="
                            , paste0("\"", path.to.data, predic.name, "\"")
                            , " -REGRESSION="
                            , paste0("\"", path.to.data, output.name.1, "\"")
                            , " -REG_RESCORR="
                            , paste0("\"", path.to.data, output.name.2, "\"")
                            , " -DEPENDENT="
                            , paste0("\"", path.to.data, input.name, "\""))
    
    system(system.command) 
  }
}


###################################################################
### CLIP and REPROJECT INPUT data
###################################################################

new.folder.name = paste0("../", zone_name, "_", proj.name, "_resolution", proj.res, "/")
if (!dir.exists(paste0(path.to.data, "TEMPERATURE/RAW/", new.folder.name)))
{
  dir.create(paste0(path.to.data, "TEMPERATURE/RAW/", new.folder.name))
}

### CHELSA Temperature : mean, max, min
for (mm in 1:12)
{
  for (i in 1:3)
  {
    cat("\n ==> Clip and downscale CHELSA ", c("MEAN","MAX","MIN")[i], "temperature for month ", mm, "\n")
    
    input.name = paste0("TEMPERATURE/", zone_name.tempCHELSA, "_", proj.name, "_resolution", proj.res.tempCHELSA, "/")
    input.name = paste0(input.name, "TEMP_", c("MEAN","MAX","MIN")[i], "_", zone_name.tempCHELSA, "_", proj.name, "_resolution", proj.res.tempCHELSA, "_", mm, ".sgrd")
    new.file.name = paste0("TEMP_", c("MEAN","MAX","MIN")[i], "_", zone_name, "_", proj.name, "_resolution", proj.res, "_", mm, ".sgrd")
    output.name = sub(
      basename(input.name),
      paste0(new.folder.name, new.file.name),
      input.name
    )
    
    if (!file.exists(paste0(path.to.data, output.name)))
    {
      system.command = paste0("saga_cmd grid_tools 0 -INPUT="
                              , paste0("\"", path.to.data, input.name, "\"")
                              , " -OUTPUT="
                              , paste0("\"", path.to.data, output.name, "\"")
                              , " -SCALE_DOWN=3"
                              , " -TARGET_DEFINITION=1"
                              , " -TARGET_TEMPLATE="
                              , paste0("\"", path.to.data, DEM_name, "\""))
      
      system(system.command) 
    }
  }
}

###################################################################
### SKY VIEW FACTOR
###################################################################

### DEM
input.name = DEM_name
output.name.vis = sub(extension(input.name), "_VISIBLE.sgrd", input.name)
output.name.svf = sub(extension(input.name), "_SVF.sgrd", input.name)

if (!file.exists(paste0(path.to.data, output.name.svf)))
{
  cat("\n ==> Calculating sky view factor \n")
  
  system.command = paste0("saga_cmd ta_lighting 3 -DEM="
                          , paste0("\"", path.to.data, input.name, "\"")
                          , " -VISIBLE="
                          , paste0("\"", path.to.data, output.name.vis, "\"")
                          , " -SVF="
                          , paste0("\"", path.to.data, output.name.svf, "\""))
  
  system(system.command)
}


###################################################################
### LAPSE RATE
###################################################################

tempERA.folder.name = paste0("../", zone_name.tempERA, "_", proj.name,"_resolution", proj.res.tempERA, "/")
new.folder.name = paste0("../", zone_name, "_", proj.name,"_resolution", proj.res, "/")
if (!dir.exists(paste0(path.to.data, "LAPSE_RATE/RAW/", new.folder.name)))
{
  dir.create(paste0(path.to.data, "LAPSE_RATE/RAW/", new.folder.name))
}

### Monthly temperature with model levels
for (mm in 1:12)
{
  cat("\n ==> Clip and downscale lapse-rate for month ", mm, "\n")

  new.file.name = paste0("LAPSE_RATE_", zone_name.tempERA, "_", proj.name, "_resolution", proj.res.tempERA, "_", mm, ".sgrd")
  input.name = paste0("LAPSE_RATE/RAW/", tempERA.folder.name, new.file.name)
  input.name = sub(extension(input.name), "_coeff2.sgrd", input.name)
  
  new.file.name = paste0("LAPSE_RATE_", zone_name, "_", proj.name, "_resolution", proj.res, "_", mm, ".sgrd")
  output.name = paste0("LAPSE_RATE/RAW/", new.folder.name, new.file.name)
  output.name = sub(extension(output.name), "_coeff2.sgrd", output.name)
  
  if (!file.exists(paste0(path.to.data, output.name)))
  {
    system.command = paste0("saga_cmd grid_tools 0 -INPUT="
                            , paste0("\"", path.to.data, input.name, "\"")
                            , " -OUTPUT="
                            , paste0("\"", path.to.data, output.name, "\"")
                            , " -SCALE_DOWN=3"
                            , " -TARGET_DEFINITION=1"
                            , " -TARGET_TEMPLATE="
                            , paste0("\"", path.to.data, DEM_name, "\""))

    system(system.command)
  }
}

###################################################################
### SOLAR RADIATION
###################################################################

new.folder.name = paste0("SOLAR_RADIATION/", zone_name, "_", proj.name,"_resolution", proj.res, "/")
if (!dir.exists(paste0(path.to.data, new.folder.name)))
{
  dir.create(paste0(path.to.data, new.folder.name))
}

input.name.dem = DEM_name
input.name.svf = sub(extension(input.name.dem), "_SVF.sgrd", input.name.dem)

for (mm in 1:12)
{
  cat("\n ==> Calculate solar radiation for month ", mm, "\n")

  nb.days = nrow(as.data.frame(seq.POSIXt(from = ISOdate(2018, mm, 1),
                                          to = ISOdate(ifelse(mm == 12, 2019, 2018), ifelse(mm == 12, 1, mm + 1), 1),
                                          by = "day"))) - 1
  output.name.direct = paste0(new.folder.name, "DirectRad_", zone_name, "_", proj.name,"_resolution", proj.res, "_", mm, ".sgrd")
  output.name.diffus = paste0(new.folder.name, "DiffuseRad_", zone_name, "_", proj.name,"_resolution", proj.res, "_", mm, ".sgrd")
  output.name.total = paste0(new.folder.name, "TotalRad_", zone_name, "_", proj.name,"_resolution", proj.res, "_", mm, ".sgrd")
  
  if (mm<=9) mm = paste0("0",mm)
  system.command = paste0("saga_cmd ta_lighting 2 -GRD_DEM="
                          , paste0("\"", path.to.data, input.name.dem, "\"")
                          , " -GRD_SVF="
                          , paste0("\"", path.to.data, input.name.svf, "\"")
                          , " -GRD_DIRECT="
                          , paste0("\"", path.to.data, output.name.direct, "\"")
                          , " -GRD_DIFFUS="
                          , paste0("\"", path.to.data, output.name.diffus, "\"")
                          , " -GRD_TOTAL="
                          , paste0("\"", path.to.data, output.name.total, "\"")
                          , " -LOCATION=1 -PERIOD=2 -DAY=2018-", mm,"-1 -DAY_STOP=2018-", mm,"-", nb.days
                          , " -DAYS_STEP=1")
  
  system(system.command)
}


###################################################################
### SOLAR RADIATION corrected by clouds
###################################################################

solar.folder.name = paste0("SOLAR_RADIATION/", zone_name, "_", proj.name,"_resolution", proj.res, "/")
clouds.folder.name = paste0("CLOUDS/", zone_name, "_", proj.name,"_resolution", proj.res, "/")
input.name.dem = DEM_name

setwd(path.to.data)
input.lai = raster(readGDAL(sub(".sgrd", ".sdat", input.name.dem)))
input.lai[] = 0.01
names(input.lai) = sub("DEM_", "LAI_", basename(DEM_name))
input.name.lai = sub(basename(DEM_name), sub("DEM_", "LAI_", basename(DEM_name)), DEM_name)
writeRaster(input.lai, file = input.name.lai, dataType = "FLT4S", overwrite = TRUE)
setwd(path.to.SAGA)

for (mm in 1:12)
{
  cat("\n ==> Correct solar radiation by clouds for month ", mm, "\n")

  setwd(path.to.data)
  
  a = raster(readGDAL(paste0(solar.folder.name, "TotalRad_", zone_name, "_", proj.name,"_resolution", proj.res, "_", mm, ".sdat")))

  b.name = paste0(clouds.folder.name, "CLOUDS_", zone_name, "_", proj.name, "_resolution", proj.res, "_", mm, ".sgrd")
  b.name = sub(extension(b.name), "_regression_rescorr.sdat", b.name)
  b = raster(readGDAL(b.name))
  
  solarrad = a * (1 - 0.75 * (b / 10000) ^ 3.4)
  solarrad.name = paste0("SolarRadiation_", zone_name, "_", proj.name, "_resolution", proj.res, "_", mm, ".sgrd")
  names(solarrad) = solarrad.name
  solarrad.name = paste0(solar.folder.name, solarrad.name)
  writeRaster(solarrad, file = solarrad.name, overwrite = TRUE)
  
  # setwd(path.to.SAGA)
  #
  # cat("\n ==> Calculate Land Surface Temperature for month ", mm, "\n")
  #
  # # output.name = paste0("TEMPERATURE/LST_", zone_name, "_", proj.name, "_resolution", unique(res(b.ras)),"_", mm, ".sgrd")
  # # 
  # # if (!file.exists(paste0(path.to.data, output.name)))
  # # {
  # #   system.command = paste0(
  # #     "saga_cmd ta_morphometry 13 -DEM="
  # #     , paste0("\"", path.to.data, input.name.dem, "\"")
  # #     , " -SWR="
  # #     , paste0("\"", path.to.data, solarrad.name, "\"")
  # #     , " -LAI="
  # #     , paste0("\"", path.to.data, input.name.lai, "\"")
  # #     , " -LST="
  # #     , paste0("\"", path.to.data, output.name, "\"")
  # #     , " -Z_REFERENCE=2250 -T_REFERENCE=0.000000 -T_GRADIENT=0.600000 -C_FACTOR=1.000000 -LAI_MAX=2.000000"
  # #   )
  # #   system(system.command)
  # # }
  # 
  # input.name.lapse = paste0("LAPSE_RATE/ERAinterim_modelLevels_Temperature_2017_", mm, ".nc")
  # input.ras = brick(paste0(path.to.data, input.name.lapse), level=1)
  # input.name.lapse = sub(basename(input.name.lapse), paste0("LAPSE_RATE_", zone_name.temp, "_", proj.name, "_resolution", unique(res(input.ras)),"_", mm,".sgrd"), input.name.lapse)
  # input.name.lapse = sub(extension(input.name.lapse), "_coeff2.sgrd", input.name.lapse)
  # 
  # for (i in 1:3)
  # {
  #   cat("\n ==> Calculate ", c("MEAN","MAX","MIN")[i], " Land Surface Temperature for month ", mm, "\n")
  #
  #   input.name.temp = paste0("TEMPERATURE/CHELSA_", c("temp","tmax","tmin")[i], "10_", mm, "_1979-2013_V1.2_land.tif")
  #   input.ras = raster(paste0(path.to.data, input.name.temp))
  #   input.name.temp = sub(basename(input.name.temp), paste0("TEMP_", c("MEAN","MAX","MIN")[i], "_", zone_name.temp, "_", proj.name, "_resolution", unique(res(input.ras)),"_", mm,".sgrd"), input.name.temp)
  #   
  #   output.name = paste0("TEMPERATURE/LST_", c("MEAN_","MIN_","MAX_")[i], zone_name, "_", proj.name, "_resolution", unique(res(b.ras)),"_", mm, ".sgrd")
  #   
  #   if (!file.exists(paste0(path.to.data, output.name)))
  #   {
  #     system.command = paste0(
  #       "saga_cmd ta_morphometry 13 -DEM="
  #       , paste0("\"", path.to.data, input.name.dem, "\"")
  #       , " -SWR="
  #       , paste0("\"", path.to.data, solarrad.name, "\"")
  #       , " -LAI="
  #       , paste0("\"", path.to.data, input.name.lai, "\"")
  #       , " -LST="
  #       , paste0("\"", path.to.data, output.name, "\"")
  #       , " -Z_REFERENCE="
  #       , paste0("\"", path.to.data, input.name.dem, "\"")
  #       , " -T_REFERENCE="
  #       , paste0("\"", path.to.data, input.name.temp, "\"")
  #       , " -T_GRADIENT="
  #       , paste0("\"", path.to.data, input.name.lapse, "\"")
  #       , " -C_FACTOR=1.000000 -LAI_MAX=2.000000"
  #     )
  #     system(system.command)
  #   }
  # }
}