##To start, put all the files you want to process in one folder. 
#After calling this script on the command line, provide the folder path as an external argument

#load required packages
packages <- c("ggplot2","grDevices")
lapply(packages,library,character.only=TRUE)

#turn command line arguments into character vector
args = commandArgs(trailingOnly=TRUE)

#name folder where your raw asc files want to process are
ascDir <- args[1]
#name folder where want your slant corrected data in csv format to be stored (folder doesn't need to exist yet!)
csvDir <- args[2]
#name folder where want your chromatogram plots in png format to be stored (doesn't need to exist yet either)
pngDir <- args[3]

#checks if a folder for containing slant corrected data output called csvDir exists. If it doesn't, it creates one.
if (file.exists(csvDir)) {
} else {
    dir.create(csvDir)
}
#checks if folder to contain chromatogram plot output called pngDir exists. If it doesn't, it creates it.
if (file.exists(pngDir)) {
} else {
    dir.create(pngDir)
}


rawGPCFilenameList = list.files(path=ascDir, pattern="*.asc")

for (i in 1:length(rawGPCFilenameList)) { 
	print(paste("Processing: ", rawGPCFilenameList[i],sep=""))

	# Figure out what output .csv filename will be
	# (replace ASC with csv, eg. 0YX0A/csv)	
	outputCsvPath <- sub("asc","csv",paste(csvDir, "/", rawGPCFilenameList[i],sep=""),fixed=TRUE)
	
    print(paste("Checking for existence of output file:",outputCsvPath))
	# Check if csv filename exists
	# If it does, skip to next turn around the for loop
	if (file.exists(outputCsvPath)){
		print("Output file already exists")
		next
	} else {
		# If it doesn't, read in the file and process it:
		print("No output file present, processing file")
        #read asc file
		fromASC <- read.table(paste(ascDir,"/",rawGPCFilenameList[i],sep=""), skip=16)
        #convert table to vector 
		vectorValues <- fromASC[[1]]
		
		# Do some math to slant correct the vector of values:
		#take average first 50 rows. 
		first50avg <- mean(vectorValues[1:50])
		#take average last 50 rows (either 850-900 or 1090-1140). 
		last50avg <- mean(vectorValues[(length(vectorValues)-50):length(vectorValues)])	
		#Calculate the slant (avg last 50 minus avg first 50).
		slant <- last50avg - first50avg
		#Calculate slant avg per time (slant divided by total reads). 
		SlantAvgPerTime <- slant/length(vectorValues) 
		#Generate vector slant avg reads (avg first 50 plus slant avg per time... until last row)
		SlantAvgReads <- vector(length=length(vectorValues))
		for (j in 1:length(vectorValues)) {
			SlantAvgReads[j] <- first50avg + SlantAvgPerTime*(j-1)
		}

		#slant corrected vector (original read minus slant avg read)
		SlantCorrectedReads <- vectorValues - SlantAvgReads
		#time column (5/60 or 4/60 increments)
		time <- vector(length=length(SlantCorrectedReads))
		increment <- 75/length(SlantCorrectedReads)
		for (j in 1:length(SlantCorrectedReads)) {
            time[j] <- increment + (increment*(j-1))
		}
        

		# Bind time and SlantCorrectedReads columns into matrix
		SlantCorrectedGPC <- cbind(time, SlantCorrectedReads)

		# Save data to csv filename we figured out earlier
		write.table(SlantCorrectedGPC, file=outputCsvPath, quote=FALSE, sep=",",row.names=FALSE,col.names=TRUE)
		print("output file:")
		print(outputCsvPath)

		# Figure out png filename (eg. 0YX0A.png)
		outputPngPath <- sub("asc","png",paste(pngDir, "/", rawGPCFilenameList[i],sep=""),fixed=TRUE)
		print("output png file:")
		print(outputPngPath)

		# Plot data and save it to png
        SlantCorrectedGPC <- as.data.frame(SlantCorrectedGPC)
        main_title <- sub(".asc", "", rawGPCFilenameList[i], fixed=TRUE)
		
        png(filename=outputPngPath,width=60,height=60,units="mm",res=900)
		p <- ggplot(SlantCorrectedGPC,aes(x=time,y=SlantCorrectedReads)) + geom_point(color="blue4",pch=20,size=0.6) + theme_bw() + labs(x="Time",y="mV",title=main_title) + theme(panel.grid=element_blank(),axis.text=element_text(size=7),axis.title=element_text(size=7),plot.title=element_text(face="bold",size=6))
		print(p)
        dev.off()
	}
}