if [ "$(uname -m)" = "arm64" ]; then
    echo "Apple Silicon detected. Compiling from source..."
    curl -sL https://raw.githubusercontent.com/fcanas/mirror-displays/master/mirror.m > mirror.m
    clang -O3 -Wall -framework Foundation -framework CoreGraphics mirror.m -o mirror
    mkdir -p ~/bin
    mv mirror ~/bin/mirror
    rm mirror.m
    echo "Compiled and installed mirror successfully for arm64"
else
    curl -L https://github.com/fcanas/mirror-displays/releases/download/v1.2/mirror.zip > mirror.zip
    echo "3a44b1e65fdbcd15ba93ec1a1af97e205c8d274cb0272a40940add9f62853e2f  mirror.zip" | shasum -a 256 -c - \
    || (echo "Mismatched SHA256 in mirror.zip, exiting..." && exit)

    unzip mirror.zip -d mirror
    mkdir -p ~/bin
    cp mirror/mirror ~/bin
    rm -rf mirror
    rm mirror.zip
    echo "Installed mirror successfully for x86_64"
fi

echo "You might need to give permissions when running the app for the first time"
