version=v1.60.0
os_conf=osx-arm64
curl -L https://github.com/rclone/rclone/releases/download/$version/rclone-$version-$os_conf.zip > rclone.zip
echo "4a1a3fdcfd575e328785cb4d09f88998fe2c3b1b0f07e77252ca28ca002be687  rclone.zip" | shasum -a 256 -c - \
|| (echo "Mismatched SHA256 in rclone.zip, exiting..." && exit)

unzip rclone.zip -d rclone

cp rclone/rclone-$version-$os_conf/rclone ~/bin
rm -rf rclone
rm rclone.zip

echo "Installed rclone successfully"
echo "You might need to give permissions when running the app for the first time"
