readGENEActiv = function(filename, start = 0, end = 0, progress_bar = FALSE, 
                         desiredtz = "", configtz = NULL) {
  
  # Extract information from the fileheader
  suppressWarnings({fh = readLines(filename, 69)})
  
  SN = gsub(pattern = "Device Unique Serial Code:", replacement = "",
            x = fh[grep(pattern = "Device Unique Serial Code", x = fh)[1]])
  firmware = gsub(pattern = "Device Firmware Version:", replacement = "",
                  x = fh[grep(pattern = "Device Firmware Version", x = fh)[1]])
  Lux = as.numeric(gsub(pattern = "Lux:", replacement = "",
                  x = fh[grep(pattern = "Lux", x = fh)[1]]))
  Volts = as.numeric(gsub(pattern = "Volts:", replacement = "",
             x = fh[grep(pattern = "Volts", x = fh)[1]]))
  # We use first Page Time and not Start time from the file header
  # because start time from the file header is known to be incorrect
  # when battery runs out prior to end of recording
  starttime = gsub(pattern = "Page Time:", replacement = "",
                   x = fh[grep(pattern = "Page Time", x = fh)[1]])
  
  tzone = gsub(pattern = "Time Zone:", replacement = "",
               x = fh[grep(pattern = "Time Zone", x = fh)[1]])
  tzone = as.numeric(unlist(strsplit(tzone, "[:]| "))[2]) * 3600
  
  Handedness = gsub(pattern = "Handedness Code:", replacement = "",
            x = fh[grep(pattern = "Handedness Code", x = fh)[1]])
  ID = gsub(pattern = "Subject Code:", replacement = "",
            x = fh[grep(pattern = "Subject Code", x = fh)[1]])
  
  DeviceLocation = gsub(pattern = "Device Location Code:", replacement = "",
            x = fh[grep(pattern = "Device Location Code", x = fh)[1]])
  
  DeviceModel = gsub(pattern = " ", replacement = "",
                     x = gsub(pattern = "Device Model:", replacement = "",
                        x = fh[grep(pattern = "Device Model", x = fh)[1]]))

  # Read acceleration, lux and temperature data
  rawdata = GENEActivReader(filename = filename,
                            start = start, end = end, 
                            progress_bar = progress_bar)
  
  rawdata$time = rawdata$time / 1000
  
  # Construct header object
  header = list(serial_number = SN,
                firmware = firmware,
                tzone = tzone,
                ReadOK = rawdata$info$ReadOK,
                SampleRate = rawdata$info$SampleRate,
                ReadErrors = rawdata$info$ReadErrors,
                numBlocksTotal = rawdata$info$numBlocksTotal,
                StarTime = starttime,
                Handedness = Handedness,
                RecordingID = ID,
                DeviceLocation = DeviceLocation,
                DeviceModel = DeviceModel)
  
  s0 = unlist(strsplit(starttime, ":"))
  if (length(s0) == 4) {
    starttime = paste0(s0[1], ":", s0[2], ":", s0[3], ".", s0[4])
  }
  
  # Establish starttime in the correct timezone
  if (is.null(configtz)) {
    starttime_posix = as.POSIXlt(x = starttime, tz = desiredtz,
                                 format = "%Y-%m-%d %H:%M:%OS", origin = "1970-01-01")
  } else {
    starttime_posix = as.POSIXlt(starttime, tz = configtz,
                                 format = "%Y-%m-%d %H:%M:%OS", origin = "1970-01-01")
  }
  
  # Correct timestamps
  if (start > 1) {
    page_offset = (((start - 1) * 300) / rawdata$info$SampleRate)
  } else {
    page_offset = 0
  }
  starttime_num = as.numeric(starttime_posix) + page_offset
  rawdata$time = rawdata$time + abs(rawdata$time[1]) + starttime_num
  return(invisible(list(
    header = header,
    data.out = data.frame(time = rawdata$time, 
                      x = rawdata$x, y = rawdata$y, z = rawdata$z,
                      light = rawdata$lux * (Lux/Volts),
                      temperature = rawdata$temperature,
                      stringsAsFactors = TRUE)
  )))
}
