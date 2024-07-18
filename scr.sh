# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <old_filename> <new_filename>"
    exit 1
fi

# Assign arguments to variables
OLD_FILENAME=$1
NEW_FILENAME=$2

# Move the old file to the new file
git mv "$OLD_FILENAME" "$NEW_FILENAME"

# remove cache for old file name

git rm --cached "$OLD_FILENAME"

touch "_$OLD_FILENAME"

cat "$NEW_FILENAME" > "_$OLD_FILENAME"

git add "$NEW_FILENAME" "_$OLD_FILENAME"

git commit -m "Moved $OLD_FILENAME to $NEW_FILENAME and copied it to _$OLD_FILENAME"

# Copy the new file back to the old filename
# Add both files to the staging area


echo "Files have been moved and copied successfully. Please review the changes before pushing."