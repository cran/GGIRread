\name{readActiGraphCount}
\alias{readActiGraphCount}
\title{
  Read ActiGraph Count data files (csv)
}
\description{
  Reads ActiGraph Count data file. Currently a variety of csv format are facilitated.
}
\usage{
  readActiGraphCount(filename = NULL, 
                            timeformat = "\%m/\%d/\%Y \%H:\%M:\%S",
                            desiredtz = "", configtz = NULL,
                            timeformatName = "timeformat")
}
\arguments{
  \item{filename}{
    filename (required)
  }
  \item{timeformat}{
    Character, timestemp format.
  }
  \item{desiredtz}{
    Character, timezone name where the accelerometer was worn. Timezone names are
    expected to be the timezone database names, e.g. Europe/London. See also:
    https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  }
  \item{configtz}{
    Character, timezone name where the accelerometer was configured. Leave NULL
    if equal to desiredtz. Timezones name are expected to be the timezone database
    names, e.g. Europe/London. See also:
    https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  }
  \item{timeformatName}{
    Character, name of timeformat variable to print in error message when
    timeformat is incorrect, of use to GGIR where argument names can differ.
  }
}
\value{
  \item{data}{Matrix with one or multiple columns}
  \item{epochSize}{epoch size in seconds of data}
  \item{startTime}{POSIXlt format timestamp on which recording starts }
  \item{deviceSerialNumber}{Device serial number if it could be extracted 
  from the file header}
}
\author{
  Vincent T van Hees <v.vanhees@accelting.com>
}