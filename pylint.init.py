import os, sys

sys.path.extend([
    "/home/vagrant/devel/cms_dev/lib/python2.6/site-packages",
    "/home/vagrant/devel/cms_dev/local/lib/python2.6/site-packages"
])

base = "/vagrant/devel/cms_dev/src"
sys.path.extend([os.path.join(base, x) for x in os.listdir(base)])
