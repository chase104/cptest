#!/bin/bash

# Check if correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <original_file> <new_file>"
    exit 1
fi

original_file=$1
new_file=$2

# Create a temporary branch
git checkout -b temp-branch

# Rename original_file to new_file and commit
git mv "$original_file" "$new_file"
git commit -m "Rename $original_file to $new_file"

# Create new original_file and make a slight change
cp "$new_file" "$original_file"
echo "# This is a new $original_file" >> "$original_file"
git add "$original_file"
git commit -m "Create new $original_file with same contents but as a new file"

# Merge the temporary branch into the current branch
git checkout -
git merge --no-ff temp-branch -m "Merge changes from temp-branch"

# Push the changes to the remote repository
git push origin HEAD

# Delete the temporary branch
git branch -d temp-branch

echo "Operations completed successfully. You can now create a PR with the changes."