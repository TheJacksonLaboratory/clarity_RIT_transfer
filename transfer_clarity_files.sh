#!/bin/bash

# Copy files from GT clarity server, perform checksum, notify of completion

#!/bin/bash

#SBATCH -p compute
#SBATCH --job-name=clarity_RIT_file_transfer
#SBATCH --output=clarity_RIT_file_transfer.out
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --begin=now+1day
#SBATCH --dependency=singleton
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=neil.kindlon@jax.org


# We'll want to resubmit this job when done
sbatch "$0"

/bin/echo "Beginning clarity file transfer at $(date)."

# Will email log file when completed to this list of people
MAIL_RECIPIENTS="neil.kindlon@jax.org,james.qin@jax.org"

# Setup the basic directories if needed
BASE_WORK_DIR="/projects/researchit/clarity_RIT_transfer"

LOG_DIR="$BASE_WORK_DIR/logs"

# The "slurp directory is where we will just grab and dump all the matching files we find on the 
# clarity server
SLURP_DIR="$BASE_WORK_DIR/slurp"

# We will move only the newest files to the "process" dir, where they'll be processed.
PROCESSING_DIR="$BASE_WORK_DIR/processing"

# When we're done we'll move the files to the "completed dir".
COMPLETED_DIR="$BASE_WORK_DIR/completed"

#Put these directories into an array
declare -a dir_arr=("$LOG_DIR" "$SLURP_DIR" "$PROCESSING_DIR" "$COMPLETED_DIR")

# Now create all dirs as needed
for dir in ${dir_arr[@]}
do
    echo "Creating directory $dir"
    mkdir -p "$dir"
    if [[ "$?" -ne 0 ]]
    then
        # Write to stdout, also append to stderr..
        /bin/echo "Could not create directory $dir, exiting." | /bin/tee -a /dev/stderr
        exit 10
    fi
done

LOG_FILE="$LOG_DIR/clarity_transfer_log_$(date +"%Y%m%d_%H%M%S").txt"
/bin/echo "Beginning clarity file transfer at $(date)." >> "$LOG_FILE"

# Make sure the slurp and processing dirs are empty.
declare -a dir_arr=("$SLURP_DIR" "$PROCESSING_DIR")
for dir in ${dir_arr[@]}
do
    rm -f "$dir/"*
    if [[ "$?" -ne 0 ]]
    then
        /bin/echo "Could not empty directory $dir, exiting." | /bin/tee -a "$LOG_FILE"
        exit 15
    fi
done


# Account, server, target directory, and root names of the files we'll grab.
USR="glsjboss"
REMOTE_SERVER="bhgtclarity01lp.jax.org"
REMOTE_DIR="/opt/gls/clarity/customextensions/close_sanger_seq_projects"
FILE_ROOT="closed_samples_today"

TARGET_DIR="$USR@$REMOTE_SERVER:$REMOTE_DIR/"
/bin/echo "Getting files from $TARGET_DIR"  | /bin/tee -a "$LOG_FILE"

# Change to the "slurp" dir and grab every file in the target dir matching the 
# FILE_ROOT pattern
cd "$SLURP_DIR"
scp "$TARGET_DIR/$FILE_ROOT"* . | /bin/tee -a "$LOG_FILE"


# Now we want to grab only the newest csv and md5 file and put them in the 
# PROCESSING DIR. The filenames include a timestamp, so we can just sort them
# numerically. Afterwards, delete the other files.
newest_csv=$(ls -1 *.csv | sort -rn | head -1)
newest_md5=$(ls -1 *.md5 | sort -rn | head -1)
/bin/echo "Found new files $newest_csv and $newest_md5." | /bin/tee -a "$LOG_FILE"

# See that the newest files aren't already in the COMPLETED_DIR. If they are, then
# these aren't new files, meaning we have no updates since the last time this script ran.
newest_csv_completed=$(ls "$COMPLETED_DIR/$newest_csv" 2> /dev/null | wc -l)
newest_md5_completed=$(ls "$COMPLETED_DIR/$newest_md5" 2> /dev/null | wc -l)
if [[ "$newest_csv_completed" -ne 0 ]] || [[ "$newest_md5_completed" -ne 0 ]]
then
    /bin/echo "Newest csv file $newest_csv already processed, exiting". | /bin/tee -a "$LOG_FILE"
    # Empty the slurp directory before exiting.
    rm -f *
    mail -s "No new clarity file transferred to Research IT" "$MAIL_RECIPIENTS" < "$LOG_FILE"
    exit 35
else
    /bin/echo "$newest_csv has not been previously processed". | /bin/tee -a "$LOG_FILE"
fi


mv "$newest_csv" "$PROCESSING_DIR"/.
if [[ "$?" -ne 0 ]]
then
    /bin/echo "Could not move file $newest_csv, exiting." | /bin/tee -a "$LOG_FILE"
    exit 25
fi

mv "$newest_md5" "$PROCESSING_DIR"/.
if [[ "$?" -ne 0 ]]
then
    /bin/echo "Could not move file $newest_md5, exiting." | /bin/tee -a "$LOG_FILE"
    exit 30
fi

/bin/echo "New files moved to processing directory, deleting other files."

rm *
if [[ "$?" -ne 0 ]]
then
    /bin/echo "Could not delete other files, exiting." | /bin/tee -a "$LOG_FILE"
    exit 50
fi



# Change to the processing dir, which should have exactly one md5 and one csv file
cd "$PROCESSING_DIR"
num_csv=$(ls -1 *.csv | wc -l)
num_md5=$(ls -1 *.md5 | wc -l)

if [[ "$num_csv" -ne 1 ]] || [[ "$num_md5" -ne 1 ]]
then
    /bin/echo "Did not find one and only one md5 or csv file in processing dir, exiting." | /bin/tee -a "$LOG_FILE"
fi

# Get the md5 checksum from the md5 file, and see that it matches the actual checksum of the csv file.
/bin/echo "Comparing md5 checksum of csv file." | /bin/tee -a "$LOG_FILE"
exp_md5=$(cat "$newest_md5" | cut -f1 -d ' ')
obs_md5=$(md5sum "$newest_csv" | cut -f1 -d ' ')
if [[ "$exp_md5" != "$obs_md5" ]]
then
    /bin/echo "Observed md5sum $obs_md5 does not match expected sum $exp_md5, exiting" | /bin/tee -a "$LOG_FILE"
    exit 40
else
    /bin/echo "Observed md5sum $obs_md5 matches expected md5sum $exp_md5." | /bin/tee -a "$LOG_FILE"
fi

# Now move the files to the "completed" directory
mv "$newest_md5" "$COMPLETED_DIR/."

if [[ $? -ne 0 ]]
then
    /bin/echo "Could not move $newest_md5 to completed directory, exiting." | /bin/tee -a "$LOG_FILE"
    exit 55
fi

mv "$newest_csv" "$COMPLETED_DIR/."

if [[ $? -ne 0 ]]
then
    /bin/echo "Could not move $newest_csv to completed directory, exiting." | /bin/tee -a "$LOG_FILE"
    exit 60
fi

/bin/echo "Moved new files $newest_csv and $newest_md5 to $COMPLETED_DIR." | /bin/tee -a "$LOG_FILE"
/bin/echo "Transfer and checksum completed at $(date)" | /bin/tee -a "$LOG_FILE"


# Cleanup the processing directory
rm -f *
if [[ $? -ne 0 ]]
then
    /bin/echo "Could not empty the processing directory, exiting." | /bin/tee -a "$LOG_FILE"
    exit 65
fi

mail -s "Clarity file $newest_csv transferred to Research IT" "$MAIL_RECIPIENTS" < "$LOG_FILE"
if [[ $? -ne 0 ]]
then
    /bin/echo "Unable to email log file" | /bin/tee -a "$LOG_FILE"
    exit 70
fi

exit 0



