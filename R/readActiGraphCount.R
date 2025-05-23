readActiGraphCount = function(filename = NULL,
                            timeformat = "%m/%d/%Y %H:%M:%S",
                            desiredtz = "",
                            configtz = NULL,
                            timeformatName = "timeformat") {
  if (length(configtz) == 0) configtz = desiredtz
  # In GGIR set timeformatName to extEpochData_timeformat
  deviceSerialNumber = NULL
  
  # Test if file has header by reading first ten rows
  # and checking whether it contains the word
  # serial number.
  headerAvailable = FALSE
  header = data.table::fread(
    input = filename,
    header = FALSE,
    nrows = 10,
    data.table = FALSE,
    sep = ","
  )
  if (nrow(header) < 10) {
    stop(paste0("File ", filename, " cannot be processed because it has less than ten rows"))
  }
  splitHeader = function(x) {
    tmp = unlist(strsplit(x, " "))
    item = gsub(
      pattern = ":| ",
      replacement = "",
      x = paste0(tmp[1:(length(tmp) - 1)], collapse = "")
    )
    df = data.frame(item = tolower(item), value = tmp[length(tmp)])
    return(df)
  }
  fileHeader = NULL
  for (hh in header[2:9,1]) {
    fileHeader = rbind(fileHeader, splitHeader(hh))
  }
  if (any(grepl("serialnumber", fileHeader$item))) headerAvailable = TRUE
  
  # Depending on whether header is present assign number of rows to skip:
  mode = NULL
  if (headerAvailable == TRUE) {
    skip = 10
    # Extract mode number from header because this tells us how to interpret the columns
    mode = as.numeric(fileHeader$value[grep(pattern = "mode", x = fileHeader$item)])
    if (is.na(mode)) mode = NULL
  } else {
    tmp = data.table::fread(input = filename,
                            header = FALSE,
                            data.table = FALSE,
                            skip = 0,
                            nrows = 1)
    if (any(grepl("data|scoring", tmp[1,]))) {
      skip = 1
    } else {
      skip = 0
    }
  }
  
  # Check if file was exported with column names:
  colnames = FALSE
  colnames_test = data.table::fread(input = filename,
                                    header = FALSE,
                                    data.table = FALSE,
                                    skip = skip,
                                    nrows = 1)
  if (any(grepl("Axis|vector magnitude|vm", colnames_test[1,], ignore.case = TRUE))) {
    colnames = TRUE
  }
  # Increment skip if column names are present
  Dtest = data.table::fread(input = filename,
                            header = colnames,
                            data.table = FALSE,
                            skip = skip, nrows = 1)
  if (length(grep(pattern = "time|date", x = Dtest[1, 1], ignore.case = TRUE)) > 0) {
    skip = skip + 1
  }
  # Read all data from file
  D = data.table::fread(input = filename,
                        header = colnames,
                        data.table = FALSE,
                        skip = skip)
  
  # Ignore time and date column if present
  D = D[, grep(pattern = "time|date", x = Dtest[1, ], ignore.case = TRUE, invert = TRUE), drop = FALSE]
  D = D[, grep(pattern = "time|date", x = colnames(Dtest), ignore.case = TRUE, invert = TRUE), drop = FALSE]
  if (inherits(x = D[1,1], what = "POSIXt")) {
    D = D[, -1, drop = FALSE]
  }
  # Identify columns with count data
  acccol = NA
  stepcol = NULL
  if (colnames == TRUE) {
    acccol = grep("axis|activity", colnames(D), ignore.case = TRUE)
    vmcol = grep("vector magnitude|vm", colnames(D), ignore.case = TRUE)
    stepcol = grep("step", colnames(D), ignore.case = TRUE)
  } else {
    if (!is.null(mode)) {
      if ((mode >= 12 && mode <= 15) | (mode >= 28 && mode <= 31) |
          (mode >= 44 && mode <= 47) | (mode >= 60 && mode <= 63)) {
        acccol = 1:3
      } else {
        acccol = 1
      }
      if (mode %in% c(13, 15, 29, 31, 45, 47, 61, 63)) {
        stepcol = 4
      }
    } else {
      # Then assume first 3 columns are axis1, axis2, axis3 if ncol(D) >= 3
      # First column is VM if ncol(D) < 3
      # Note that in ActiLife software the user can select
      # the columns to export (e.g, it could be "Axis1", "Vector Magnitude", "Steps")
      # which may mean that our assumptions here are not necessarily true.
      if (ncol(D) >= 3) {
        acccol = 1:3
      } else {
        acccol = 1
      }
    }
  }
  # Assign colnames and formatting
  if (length(acccol) == 3 && is.na(acccol[1]) == FALSE) { 
    colnames(D)[acccol] = c("y", "x", "z") # ActiGraph always stores y axis first
  }
  if (length(acccol) == 1 &&is.na(vmcol[1]) == FALSE) { 
    D = as.matrix(D, drop = FALSE) # Convert to matrix as data.frame will auto-collapse to vector
    colnames(D)[acccol] = "vm"
  }
  if (length(stepcol) == 1 && is.na(stepcol[1]) == FALSE) { 
    colnames(D)[stepcol] = "steps"
  }
  keep = c(acccol, stepcol)[!is.na(c(acccol, stepcol))]
  D = D[, keep, drop = FALSE]
  if (ncol(D) >= 3) {
    D$vm = sqrt(D[, 1] ^ 2 + D[, 2] ^ 2 + D[, 3] ^ 2)
  }
  # Extract information from header, if present
  if (headerAvailable == TRUE) {
    deviceSerialNumber = fileHeader$value[grep(pattern = "serialnumber", x = fileHeader$item)]
    epochSize = fileHeader$value[grep(pattern = "epochperiod|cycleperiod", x = fileHeader$item)]
    epSizeShort = sum(as.numeric(unlist(strsplit(epochSize, ":"))) * c(3600, 60, 1))
    starttime = fileHeader$value[grep(pattern = "starttime", x = fileHeader$item)]
    startdate = fileHeader$value[grep(pattern = "startdate", x = fileHeader$item)]
    timestamp = paste0(startdate, " ", starttime)
    timestamp_POSIX = as.POSIXct(timestamp, tz = configtz,
                                 format = timeformat)
  } else if (headerAvailable == FALSE) {
    # Extract date/timestamp from first values of column
    tmp = data.table::fread(input = filename,
                            header = colnames,
                            data.table = FALSE,
                            skip = skip,
                            nrows = 2)
    if (colnames == TRUE) {
      datecol = grep("date", colnames(tmp), ignore.case = TRUE)
      timecol = grep("time|epoch", colnames(tmp), ignore.case = TRUE)
      timestamp = paste0(tmp[, datecol], " ", tmp[1, timecol])
      format = timeformat
      timestamp_POSIX = as.POSIXct(timestamp, tz = configtz, format = format)
      if (all(is.na(timestamp_POSIX))) {
        stop(paste0("\nTimestamps are not available in the file, neither has",
                    " it a header to extract the timestamps from. Therefore, the file",
                    " cannot be processed.\n"))
      }
      epochSize = difftime(timestamp_POSIX[2], timestamp_POSIX[1], 
                           units = "secs")
      epSizeShort = as.numeric(epochSize)
      timestamp_POSIX = timestamp_POSIX[1] # startTime
    }
  }
  # Check timestamp is meaningful
  checkTimeFormat(timestamp_POSIX = timestamp_POSIX, rawValue = timestamp[1],
                  timeformat = timeformat,
                  timeformatName = timeformatName)

  
  # Establish starttime in the correct timezone
  if (configtz != desiredtz) {
    timestamp_POSIX = as.POSIXct(x = as.numeric(timestamp_POSIX), tz = desiredtz,
                                 origin = "1970-01-01")
  }

  invisible(list(data = D, epochSize = epSizeShort,
                 startTime = timestamp_POSIX,
                 deviceSerialNumber = deviceSerialNumber))
}