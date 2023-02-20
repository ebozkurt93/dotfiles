echo "Installing Fira Code"
curl -L https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip > fira_code.zip
echo "0949915ba8eb24d89fd93d10a7ff623f42830d7c5ffc3ecbf960e4ecad3e3e79  fira_code.zip" | shasum -a 256 -c - \
  || (echo "Mismatched SHA256 in fira_code.zip, exiting..." && exit)
unzip fira_code.zip -d fira_code
cp -a fira_code/ttf/ ~/Library/Fonts
rm -rf fira_code
rm fira_code.zip
echo "Installed Fira Code"

echo "Installing Input Mono"
# they seem to be generating this file on request, therefore SHA256 changes each time...
curl -L 'https://input.djr.com/build/?fontSelection=whole&a=0&g=0&i=0&l=0&zero=0&asterisk=0&braces=0&preset=default&line-height=1.2&accept=I+do&email=' > input_mono.zip
unzip input_mono.zip -d input_mono
cp -a input_mono/Input_Fonts/InputMono/InputMonoNarrow/ ~/Library/Fonts
# cp -a input_mono/Input_Fonts/InputMono/InputMono/ ~/Library/Fonts
rm -rf input_mono
rm input_mono.zip
echo "Installed Input Mono"

echo "Installing Jetbrains Mono"
curl -L https://download.jetbrains.com/fonts/JetBrainsMono-2.242.zip > jetbrains_mono.zip
echo "4e315b4ef176ce7ffc971b14997bdc8f646e3d1e5b913d1ecba3a3b10b4a1a9f  jetbrains_mono.zip" | shasum -a 256 -c - \
  || (echo "Mismatched SHA256 in fira_code.zip, exiting..." && exit)
unzip jetbrains_mono.zip -d jetbrains_mono
cp -a jetbrains_mono/fonts/ttf/ ~/Library/Fonts
rm -rf jetbrains_mono
rm jetbrains_mono.zip
echo "Installed Jetbrains Mono"

echo "Installing Noto Sans Mono"
curl -L 'https://fonts.google.com/download?family=Noto%20Sans%20Mono' > noto_sans_mono.zip
unzip noto_sans_mono.zip -d noto_sans_mono
cp -a noto_sans_mono/static/NotoSansMono/ ~/Library/Fonts
rm -rf noto_sans_mono
rm noto_sans_mono.zip
echo "Installed Noto Sans Mono"

echo "Installing Droid Sans Mono (for Nerd Font icons)"
dsm_name="Droid Sans Mono for Powerline Nerd Font Complete.otf"
curl -fLo "$dsm_name" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf
mv "$dsm_name" ~/Library/Fonts
echo "Installed Droid Sans Mono"
echo "Installed fonts successfully"

