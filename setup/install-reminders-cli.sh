PATH_DIR="$HOME/bin"
mkdir -p "$PATH_DIR"
curl -L https://github.com/keith/reminders-cli/releases/download/2.3.0/reminders.tar.gz > "reminders.tar.gz"
echo "4384c798c390c38b389d19befaae591b9502b1d4ea3fae991b26319bc4244f83  reminders.tar.gz" | shasum -a 256 -c -
if [ $? != 0 ]; then
  echo "Mismatched SHA256 in reminders.tar.gz, exiting..."
  exit
fi
tar -zxvf reminders.tar.gz reminders
rm "reminders.tar.gz"
mv "reminders" "$PATH_DIR/reminders"
chmod +x "$PATH_DIR/reminders"
