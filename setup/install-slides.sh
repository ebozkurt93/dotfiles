PATH_DIR="$HOME/bin"
mkdir -p "$PATH_DIR"
curl -L https://github.com/maaslalani/slides/releases/download/v0.9.0/slides_0.9.0_darwin_amd64.tar.gz > "slides.tar.gz"
echo "033467b54bc3b1630b2e95bbfb7c0d168e162255e1c343df72744bc95369547c  slides.tar.gz" | shasum -a 256 -c -
if [ $? != 0 ]; then
  echo "Mismatched SHA256 in slides.tar.gz, exiting..."
  exit
fi
tar -zxvf slides.tar.gz slides
rm "slides.tar.gz"
mv "slides" "$PATH_DIR/slides"
chmod +x "$PATH_DIR/slides"
