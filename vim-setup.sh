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

echo_loud "Checking for tmux..."
sudo apt-get install tmux

echo_loud "Checking for nodejs and npm..."
if [ ! $(which node) ] || [ ! $(which npm) ]; then
    if [ "$(uname)" == "Darwin" ]; then
        brew install node
    else
        sudo add-apt-repository ppa:chris-lea/node.js
        sudo apt-get update
        sudo apt-get install nodejs
  fi
fi

echo_loud "Installing global javascript tools with npm..."
for x in grunt-cli jslint jshint; do
    sudo npm list -g | grep $x || sudo npm install -g $x
done

echo_loud "Installing global python tools with pip..."
for x in flake8 ipython; do
    sudo pip freeze | grep $x || sudo pip install $x
done

# Build vim from source
if [ $(has_old_vim_version) ]; then
    echo_loud "Looks like your vim is pretty old.  To use YouCompleteMe you need to build from source."
    if [ $(confirm "Build from source now?") ]; then
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
        if [ has_old_vim_version ]; then
            echo_bad "Build from source failed."
        else
            echo_loud "Build from source complete!"
        fi
    fi
fi

echo_loud "Checking for pathogen..."
mkdir -p ~/.vim/autoload ~/.vim/bundle
if [ ! -f ~/.vim/autoload/pathogen.vim ]; then
    curl -so ~/.vim/autoload/pathogen.vim \
            https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim
    echo_loud "Make sure your .vimrc has the following line:"
    echo_loud "execute pathogen#infect()"
fi
cd ~/.vim/bundle
vim_plugin_install() {
    if [ -d $1 ]; then
        echo_loud "$1 already installed."
    else
        echo_loud "Installing $1"
        git clone $2
    fi
}
echo_loud "Checking vim plugins..."
vim_plugin_install syntastic https://github.com/scrooloose/syntastic
vim_plugin_install vim-fugitive https://github.com/tpope/vim-fugitive
vim_plugin_install delimitMate https://github.com/Raimondi/delimitMate
vim_plugin_install nerdtree https://github.com/scrooloose/nerdtree
vim_plugin_install tern_for_vim https://github.com/marijnh/tern_for_vim
vim_plugin_install vim-css3-syntax https://github.com/hail2u/vim-css3-syntax
vim_plugin_install vim-css-color https://github.com/skammer/vim-css-color
vim_plugin_install vim-javascript https://github.com/pangloss/vim-javascript
vim_plugin_install vim-javascript-syntax https://github.com/jelera/vim-javascript-syntax.git

if [ ! -d YouCompleteMe ]; then
    echo_loud "Installing YouCompleteMe WITHOUT C/C++ support.  If you need C/C++, install it manually"
    echo_loud "from the docs: https://github.com/Valloric/YouCompleteMe"
    if [ $(confirm) ]; then 
        git clone https://github.com/Valloric/YouCompleteMe
        git submodule update --init --recursive
        sudo apt-get install cmake
        sudo apt-get install python-dev
        cd_to_build_dir
        mkdir -p ycm_build
        cd ycm_build
        cmake -G "Unix Makefiles" . ~/.vim/bundle/YouCompleteMe/cpp
        echo_loud "YouCompleteMe installation complete!"
    fi
fi
