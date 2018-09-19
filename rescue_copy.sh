#!/bin/bash
# This script is a maintenance script that is supposed to be
# executed regularly, using i.e. cron.
# .
# The script checks if there are any new files in a directory
# and tries to copy them to target folder. If the copying succeeds
# the source file is deleted. If there already is a file with matching
# size (in the target folder) the source file is deleted.
# .
# The original usage is to move the files that were not successfully
# copied to a network drive after being created by a program.
# In this case TVHeadend has tried to copy the recording to common
# network folder (using another external script), but it failed.
# So the file was copied to local rescue directory (which should
# remain empty).
#
# If this script fails to copy the file there will be no mail notice,
# since the failure had already happened earlier. Instead, it tries to
# send an email to the desired recipient if the copying was succesful so
# that the user does not need to move anything manually.
# .
# There are prerequisites. Please check that the target folder has
# write premissions for all users. Also, please check the permissions for
# all users in the script directory (for logging).
# Also, ssmtp and mailutils need to be installed for the mail notification
# to work, please test that emailing works beforehand. Email is only sent
# if the copying was succesfull.

# Set up the directory (without the last slash) in which the script (and the log) is (please check the permissions).
scriptdir="/home/user/scriptfolder"

# Set up the source directory (without the last slash) (please check that it is a valid folder).
sourcedir="/home/user/sourcefolder"

# Set up the target directory (without the last slash) (please check that it is 1) a valid folder/mount 2) with permissions and 3) not the same folder as the source).
targetdir="/media/targetfolder"

# Set up the receiver that will get the success notice (a valid email address).
emailtarget="foo@bar"

# No need to edit the lines below this point, do not touch!

# Check that the script directory is valid.
if [ -d "$scriptdir" ]
then
# This is the expected and not-logged condition.
    echo "The script directory seems to exist (permissions presumed), continuing."
else
    echo "The script directory is not set or it is not valid, exiting... (no log was created)"
    sleep 2
    exit 0
fi

# Script initiation logging, this can be commented out.
curdatetime=$(date +"%d/%m/%Y %R")
echo "$curdatetime : Executing the (rescue) file copying script." >> "$scriptdir/log_rescue_copy.txt"

# Check if there are any files to consider.
filecount1="0"
for ifile in "$sourcedir"/*
do
    if test -f "$ifile"
    then filecount1=$((filecount1+1))
    fi
done

# This can be commented out.
# echo "Total of $filecount1 file(s) found. Exiting if zero."

if [ "$filecount1" -ge 1 ]
then
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : Total of $filecount1 file(s) were found, next trying to copy them." >> "$scriptdir/log_rescue_copy.txt"
    echo "$filecount1 file(s) were found, proceeding with copying..."
else
    echo "No files were found in source directory, exiting"
    exit 0
fi

# Next, the write-read-accessibility of the target folder is tested
# by creating a probe file. A numeric value is then written and then
# the value is read to a variable. If the variable matches the expected
# value, the target folder is considered valid. The probe file is deleted
# immediately after the the value is read.

# First, delete the unlikely pre-existing probe file.
if [ -f "$targetdir"/targetdirwritereadtest.txt ]
then
    rm "$targetdir"/targetdirwritereadtest.txt
fi

# If the file can't be deleted, the permission test fails.
if [ -f "$targetdir"/targetdirwritereadtest.txt ]
then
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : There was a probe file that could not be deleted, exiting." >> "$scriptdir/log_rescue_copy.txt"
    echo "End of script. The target write-read permissions test failed, check the log."
    exit 0
fi

# Next create a the probe file.
touch "$targetdir"/targetdirwritereadtest.txt

# Check that the probe file was created, otherwise try remounting and re-touching.
if [ -f "$targetdir"/targetdirwritereadtest.txt ]
then
    # This is the expected case, and the file was created, no logging.
    echo "The probe file was created, continuing."
else
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : Could not write a file in the $targetdir folder, trying to remount." >> "$scriptdir/log_rescue_copy.txt"
    sudo mount -a
    sleep 5
    touch "$targetdir"/targetdirwritereadtest.txt
fi

# And now check that the file is there, otherwise.
if [ -f "$targetdir"/targetdirwritereadtest.txt ]
then
    # This is still the expected case.
    echo "Double-check passed, continuing."
else
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : The probe file could not be created." >> "$scriptdir/log_rescue_copy.txt"
    echo "The target write-read permissions test failed, check the log."
fi

sleep 1
echo "2" >> "$targetdir"/targetdirwritereadtest.txt
sleep 1
targettestread=$(<"$targetdir/targetdirwritereadtest.txt")
rm "$targetdir"/targetdirwritereadtest.txt

if [ "$targettestread" != 2 ]
then
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : The write-read test for $targetdir failed. Check that the folder is valid and all users have write permissions." >> "$scriptdir/log_rescue_copy.txt"
    echo "End of script, the target directory was did not pass the write-read test, check the log."
    exit 0
fi

# If the script has gotten this far, all the set parameters should be valid, there are files to copy and the target folder has sufficient permissions for copying.

# This can be commented out.
# curdatetime=$(date +"%d/%m/%Y %R")
# echo "$curdatetime : Target folder $targetdir seems to be mounted OK, next trying to copy the files one by one." >> "$scriptdir/log_rescue_copy.txt"

sleep 1

# Finally, the actual loop that tries to copy each file in the source directory.

for ifile in "$sourcedir"/*
do
    sourcesize_one=$(stat -c%s "$ifile")

# Take a 2 sec break and then reads the file size again. If there is a mismatch, skip to the next file.
    sleep 2
    sourcesize_two=$(stat -c%s "$ifile")
    if [ "$sourcesize_one" != "$sourcesize_two" ]
    then
        curdatetime=$(date +"%d/%m/%Y %R")
        echo "$curdatetime : Source file size check mismatch, it appears that the file $ifile is being written at the moment. Skipping to the next file..." >> "$scriptdir/log_rescue_copy.txt"
        echo "Source file size mismatch, probably the file is being written, continuing to the next file..."
        continue
    fi

# Check, if there already is a matching file in the target directory and make a log comment if there is.
    ifilebase=$(basename "$ifile")
    if test -f "$targetdir/$ifilebase"
    then
        curdatetime=$(date +"%d/%m/%Y %R")
        echo "$curdatetime : There already is a file with the same name as $ifilebase. Going to copy over it." >> "$scriptdir/log_rescue_copy.txt"
        echo "A matching filename ($ifilebase) found in the target directory. Overwriting will occur."
    fi

# Copy the source file to the target folder (whether there is a pre-existing file or not).

    /bin/cp "$ifile" "$targetdir"

    sleep 3

# Let's make sure that the copying was successful by comparing the file sizes.
sourcesize=$(stat -c%s "$ifile")
targetsize=$(stat -c%s "$targetdir/$ifilebase")

# This can be commented out.
# echo "Source size is $sourcesize_one and target size is $targetsize ."

# If the target file size matches the source, the process is logged as a success, send an email for notification.
if [ "$sourcesize" = "$targetsize" ]
then
    rm "$ifile"
    echo "File $ifilebase was successfully copied to $targetdir. The source file was deleted. " | mail -s "Rescue copy success" "$emailtarget"
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : The file $ifilebase was succesfully copied to $targetdir. A mail was sent (or was tried to be sent)." >> "$scriptdir/log_rescue_copy.txt"
    echo "The source file ($ifilebase) was succesfully copied to the target directory, checking for other files..."
# Otherwise log an error and continue to the (possible) next file.
else
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : The file $ifilebase could not be copied to $targetdir, source and target file sizes were considered." >> "$scriptdir/log_rescue_copy.txt"
    echo "The file $ifilebase could not be copied to $targetdir, check the log. Skipping to the (possible) next file..."
    continue
fi

done

curdatetime=$(date +"%d/%m/%Y %R")
echo "$curdatetime : The end of the script." >> "$scriptdir/log_rescue_copy.txt"
echo "End of script, check the log for details."

exit 0
