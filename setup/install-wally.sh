PATH_DIR="$HOME/bin"
mkdir -p "$PATH_DIR"
curl -L https://github.com/georgesofianosgr/wally/releases/download/v1.0.0/wally > "wally"
echo "0b554066caadbb4681b218f3aa41ca1b8752d2b5b4576d21c6469229660d2e28  wally" | shasum -a 256 -c - \
|| (echo "Mismatched SHA256 in wally, exiting..." && exit)
mv "wally" "$PATH_DIR/wally"
chmod +x "$PATH_DIR/wally"
