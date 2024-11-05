#!/bin/bash

docker run -it --rm \
    -v "$(pwd)":/data \
    -v nvim-config:/root/.config \
    -v nvim-data:/root/.local/share/nvim \
    -e KICKSTART_URL=https://github.com/Walms/kickstart.nvim.git \
    hledger-dev
