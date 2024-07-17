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

# Copy the new file back to the old filename
cp "$NEW_FILENAME" "$OLD_FILENAME"


echo "Files have been moved and copied successfully. Please review the changes before pushing."