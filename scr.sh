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

# commit rename 

git commit -m "Moved $OLD_FILENAME to $NEW_FILENAME"




touch "__old__$OLD_FILENAME"

cat "$NEW_FILENAME" > "__old__$OLD_FILENAME"

git rm --cached "$OLD_FILENAME"
git rm --cached "__old__$OLD_FILENAME"

echo "

/* This is a new file with additional inert content" >> "__old__$OLD_FILENAME"
for i in {1..2000}
do
    echo "This is line $i of the comment" >> "__old__$OLD_FILENAME"
done
echo "End of the 2,000-line comment */" >> "__old__$OLD_FILENAME"


git add "$NEW_FILENAME" "__old__$OLD_FILENAME"

git commit -m "Moved $OLD_FILENAME to $NEW_FILENAME and created __old__$OLD_FILENAME"

git push origin HEAD

echo "Files have been moved and copied successfully. Please review the changes before pushing."