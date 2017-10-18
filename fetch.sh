#!/bin/bash

# For Linux, date -- for mac OS, gdate
DATE_BINARY="gdate"
DATE_FORMAT="%R:%S.%3N"

# Specify escape character
ESCAPE_CHAR="\x1B"	# Mac
#ESCAPE_CHAR="\e"	# Linux

# Don't change unless they change it.
BASE_URL="https://earthquake.usgs.gov/fdsnws/event/1/query.csv?"

# Your range
YEAR_START=2017
YEAR_END=2017

# How many to fetch at once, up to 20,000
BATCH_SIZE=10000

#
# You can stop customizing here.
#

# Colors
BLUE="${ESCAPE_CHAR}[34m"
BLUE_LIGHT="${ESCAPE_CHAR}[94m"
CYAN="${ESCAPE_CHAR}[36m"
CYAN_LIGHT="${ESCAPE_CHAR}[96m"
YELLOW="${ESCAPE_CHAR}[33m"
YELLOW_LIGHT="${ESCAPE_CHAR}[93m"
GRAY="${ESCAPE_CHAR}[90m"
GRAY_LIGHT="${ESCAPE_CHAR}[37m"
GREEN="${ESCAPE_CHAR}[32m"
GREEN_LIGHT="${ESCAPE_CHAR}[92m"
MAGENTA="${ESCAPE_CHAR}[35m"
MAGENTA_LIGHT="${ESCAPE_CHAR}[95m"
RESET="${ESCAPE_CHAR}[00m"

# Style to your heart's content
#BRACKET_OPEN="﹝"
BRACKET_OPEN="${ESCAPE_CHAR}${GRAY_LIGHT}﹙${ESCAPE_CHAR}${RESET}"
#BRACKET_CLOSE="﹞"
BRACKET_CLOSE="${ESCAPE_CHAR}${GRAY_LIGHT}﹚${ESCAPE_CHAR}${RESET}"

BOX_COLOR="${YELLOW}"
BOX_START="${ESCAPE_CHAR}${BOX_COLOR}┌─${ESCAPE_CHAR}${RESET}"
BOX_PAD="${ESCAPE_CHAR}${BOX_COLOR}──────────────────────────────────────────────────────${ESCAPE_CHAR}${RESET}"
BOX_LINE="${ESCAPE_CHAR}${BOX_COLOR}│${ESCAPE_CHAR}${RESET}"
BOX_END="${ESCAPE_CHAR}${BOX_COLOR}└${ESCAPE_CHAR}${RESET}"

# Fetch by year from {X..Y}
for YEAR in $(seq $YEAR_START $YEAR_END); do

	# First, some cleanup.  Touch only the pieces, not the existing whole (merged) files.
	rm -rf ${YEAR}_*.csv

	# Form time frame window we can user for this run for $YEAR
	TIME_START="${YEAR}-01-01%2000%3A00%3A00"
	TIME_END="${YEAR}-12-31%2023%3A59%3A59"

	# Reset offset for each year, starting at 1 each time.  For some reason,
	# offset of 0 causes their server to return some binary nonsense.
	OFFSET=1

	# Progress on the shell.
	DATE_NOW=$(${DATE_BINARY} +${DATE_FORMAT})
	echo -e "${BRACKET_OPEN}${GRAY_LIGHT}${DATE_NOW}${RESET}${BRACKET_CLOSE} ${BOX_START} ${YELLOW_LIGHT}${YEAR}${RESET} ${BOX_PAD}"

	# Each year, start a new iteration.  We don't see that there are more than (99*20000) earthquakes per annum, 
	# so this should be sufficient in large enough batches (5K+)
	for ITERATION in {1..99}; do

		# Form the URL and output bits for this run of batch/limit...which will have cURL output these
		# in the format YYYY_001.csv, YYYY_002.csv, etc.
		ITERATION_FILE=$(printf "%03d\n" $ITERATION)
		FILE_NAME="${YEAR}_${ITERATION_FILE}.csv"
		URL="${BASE_URL}starttime=${TIME_START}&endtime=${TIME_END}&minmagnitude=1&maxmagnitude=10&orderby=time-asc&limit=${BATCH_SIZE}&offset=${OFFSET}"

		# Stats before the fetch
		DATE_NOW=$(${DATE_BINARY} +${DATE_FORMAT})
		NEXT_OFFSET=$((OFFSET + BATCH_SIZE - 1))
		echo -e "${BRACKET_OPEN}${GRAY_LIGHT}${DATE_NOW}${RESET}${BRACKET_CLOSE} ${BOX_LINE}   〈 ${OFFSET} ➝ ${NEXT_OFFSET} 〉"

		# Have cURL fetch this and write to sequential files...silently output to $FILE_NAME
		curl -s -o ${FILE_NAME} "${URL}"

		# Some user output
		DATE_NOW=$(${DATE_BINARY} +${DATE_FORMAT})
		FILE_SIZE=$(du -ksh ${FILE_NAME} | awk '{ print $1 }')
		YEAR_FILE_SIZE=$(find . -type f -name "${YEAR}_*.csv" -exec du -ch {} + | grep total | xargs | awk '{ print $1 }')
		echo -e "${BRACKET_OPEN}${GRAY_LIGHT}${DATE_NOW}${RESET}${BRACKET_CLOSE} ${BOX_LINE}     ${MAGENTA_LIGHT}»${RESET} Wrote ${GRAY}${FILE_SIZE}${RESET} to ${GREEN}${FILE_NAME}${RESET} ${BLUE}(${RESET}${BLUE_LIGHT}year size: ~${YEAR_FILE_SIZE}${RESET}${BLUE})${RESET}"

		# Do we need a new round?  Match only the first field of the CSV to check if it's near the end
		FILE_MATCH=$(tail -n 1 ${FILE_NAME} | cut -d ',' -f1 | egrep "${YEAR}-12-[1-3][0-9]")
		if [[ ! -z $FILE_MATCH ]]; then
			# We're at or near the end.  We can break out of the loop for this year and go
			# on to the next one.
			#echo "		Last line of ${FILE_NAME} matches ${YEAR}-12-31T23:5[6-9] ...stopping for ${YEAR}"
			YEAR_FILE_SIZE=$(find . -type f -name "${YEAR}_*.csv" -exec du -ch {} + | grep total | xargs | awk '{ print $1 }')
			DATE_NOW=$(${DATE_BINARY} +${DATE_FORMAT})
			echo -e "${BRACKET_OPEN}${GRAY_LIGHT}${DATE_NOW}${RESET}${BRACKET_CLOSE} ${BOX_LINE}  ...finished ${YELLOW_LIGHT}${YEAR}${RESET} ${BLUE}(${RESET}${BLUE_LIGHT}${YEAR_FILE_SIZE} total${RESET}${BLUE})${RESET}"
			echo -e "${BRACKET_OPEN}${GRAY_LIGHT}${DATE_NOW}${RESET}${BRACKET_CLOSE} ${BOX_END}${BOX_PAD}${ESCAPE_CHAR}${YELLOW}───────${RESET}"
			break
		fi

		# Increase the limit for next time
		OFFSET=$((OFFSET + BATCH_SIZE))

	done	# /ITERATION loop

done	# /YEAR loop

# Clean line break
echo ""

# Fetch by year from {X..Y}
for YEAR in $(seq $YEAR_START $YEAR_END); do

	# Remove any previous copy.
	rm -rf ${YEAR}.csv
	
	# Start merged YYYY.csv file by using first segment wholesale
	cat ${YEAR}_001.csv > ${YEAR}.csv

	# Loop through others stripping the first line and appending.
	FILES=$(ls | egrep "${YEAR}_" | egrep -v "_001")
	for FILE in $FILES; do
		# Append $FILE to YEAR.csv minus line 1
		tail -n +2 $FILE >> ${YEAR}.csv
	done	# /FILE loop

	# Give feedback
	FILE_SIZE=$(du -ksh ${YEAR}.csv | awk '{ print $1 }')
	FILE_LINES=$(cat ${YEAR}.csv | wc -l | xargs)
	FILE_LINES=$((FILE_LINES - 1))
	echo -e "${BRACKET_OPEN}${GRAY_LIGHT}${DATE_NOW}${RESET}${BRACKET_CLOSE} Merged ${FILE_LINES} lines into ${YEAR}.csv (${FILE_SIZE})"

	# Cleanup old files
	rm -rf ${YEAR}_*.csv

done 	# /YEAR loop

DATE_NOW=$(${DATE_BINARY} +${DATE_FORMAT})
echo -e "${BRACKET_OPEN}${GRAY_LIGHT}${DATE_NOW}${RESET}${BRACKET_CLOSE} Finished 👍"
