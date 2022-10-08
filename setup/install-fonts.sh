curl -L https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip > fira_code.zip
echo "0949915ba8eb24d89fd93d10a7ff623f42830d7c5ffc3ecbf960e4ecad3e3e79  fira_code.zip" | shasum -a 256 -c - \
|| (echo "Mismatched SHA256 in fira_code.zip, exiting..." && exit)

unzip fira_code.zip -d fira_code

cp -a fira_code/ttf/ ~/Library/Fonts
rm -rf fira_code
rm fira_code.zip

echo "Installed fonts successfully"