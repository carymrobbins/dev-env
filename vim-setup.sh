#!/bin/bash
set -e

echo_loud () {
    echo "$(tput setaf 2 && tput bold)$@$(tput sgr 0)"
}

echo_bad () {
    echo "$(tput setaf 1 && tput bold)$@$(tput sgr 0)"
}

confirm () {
    # http://stackoverflow.com/questions/3231804/in-bash-how-to-add-are-you-sure-y-n-to-any-command-or-alias
    # call with a prompt string or use a default
    read -r -p "$(echo_loud "${1:-Would you like to proceed?} [y/N]")" response
    case $response in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

has_old_vim_version() {
    [ "$(echo $(vim --version | grep -o "[0-9][0-9]*\.[0-9][0-9]*" | head -n1) "< 7.4" | bc)" == "1" ]
}

cd_to_build_dir() {
    read -r -p "What directory would you like to build to? [~/build] " BUILD_DIR
    if [ -z $BUILD_DIR ]; then
        BUILD_DIR=~/build
    fi
    cd $BUILD_DIR
}

APT_GET_UPDATED=""

echo_loud "Installing global javascript tools with npm..."
if [ ! $(which node) ] || [ ! $(which npm) ]; then
    if [ "$(uname)" == "Darwin" ]; then
        brew install node
    else
        sudo add-apt-repository ppa:chris-lea/node.js
        sudo apt-get update
        APT_GET_UPDATED=1
        sudo apt-get install nodejs
  fi
fi
for x in grunt-cli jslint jshint; do
    sudo npm list -g | grep $x || sudo npm install -g $x
done

if [ ! $APT_GET_UPDATED ]; then
    echo_loud "Updating apt-get..."
    sudo apt-get update
fi

echo_loud "Checking for tmux..."
sudo apt-get install tmux

echo_loud "Installing global python tools with pip..."
which easy_install > /dev/null || sudo apt-get install python-setuptools
which pip > /dev/null          || sudo easy_install pip
for x in flake8 ipython ipdb; do
    sudo pip freeze | grep $x > /dev/null || sudo pip install $x
done

# Build vim from source
has_old_vim_version && {
    echo_loud "Looks like your vim is pretty old.  To use YouCompleteMe you need to build from source."
    confirm "Build from source now?" && {
        sudo apt-get install libncurses5-dev libgnome2-dev libgnomeui-dev \
            libgtk2.0-dev libatk1.0-dev libbonoboui2-dev \
            libcairo2-dev libx11-dev libxpm-dev libxt-dev python-dev ruby-dev mercurial
        sudo apt-get remove vim vim-runtime gvim vim-tiny vim-common vim-gui-common
        cd_to_build_dir
        hg clone https://code.google.com/p/vim/
        cd vim
        ./configure --with-features=huge \
                    --enable-rubyinterp \
                    --enable-pythoninterp \
                    --with-python-config-dir=/usr/lib/python2.7-config \
                    --enable-perlinterp \
                    --enable-gui=gtk2 --enable-cscope --prefix=/usr \
                    --enable-luainterp
        make VIMRUNTIMEDIR=/usr/share/vim/vim74
        sudo make install
        sudo update-alternatives --install /usr/bin/editor editor /usr/bin/vim 1
        sudo update-alternatives --set editor /usr/bin/vim
        sudo update-alternatives --install /usr/bin/vi vi /usr/bin/vim 1
        sudo update-alternatives --set vi /usr/bin/vim
        has_old_vim_version && echo_bad "Build from source failed." || echo_loud "Build from source complete!"
    }
}

echo_loud "Checking for pathogen..."
mkdir -p ~/.vim/autoload ~/.vim/bundle
if [ ! -f ~/.vim/autoload/pathogen.vim ]; then
    echo_loud "Installing pathogen..."
    curl -LSso ~/.vim/autoload/pathogen.vim \
            https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim
    echo_bad "Make sure your .vimrc has the following line:"
    echo_bad "execute pathogen#infect()"
fi
cd ~/.vim/bundle
vim_plugin_install() {
    URL=$1
    NAME=$(basename $URL)
    if [ -d $NAME ]; then
        echo_loud "$NAME already installed."
    else
        echo_loud "Installing $NAME"
        git clone $URL
    fi
}
echo_loud "Checking vim plugins..."
vim_plugin_install https://github.com/scrooloose/syntastic
vim_plugin_install https://github.com/tpope/vim-fugitive
vim_plugin_install https://github.com/Raimondi/delimitMate
vim_plugin_install https://github.com/scrooloose/nerdtree
vim_plugin_install https://github.com/marijnh/tern_for_vim
vim_plugin_install https://github.com/hail2u/vim-css3-syntax
vim_plugin_install https://github.com/skammer/vim-css-color
vim_plugin_install https://github.com/pangloss/vim-javascript
vim_plugin_install https://github.com/jelera/vim-javascript-syntax
vim_plugin_install https://github.com/wincent/Command-T

if [ ! -d YouCompleteMe ]; then
    echo_loud "Installing YouCompleteMe WITHOUT C/C++ support.  If you need C/C++, install it manually" \
              "from the docs: https://github.com/Valloric/YouCompleteMe"
    confirm && {
        git clone https://github.com/Valloric/YouCompleteMe
        cd YouCompleteMe
        git submodule update --init --recursive
        sudo apt-get install cmake
        sudo apt-get install python-dev
        cd_to_build_dir
        mkdir -p ycm_build
        cd ycm_build
        cmake -G "Unix Makefiles" . ~/.vim/bundle/YouCompleteMe/cpp
        make ycm_support_libs
        echo_loud "YouCompleteMe installation complete!"
    }
fi
