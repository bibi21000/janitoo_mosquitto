# Makefile for janitoo
#

# You can set these variables from the command line.
ARCHBASE      = archive
BUILDDIR      = build
DISTDIR       = dists
NOSE          = $(shell which nosetests)
NOSEOPTS      = --verbosity=2
PYLINT        = $(shell which pylint)
PYLINTOPTS    = --max-line-length=140 --max-args=9 --extension-pkg-whitelist=zmq --ignored-classes=zmq --min-public-methods=0

ifndef PYTHON_EXEC
PYTHON_EXEC=python
endif

ifndef message
message="Auto-commit"
endif

ifdef VIRTUAL_ENV
python_version_full := $(wordlist 2,4,$(subst ., ,$(shell ${VIRTUAL_ENV}/bin/${PYTHON_EXEC} --version 2>&1)))
else
python_version_full := $(wordlist 2,4,$(subst ., ,$(shell ${PYTHON_EXEC} --version 2>&1)))
endif

python_version_major = $(word 1,${python_version_full})
python_version_minor = $(word 2,${python_version_full})
python_version_patch = $(word 3,${python_version_full})

PIP_EXEC=pip
ifeq (${python_version_major},3)
	PIP_EXEC=pip3
endif

MODULENAME   = $(shell basename `pwd`)
DOCKERNAME   = $(shell echo ${MODULENAME}|sed -e "s|janitoo_||g")

NOSECOVER     = --cover-package=janitoo,janitoo_db,${MODULENAME} --cover-min-percentage= --with-coverage --cover-inclusive --cover-html --cover-html-dir=${BUILDDIR}/docs/html/tools/coverage --with-html --html-file=${BUILDDIR}/docs/html/tools/nosetests/index.html

DEBIANDEPS := $(shell [ -f debian.deps ] && cat debian.deps)
BOWERDEPS := $(shell [ -f bower.deps ] && cat bower.deps)

TAGGED := $(shell git tag | grep -c v${janitoo_version} )

distro = $(shell lsb_release -a 2>/dev/null|grep Distributor|cut -f2 -d ":"|sed -e "s/\t//g" )
release = $(shell lsb_release -a 2>/dev/null|grep Release|cut -f2 -d ":"|sed -e "s/\t//g" )
codename = $(shell lsb_release -a 2>/dev/null|grep Codename|cut -f2 -d ":"|sed -e "s/\t//g" )

-include Makefile.local

.PHONY: help check-tag clean all build develop install uninstall clean-doc doc certification tests pylint deps docker-tests

help:
	@echo "Please use \`make <target>' where <target> is one of"
	@echo "  build           : build the module"
	@echo "  develop         : install for developpers"
	@echo "  install         : install for users"
	@echo "  uninstall       : uninstall the module"
	@echo "  deps            : install dependencies for users"
	@echo "  doc   	    	 : make documentation"
	@echo "  tests           : launch tests"
	@echo "  clean           : clean the development directory"

clean-dist:
	-rm -rf $(DISTDIR)

clean: clean-doc
	-rm -rf $(ARCHBASE)
	-rm -rf $(BUILDDIR)
	-rm -f generated_doc
	-rm -f janidoc
	-@find . -name \*.pyc -delete

uninstall:
	-yes | ${PIP_EXEC} uninstall ${MODULENAME}
	-${PYTHON_EXEC} setup.py develop --uninstall
	-@find . -name \*.egg-info -type d -exec rm -rf "{}" \;

deps:
	@echo "Install dependencies for ${MODULENAME}."
ifneq ('${DEBIANDEPS}','')
	sudo apt-get install -y ${DEBIANDEPS}
endif
	@echo
	@echo "Dependencies for ${MODULENAME} finished."

clean-doc:
	-rm -Rf ${BUILDDIR}/docs
	-rm -Rf ${BUILDDIR}/janidoc
	-rm -f objects.inv
	-rm -f generated_doc
	-rm -f janidoc

janidoc:
	-ln -s /opt/janitoo/src/janitoo_sphinx janidoc

apidoc:
	-rm -rf ${BUILDDIR}/janidoc/source/api
	-mkdir -p ${BUILDDIR}/janidoc/source/api
	cp -Rf janidoc/* ${BUILDDIR}/janidoc/
	cd ${BUILDDIR}/janidoc/source/api && sphinx-apidoc --force --no-toc -o . ../../../../src/
	cd ${BUILDDIR}/janidoc/source/api && mv ${MODULENAME}.rst index.rst

doc: janidoc apidoc
	- [ -f transitions_graph.py ] && python transitions_graph.py
	-cp -Rf rst/* ${BUILDDIR}/janidoc/source
	sed -i -e "s/MODULE_NAME/${MODULENAME}/g" ${BUILDDIR}/janidoc/source/tools/index.rst
	make -C ${BUILDDIR}/janidoc html
	cp ${BUILDDIR}/janidoc/source/README.rst README.rst
	-ln -s $(BUILDDIR)/docs/html generated_doc
	@echo
	@echo "Documentation finished."

github.io:
	git checkout --orphan gh-pages
	git rm -rf .
	touch .nojekyll
	git add .nojekyll
	git commit -m "Initial import" -a
	git push origin gh-pages
	git checkout master
	@echo
	@echo "github.io branch initialised."

doc-full: tests pylint doc-commit

doc-commit: doc
	git checkout gh-pages
	cp -Rf build/docs/html/* .
	git add *.html
	git add *.js
	git add tools/
	git add api/
	-git add _images/
	-git add _modules/
	-git add _sources/
	-git add _static/
	git commit -m "Auto-commit documentation" -a
	git push origin gh-pages
	git checkout master
	@echo
	@echo "Documentation published to github.io."

pylint:
	-mkdir -p ${BUILDDIR}/docs/html/tools/pylint
	$(PYLINT) --output-format=html $(PYLINTOPTS) src/${MODULENAME} >${BUILDDIR}/docs/html/tools/pylint/index.html

install: develop
	@echo
	@echo "Installation of ${MODULENAME} finished."

develop:
	@echo
	@echo "Installation for developpers of ${MODULENAME} start."
	lsb_release -a
	@echo "Install mosquitto for $(distro):$(codename)."
ifeq ($(distro),Debian)
	wget -qO - http://repo.mosquitto.org/debian/mosquitto-repo.gpg.key | sudo apt-key add -
	cd /etc/apt/sources.list.d/ && sudo wget http://repo.mosquitto.org/debian/mosquitto-$(codename).list
endif
ifeq ($(distro),Ubuntu)
	sudo apt-get install python-software-properties
	sudo apt-add-repository -y ppa:mosquitto-dev/mosquitto-ppa
endif
	sudo apt-get update
	sudo apt-get install -y --force-yes mosquitto
#~ ifneq ($(codename),precise)
	#~ #No websocket for precise
	#~ sudo cp websockets.conf /etc/mosquitto/conf.d/
#~ endif
	sudo cp mqtt.conf /etc/mosquitto/conf.d/
	cat /etc/mosquitto/mosquitto.conf
	sudo service mosquitto restart
	sleep 2
	cat /var/log/mosquitto/mosquitto.log|grep mosquitto
	-netcat -zv 127.0.0.1 1-9999 2>&1|grep succeeded
	@echo
	@echo "Dependencies for ${MODULENAME} finished."

directories:
	-sudo mkdir /opt/janitoo
	-sudo chown -Rf ${USER}:${USER} /opt/janitoo
	-for dir in cache cache/janitoo_manager home log run etc init; do mkdir /opt/janitoo/$$dir; done

travis-deps: deps
	sudo apt-get -y install libevent-2.0-5
	pip install git+git://github.com/bibi21000/janitoo@master
	pip install git+git://github.com/bibi21000/janitoo_nosetests@master
	@echo
	@echo "Travis dependencies for ${MODULENAME} installed."

docker-deps:
	-cp -rf docker/config/* /opt/janitoo/etc/
	-cp -rf docker/supervisor.conf.d/* /etc/supervisor/janitoo.conf.d/
	-cp -rf docker/supervisor-tests.conf.d/* /etc/supervisor/janitoo-tests.conf.d/
	-cp -rf docker/nginx/* /etc/nginx/conf.d/
	true
	@echo
	@echo "Docker dependencies for ${MODULENAME} installed."

appliance-deps:
	-cp -rf docker/appliance/* /opt/janitoo/etc/
	-cp -rf docker/supervisor.conf.d/* /etc/supervisor/janitoo.conf.d/
	-cp -rf docker/nginx/* /etc/nginx/conf.d/
	@echo
	@echo "Appliance dependencies for ${MODULENAME} installed."

docker-tests:
	@echo
	@echo "Docker tests for ${MODULENAME} start."
	[ -f tests/test_docker.py ] && $(NOSE) $(NOSEOPTS) $(NOSEDOCKER) tests/test_docker.py
	@echo
	@echo "Docker tests for ${MODULENAME} finished."

docker-local-pull:
	@echo
	@echo "Pull local docker for ${MODULENAME}."
	docker pull bibi21000/${MODULENAME}
	@echo
	@echo "Docker local for ${MODULENAME} pulled."

docker-local-store: docker-local-pull
	@echo
	@echo "Create docker local store for ${MODULENAME}."
	docker create -v /root/.ssh/ -v /opt/janitoo/etc/ --name ${DOCKERNAME}_store bibi21000/${MODULENAME} /bin/true
	@echo
	@echo "Docker local store for ${MODULENAME} created."

docker-local-running: docker-local-pull
	@echo
	@echo "Update local docker for ${MODULENAME}."
	-docker stop ${DOCKERNAME}_running
	-docker rm ${DOCKERNAME}_running
	docker create --volumes-from ${DOCKERNAME}_store -p 8885:22 --name ${DOCKERNAME}_running bibi21000/${MODULENAME}
	docker ps -a|grep ${DOCKERNAME}_running
	docker start ${DOCKERNAME}_running
	docker ps|grep ${DOCKERNAME}_running
	@echo
	@echo "Docker local for ${MODULENAME} updated."
	@echo "Docker tests for ${MODULENAME} finished."

tests:
	-netcat -zv 127.0.0.1 1-9999 2>&1|grep succeeded
#~ ifneq ($(codename),precise)
	#~ #No websocket for precise
	#~ netcat -zv 127.0.0.1 1-9999 2>&1|grep succeeded|grep 9001
#~ endif
	$(NOSE) $(NOSEOPTS) tests
	@echo
	@echo "Tests for ${MODULENAME} finished."

certification:
	$(NOSE) --verbosity=2 --with-xunit --xunit-file=certification/result.xml certification
	@echo
	@echo "Certification for ${MODULENAME} finished."

build:
	${PYTHON_EXEC} setup.py build --build-base $(BUILDDIR)

egg:
	-mkdir -p $(BUILDDIR)
	-mkdir -p $(DISTDIR)
	${PYTHON_EXEC} setup.py bdist_egg --bdist-dir $(BUILDDIR) --dist-dir $(DISTDIR)

tar:
	-mkdir -p $(DISTDIR)
	tar cvjf $(DISTDIR)/${MODULENAME}-${janitoo_version}.tar.bz2 -h --exclude=\*.pyc --exclude=\*.egg-info --exclude=janidoc --exclude=.git* --exclude=$(BUILDDIR) --exclude=$(DISTDIR) --exclude=$(ARCHBASE) .
	@echo
	@echo "Archive for ${MODULENAME} version ${janitoo_version} created"

commit:
	-git add rst/
	-cp rst/README.rst .
	-git add README.rst
	git commit -m "$(message)" -a && git push
	@echo
	@echo "Commits for branch master pushed on github."

pull:
	git pull
	@echo
	@echo "Commits from branch master pulled from github."

status:
	git status

tag: check-tag commit
	git tag v${janitoo_version}
	git push origin v${janitoo_version}
	@echo
	@echo "Tag pushed on github."

check-tag:
ifneq ('${TAGGED}','0')
	echo "Already tagged with version ${janitoo_version}"
	@/bin/false
endif

new-version: tag clean tar
	@echo
	@echo "New version ${janitoo_version} created and published"

debch:
	dch --newversion ${janitoo_version} --maintmaint "Automatic release from upstream"

deb:
	dpkg-buildpackage
