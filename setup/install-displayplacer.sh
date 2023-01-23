PATH_DIR="$HOME/bin"
mkdir -p "$PATH_DIR"
curl -L https://github.com/jakehilborn/displayplacer/releases/download/v1.2.0/displayplacer > "displayplacer"
echo "1dc2355e54bc2b84ce7471d6741f9148cd3e5632b561d81ec355adeef41528ad  displayplacer" | shasum -a 256 -c - \
|| (echo "Mismatched SHA256 in displayplacer, exiting..." && exit)
mv "displayplacer" "$PATH_DIR/displayplacer"
chmod +x "$PATH_DIR/displayplacer"
