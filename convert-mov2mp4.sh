# Variables
root_folder="Source"                                      # Where to scan
installation_path="/to/your/path/"                        # Full path where nextcloud is installed, must not end with '/'
old_extension=".mov"                                      # e.g. ".mov"
new_extension=".mp4"                                      # e.g. ".mp4"
safe_mode=true                                            # true = rename file to .mov-old, false = permanently delete old .mov file
ignoregrep="Permission"                                   # Ignore stderr messages from find that match this grep (e.g. 'Permission denied' for some folder name)
instance_id=$(openssl rand -hex 4)
append_extension=-wip-$instance_id

# Check version de ffmpeg
FFMPEG_VERSION=$(ffmpeg -version | head -n 1 | awk '{print $3}')
REQUIRED_VERSION="5.1.5"
if [[ "$FFMPEG_VERSION" < "$REQUIRED_VERSION" ]]; then
    echo "The version of ffmpeg $FFMPEG_VERSION. Udpate please. $REQUIRED_VERSION ou latest."
    exit 1
fi

# Find files to convert
files_to_convert=()
while IFS=  read -r -d $'\0'; do
    original_filename="$REPLY"
    temporary_filename="$original_filename$append_extension"
    mv "$original_filename" "$temporary_filename"
    #ls "$original_filename"
    #ls "$temporary_filename"
    files_to_convert+=("$temporary_filename")
done < <(find $root_folder -name "*$old_extension" -print0 2> >(grep -v $ignoregrep >&2))

# Get list of folders to update and remove duplicates
folders_to_update=()
for i in "${files_to_convert[@]}"
do
        :
        printf "Processing $i\n\n"
        xpath=${i%/*}
        folders_to_update+=("${xpath:${#root_folder}}") # discard everything after root folder (cuts by length of string)
done
eval folders_to_update=($(for i in  "${folders_to_update[@]}" ; do  echo "\"$i\"" ; done | sort -u))

# Convert it!
for i in "${files_to_convert[@]}"
do
        :
        # Extract original file dates
        MOD_DATE=$(stat -c %y "$i")
        ACC_DATE=$(stat -c %x "$i")

        # Define the output file name
        output_file="${i::-${#old_extension}-${#append_extension}}$new_extension"

        # Get exif create file
        CREATION_DATE=$(exiftool -CreateDate -d "%Y-%m-%d %H:%M:%S" -s3 "$i")

        # Export file to mp4
        ffmpeg -loglevel panic -i "$i" -q:v 0 -q:a 0 -map_metadata:s:v 0:s:v -map_metadata:s:a 0:s:a "$output_file"

        # Add create date into exif (todo)
        exiftool -overwrite_original -CreateDate="$CREATION_DATE" "$output_file"

        # Apply original dates to the new file
        touch -d "$MOD_DATE" "$output_file"
        touch -d "$ACC_DATE" -a "$output_file"

        if [ "$safe_mode" = true ]
                then
                        mv "$i" "$i-old"
                else
                rm "$i"
        fi
done

chmod 640 $root_folder/*.mp4
chown -R www-data: "$root_folder";
