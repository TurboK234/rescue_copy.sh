# rescue_copy.sh
A linux shell script to regularly check for files in a folder and copy them to target folder.

This script is a maintenance script that is supposed to be
executed regularly, using i.e. cron.

The script checks if there are any new files in a directory
and tries to copy them to target folder. If the copying succeeds
the source file is deleted. If there already is a file with matching
size (in the target folder) the source file is deleted.

The original usage is to move the files that were not successfully
copied to a network drive after being created by a program.
In this case TVHeadend has tried to copy the recording to common
network folder (using another external script), but it failed.
So the file was copied to local rescue directory (which should
remain empty).

If this script fails to copy the file there will be no mail notice,
since the failure had already happened earlier. Instead, it tries to
send an email to the desired recipient if the copying was succesful so
that the user does not need to move anything manually.

There are prerequisites. Please check that the target folder has
write premissions for all users. Also, please check the permissions for
all users in the script directory (for logging).
Also, ssmtp and mailutils need to be installed for the mail notification
to work, please test that emailing works beforehand. Email is only sent
if the copying was succesfull.
