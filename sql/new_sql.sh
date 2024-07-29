# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <old_filename> <new_filename>"
    exit 1
fi

# Assign arguments to variables
OLD_FILENAME=$1
NEW_FILENAME=$2

# Extract the part of the old filename after the timestamp and before -old
BASENAME=$(basename "$OLD_FILENAME")
TIMESTAMP="${BASENAME%%-*}"
SUFFIX=$(echo "$BASENAME" | sed -e "s/^$TIMESTAMP-//" -e 's/-old$//')

# Move the old file to the new file
git mv "$OLD_FILENAME" "$NEW_FILENAME"

git add "$NEW_FILENAME"
# commit and push
git commit -m "Moved $OLD_FILENAME to $NEW_FILENAME"

git push origin HEAD

# Append -old to the old filename
OLD_FILE_WITH_SUFFIX="${OLD_FILENAME%.*}-old.${OLD_FILENAME##*.}"

touch "$OLD_FILE_WITH_SUFFIX"

cat "$NEW_FILENAME" > "$OLD_FILE_WITH_SUFFIX"

echo "

/* This is a new file with additional inert content" >> "$OLD_FILE_WITH_SUFFIX"
for i in {1..100}
do
    echo "This is line $i of the comment" >> "$OLD_FILE_WITH_SUFFIX"
done
echo "End of the 2,000-line comment */" >> "$OLD_FILE_WITH_SUFFIX"

git add "$NEW_FILENAME" "$OLD_FILE_WITH_SUFFIX"

git commit -m "Moved and recreated original file $OLD_FILE_WITH_SUFFIX"

git push origin HEAD

echo "Files have been moved and copied successfully. Please review the changes before pushing."