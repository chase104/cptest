# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <old_filename> <new_filename>"
    exit 1
fi

# Assign arguments to variables
OLD_FILENAME=$1
NEW_FILENAME=$2

# Move the old file to the new file
mv "$OLD_FILENAME" "$NEW_FILENAME"

cp "$NEW_FILENAME" "$OLD_FILENAME"
# clear contents of old file
echo "" > "$OLD_FILENAME"

# remove cache forscr.sh

git rm --cached "$OLD_FILENAME"

git add "$NEW_FILENAME" "_$OLD_FILENAME"

git commit -m "Moved $OLD_FILENAME to $NEW_FILENAME and copied emptied $OLD_FILENAME"

# populate old file and commit

cat "$NEW_FILENAME" > "$OLD_FILENAME"

git add "$OLD_FILENAME"

git commit -m "Populated $OLD_FILENAME with contents of $NEW_FILENAME"

echo "Files have been moved and copied successfully. Please review the changes before pushing."