#!/bin/sh

# Check if correct number of arguments is provided
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <old_filename> <new_filename>"
  exit 1
fi

OLD_FILE=$1
NEW_FILE=$2
TEMP_FILE="temp.sql"

# Check if the old file exists
if [ ! -f "$OLD_FILE" ]; then
  echo "File $OLD_FILE does not exist."
  exit 1
fi

# Copy the old file to a temporary file
cp "$OLD_FILE" "$TEMP_FILE"
if [ $? -ne 0 ]; then
  echo "Failed to copy $OLD_FILE to $TEMP_FILE"
  exit 1
fi

# Move the old file to the new file
git mv "$OLD_FILE" "$NEW_FILE"
if [ $? -ne 0 ]; then
  echo "Failed to move $OLD_FILE to $NEW_FILE"
  exit 1
fi

# Commit the move
git commit -m "Renamed $OLD_FILE to $NEW_FILE"
if [ $? -ne 0 ]; then
  echo "Failed to commit the rename"
  exit 1
fi

# Move the temporary file back to the old file name
# mv "$TEMP_FILE" "$OLD_FILE"
# if [ $? -ne 0 ]; then
#   echo "Failed to move $TEMP_FILE to $OLD_FILE"
#   exit 1
# fi

# Add and commit the new file with the old name
git add "$TEMP_FILE"
if [ $? -ne 0 ]; then
  echo "Failed to add the new $OLD_FILE"
  exit 1
fi

git commit -m "Added new $OLD_FILE with the same contents as $NEW_FILE"
if [ $? -ne 0 ]; then
  echo "Failed to commit the new $OLD_FILE"
  exit 1
fi

echo "Operation completed successfully."