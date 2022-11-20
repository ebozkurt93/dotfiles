PATH_DIR="$HOME/Documents/binaries"
mkdir -p "$PATH_DIR"
curl https://cht.sh/:cht.sh > "cht.sh"
echo "d3135e42b800ff2e7aac44d4dfe500f0f4e2c7eb00a1c2191b0dc8b28431f155  cht.sh" | shasum -a 256 -c - \
|| (echo "Mismatched SHA256 in cht.sh, exiting..." && exit)
mv "cht.sh" "$PATH_DIR/cht.sh"
chmod +x "$PATH_DIR/cht.sh"
