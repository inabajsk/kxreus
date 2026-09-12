#########################################################################
# Customizable section begins
#########################################################################
PWD=$(shell pwd)

#################################################################
# end of the customizable section
################################################################
ifeq ($(ARCHDIR), "")
ARCHDIR=$(shell /bin/uname |sed s/-.*// |sed s/_.*//)
endif

#LIBDIR=$(EUSDIR)/$(ARCHDIR)/lib
#OBJDIR=$(EUSDIR)/$(ARCHDIR)/obj
#LIBDIR=$(ARCHDIR)/lib
#OBJDIR=$(ARCHDIR)/obj
LIBDIR=$(PWD)/$(ARCHDIR)/lib
OBJDIR=$(PWD)/$(ARCHDIR)/obj
BINDIR=$(PWD)/$(ARCHDIR)/bin

CC=gcc
ifneq ($(ARCHDIR), Linux64)
CCFLAGS=-g -O2 -D$(ARCHDIR) -fno-exceptions -fomit-frame-pointer -ffast-math -fpic
else
CCFLAGS=-g -O2 -D$(ARCHDIR) -fno-exceptions -fomit-frame-pointer -ffast-math -fPIC
endif
EUSLISP=irteusgl
LDFLAGS=

#COMMONOBJS=x11colors dutil dworld drobot
ifeq ($(ARCHDIR), Linux64)
COMMONOBJS=utils eus2wrl rcb4sample tiny-xml nn cblaslib mnist\
	armh7interface eus2mjcf ftdi ics uart humanmodel inertia kxrextentions\
	rcb4asm rcb4file rcb4interface rcb4robots rcb4lisp rcb4machine\
	kxranimate kxrdyna kxr-body-minus-holes kxr-stl-cache kxrbody kxrbodyset kxrlinks kxrmodels kxrviewer m5models \
	kxrboards

endif
ifeq ($(ARCHDIR), LinuxARM)
COMMONOBJS=utils eus2wrl rcb4sample tiny-xml \
	armh7interface eus2mjcf ftdi uart kxrextentions\
	rcb4asm rcb4file rcb4interface rcb4robots rcb4lisp rcb4machine\
	kxranimate kxrdyna kxr-body-minus-holes kxr-stl-cache kxrbody kxrbodyset kxrlinks kxrmodels kxrviewer m5models \
	kxrboards eus2webots vrmlParser wbtNodeSpec vrmlNodeSpec
endif

OBJS+=$(COMMONOBJS)
COMPILE=compile-all.l

OBJS+=$(JSKOBJS)

### Linux
CPP=g++
LSFX=so
LPFX=lib
OSFX=o
LDFLAGS= 
MSLD=$(LD)
MSOUT=-o 
MSLDFLAGS=$(LDFLAGS) -lglut -lGL -lGLU -lm
ASFX=a
IMPLIB=

# ifneq ($(ARCHDIR), Linux64)
# EUSCCFLAGS=-Di386 -DLinux -w -malign-functions=4 -DGCC3 -DGCC -DTHREADED -DPTHREAD -fpic -O2
# else
# EUSCCFLAGS=-Dx86_64 -DLinux -w -malign-functions=8 -DGCC3 -DGCC -DTHREADED -DPTHREAD -fPIC -O2
# endif

EUSLDFLAGS=
ifeq ($(shell /bin/uname -m), x86_64)
ifneq ($(ARCHDIR), Linux64)
CC += -m32 -DUSE_MULTI_LIB
CPP += -m32 -DUSE_MULTI_LIB
endif
endif


LD=$(CPP) -shared


BMODULES=$(addprefix $(OBJDIR)/, $(addsuffix .$(LSFX),$(OBJS)))
BMODULESOBJ=$(addprefix $(OBJDIR)/, $(addsuffix .$(OSFX),$(OBJS)))

# 
lisp: dir $(LIBOBJECTS)
	touch ~/.eusrc
	cp -f ~/.eusrc ~/.eusrc-old
	export LD_LIBRARY_PATH=$(PWD)/$(ARCHDIR)/lib:$(LD_LIBRARY_PATH);  $(EUSLISP) < $(COMPILE)
	install -m 0644 eusrc.l $(HOME)/.eusrc
	install -m 0644 rcb4robotconfig.l $(LIBDIR)
	touch glbodies/*

all: libs lisp gen

gen:
	irteusgl kxranimate.l "(progn (kxr-sample-robots :sample 1) (exit))"

#	irteusgl kxranimate.l "(progn (kxr-sample-robots) (exit))"

regen:
	irteusgl kxranimate.l "(progn (kxr-sample-robots :generate t) (exit))"

libs:	
	sudo apt-get install -y libftdi-dev
	sudo apt-get install -y libopenblas-dev
	sudo apt-get install -y cmake
	sudo apt-get install -y gifsicle
	sudo apt-get install -y binutils-arm-none-eabi
	sudo install -m 0755 udevs/99-my-rcb4.rules /etc/udev/rules.d/
	sudo install -m 0755 udevs/99-my-ftdi-akizuki.rules /etc/udev/rules.d/
	sudo install -m 0755 udevs/99-my-ftdi-future.rules /etc/udev/rules.d/
	sudo install -m 0755 udevs/99-my-m5stack.rules /etc/udev/rules.d/
	sudo udevadm control --reload-rules && sudo udevadm trigger
#	sudo apt-get install -y ros-$(ROS_DISTRO)-roseus
dir: check-jskeus
	mkdir -p $(ARCHDIR)
	mkdir -p $(LIBDIR)
	mkdir -p $(OBJDIR)
	mkdir -p $(BINDIR)
#	install -m 0755 -d $(ARCHDIR)
#	install -m 0755 -d $(LIBDIR)
#	install -m 0755 -d $(OBJDIR)


#
# clean
#
clean-objects:
	cd work; rm -f $(addsuffix .c,$(OBJS))
	cd work; rm -f $(addsuffix .h,$(OBJS))
	cd work; rm -f $(addsuffix .o,$(OBJS))

clean-models:
	rm -rf models

clean:
	make clean-objects
	rm -f $(BMODULES) $(BMODULESOBJ) eusrc.l
	rm -rf $(ARCHDIR) meshes daes glbodies urdf work wrls yamls

clean-all:
	make clean
	make clean-models

get-eus:
	wget http://www.dh.aist.go.jp/~t.matsui/ftp/eus826/eus826.tar.gz

build-eus:
	(cd $(EUSDIR)/..;\
	 patch -p0 < $(PWD)/eus826.patch)
	(cd $(EUSDIR)/lisp;\
	make -f Makefile.Linux.thread clean eus0 eus1 eus2 eusg eusx eus eusgl)

#
# jskeus, built from our own inabajsk forks instead of upstream euslisp/*.
# Use this while a fix is only merged into our fork and not yet upstream
# (e.g. a pending PR) -- it clones and builds jskeus/EusLisp from
# inabajsk's branches instead of waiting for the PR to land.
#
JSKEUS_DIR ?= $(HOME)/jskeus
JSKEUS_GIT_URL ?= git@github.com:inabajsk/jskeus
JSKEUS_GIT_BRANCH ?= master
EUS_GIT_URL ?= git@github.com:inabajsk/EusLisp
EUS_GIT_BRANCH ?= glu-tess-collector

# run as a prerequisite of dir: (and so of every build) -- only actually
# clones+builds jskeus when $(JSKEUS_DIR) doesn't exist yet, so a normal
# build with jskeus already present pays just a directory check.
check-jskeus:
	@if [ ! -d $(JSKEUS_DIR) ]; then \
		echo "$(JSKEUS_DIR) not found -- building jskeus from $(JSKEUS_GIT_URL) first"; \
		$(MAKE) jskeus; \
	fi

jskeus:
	if [ ! -d $(JSKEUS_DIR) ]; then \
		git clone $(JSKEUS_GIT_URL) -b $(JSKEUS_GIT_BRANCH) $(JSKEUS_DIR); \
	fi
	$(MAKE) -C $(JSKEUS_DIR) GIT_EUSURL=$(EUS_GIT_URL) GIT_EUSBRANCH=$(EUS_GIT_BRANCH) all

# kxreus's own .so files are built against a specific jskeus core; after
# (re)building jskeus above, kxreus must be rebuilt from clean or it will
# crash against the new core's ABI. This runs both steps in order.
rebuild-with-jskeus: jskeus
	make clean
	make

