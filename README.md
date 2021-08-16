# clarity_RIT_transfer

#### Regularly transfer files from the GT clarity server to a Research IT folder via a self-resubmitting Slurm job, compare checksum, and email log file to specified users.


## Details

### Server and file location
Files are expected to be found on bhgtclarity01lp.jax.org (the "remote" server). There they are under /opt/gls/clarity/customextensions/close_sanger_seq_projects.
We want the most recent files beginning with the root ""closed_samples_today" followed by a datestamp, and ending with the extensions .csv and .md5.


### Target location
The script currently copies the files to the folder /projects/researchit/clarity_RIT_transfer.


### Transfer means
Files are copied via scp, logging into the remote server with a specified username. Currently it is "glsjboss". Public ssh keys have been setup in that user's home directoy on the remote server and must also be in your home directory. Currently this is /home/kindln on sumner.


### File selection
Because we don't know what datestamp the files will have, we have to just grab every file matching the above pattern, pick the most recent md5 and csv file, and throw the rest out. If these files have already been processed, it means there are no new files on the remote server since the script last ran, so it will stop. When we're done, the files will be moved to the "completed" directory under the target location, above.


### Checksums
We compute the md5 checksum of the csv file and compare it to the one in the md5 file.


### Logging and email
Log files is kept in the logs directory and emailed to the specified users (currently Neil Kindlon and James Qin).

### Job recurrence
The job resubmits itself with an sbatch call to SLURM and is currently set to run once a day. New files are actually expected to only appear once a week.
