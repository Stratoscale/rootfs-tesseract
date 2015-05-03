CENTOS_RELEASE_RPM_NAME = centos-release-7-1.1503.el7.centos.2.8.x86_64.rpm
ROOTFS = build/root

all: $(ROOTFS)

submit:
	sudo -E solvent submitproduct rootfs $(ROOTFS)

approve:
	sudo -E solvent approve --product=rootfs

clean:
	sudo rm -fr build

build/$(CENTOS_RELEASE_RPM_NAME):
	-mkdir $(@D)
	yumdownloader --config=centos.yum.conf --destdir=build centos-release
	test -e $@

$(ROOTFS): build/$(CENTOS_RELEASE_RPM_NAME)
	echo "Testing sudo works - if this fails add the following line to /etc/sudoers:"
	echo '<username>	ALL=NOPASSWD:	ALL'
	echo "and consider commenting out RequireTTY"
	sudo -n true
	echo "Cleaning"
	-sudo rm -fr $(ROOTFS) $(ROOTFS).tmp
	mkdir -p $(ROOTFS).tmp
	mkdir -p $(ROOTFS).tmp/var/lib/rpm
	echo "Unpacking release packages"
	sudo rpm --root $(abspath $(ROOTFS)).tmp --initdb
	sudo rpm --root $(abspath $(ROOTFS)).tmp -ivh $<
	echo "Installing minimal install"
	sudo yum --nogpgcheck --installroot=$(abspath $(ROOTFS)).tmp groupinstall "minimal install" --assumeyes
	cp /etc/resolv.conf $(ROOTFS).tmp/etc/resolv.conf
	echo "Updating"
	sudo chroot $(ROOTFS).tmp yum upgrade --assumeyes
	echo "Install kernel and boot loader"
	sudo chroot $(ROOTFS).tmp yum install kernel grub2 kexec-tools lvm2 --assumeyes
	echo
	echo "writing configuration 1: disabling selinux"
	sudo cp selinux.config $(ROOTFS).tmp/etc/selinux/config
	echo "writing configuration 2: /etc/resov.conf"
	sudo cp /etc/resolv.conf $(ROOTFS).tmp/etc/
	echo "writing configuration 3: ethernet configuration"
	sudo cp ifcfg-eth0 $(ROOTFS).tmp/etc/sysconfig/network-scripts/ifcfg-eth0
	echo "writing configuration 4: boot-loader"
	sudo cp etc_default_grub $(ROOTFS).tmp/etc/default/grub
	sudo ./chroot.py $(ROOTFS).tmp grub2-mkconfig -o /boot/grub2/grub.cfg || true
	test -e $(ROOTFS).tmp/boot/grub2/grub.cfg
	sudo sh -c "echo 'add_dracutmodules+=\"lvm\"' >> $(ROOTFS).tmp/etc/dracut.conf"
	sudo ./chroot.py $(ROOTFS).tmp dracut --kver=`ls $(ROOTFS).tmp/lib/modules` --force
	sudo grep console.ttyS0 $(ROOTFS).tmp/boot/grub2/grub.cfg
	sudo rm -fr $(ROOTFS).tmp/tmp/* $(ROOTFS).tmp/var/tmp/*
	echo "Installing RPMs"
	$(foreach rpm,$(RPMS_TO_INSTALL), sudo chroot $(ROOTFS).tmp yum install $(rpm) --assumeyes && ) true
	$(foreach rpm,$(RPMS_TO_DOWNLOAD), sudo chroot $(ROOTFS).tmp sh -c "cd /tmp; curl $(YUMCACHE)$(rpm) -o `basename $(rpm)`; yum install ./`basename $(rpm)` --assumeyes" && ) true
	echo "Installing packages from EPEL"
	cp epel-release-7-5.noarch.rpm $(ROOTFS).tmp/tmp
	sudo chroot $(ROOTFS).tmp yum install /tmp/epel-release-7-5.noarch.rpm --assumeyes
	$(foreach package,$(EPEL_PACKAGES_TO_INSTALL), sudo chroot $(ROOTFS).tmp yum install $(package) --assumeyes && ) true
	sudo ./chroot.py $(ROOTFS).tmp pip install $(PYTHON_PACKAGES_TO_INSTALL) $(PYTHON_PACKAGES_TO_INSTALL_INDIRECT_DEPENDENCY) --allow-external PIL --allow-unverified PIL
	echo "Installing pip packages"
	sudo cp externals/get-pip.py $(ROOTFS).tmp/tmp/
	sudo ./chroot.py $(ROOTFS).tmp python /tmp/get-pip.py
	sudo ./chroot.py $(ROOTFS).tmp pip install $(PYTHON_PACKAGES_TO_INSTALL)
	echo "Done"
	sudo rm -fr $(ROOTFS).tmp/tmp/* $(ROOTFS).tmp/var/tmp/*
	sudo mv $(ROOTFS).tmp $(ROOTFS)

RPMS_TO_INSTALL = \
	boost-iostreams \
	boost-program-options \
	boost-python \
	boost-system \
	boost-regex \
	boost-filesystem \
	ethtool \
	iproute \
	libyaml \
	net-tools \
	patch \
	python-six \
	tar \
	tcpdump \
	xfsprogs \
	xmlrpc-c-c++ \
	redhat-lsb-core \
    automake \
    boost-devel \
    createrepo \
    cscope \
    ctags \
    curl \
    doxygen \
    fuseiso \
    fontforge \
    gcc \
    gcc-c++ \
    git \
    httpd-tools \
    java-1.7.0-openjdk \
    kernel-debug-devel \
    kernel-devel \
    libcap \
    libvirt-python \
    make \
    ncurses-devel \
    nmap \
    openssl-devel \
    python-devel \
    python-dmidecode \
    python-matplotlib \
    python-netaddr \
    rpmdevtools \
    ruby \
    ruby-devel \
    rubygem-rake \
    spice-gtk-tools \
    tcpdump \
    udisks2 \
    unzip \
    vim-enhanced \
    wget \
    xmlrpc-c-devel \
    yum-utils \

PYTHON_PACKAGES_TO_INSTALL = \
	anyjson \
	bunch \
	bz2file \
	coverage \
	Flask \
	Flask-RESTful \
	ftputil \
	futures \
	greenlet \
	ipdb \
	jinja2 \
	lcov_cobertura \
	mock \
	netaddr \
	netifaces \
	networkx \
	paramiko \
	pep8 \
	pip2pi \
	pss \
	psutil \
	PyCPUID \
	pyftpdlib \
	pyiface \
	pylint \
	PyYAML \
	pyzmq \
	qpid-python \
	requests \
	requests-toolbelt \
	selenium \
	setuptools \
	sh \
	simplejson \
	single \
	stevedore \
	taskflow \
	tornado \
	Twisted \
	vncdotool \
	websockify \
	whisper \
	xmltodict \

EPEL_PACKAGES_TO_INSTALL = \
    sshpass \
    mock \

