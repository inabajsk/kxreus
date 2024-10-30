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
	kxranimate kxrdyna kxrbody kxrbodyset kxrlinks kxrmodels kxrviewer m5models \
	kxrboards 

endif
ifeq ($(ARCHDIR), LinuxARM)
COMMONOBJS=utils eus2wrl rcb4sample tiny-xml \
	armh7interface eus2mjcf ftdi uart kxrextentions\
	rcb4asm rcb4file rcb4interface rcb4robots rcb4lisp rcb4machine\
	kxranimate kxrdyna kxrbody kxrbodyset kxrlinks kxrmodels kxrviewer m5models \
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
ifneq ($(ARCHDIR), Linux64)
EUSCCFLAGS=-Di386 -DLinux -w -malign-functions=4 -DGCC3 -DGCC -DTHREADED -DPTHREAD -fpic -O2
else
EUSCCFLAGS=-Dx86_64 -DLinux -w -malign-functions=8 -DGCC3 -DGCC -DTHREADED -DPTHREAD -fPIC -O2
endif

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
lisp: $(LIBOBJECTS)
	touch ~/.eusrc
	cp -f ~/.eusrc ~/.eusrc-old
	export LD_LIBRARY_PATH=$(PWD)/$(ARCHDIR)/lib:$(LD_LIBRARY_PATH);  $(EUSLISP) < $(COMPILE)
	install -m 0644 eusrc.l $(HOME)/.eusrc
	install -m 0644 rcb4robotconfig.l $(LIBDIR)
	touch glbodies/*

all: libs dir lisp gen

gen:
	irteusgl kxranimate.l "(progn (kxr-sample-robots) (exit))"

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
	sudo apt-get install -y ros-$(ROS_DISTRO)-roseus
dir:
	install -m 0755 -d $(ARCHDIR)
	install -m 0755 -d $(LIBDIR)
	install -m 0755 -d $(OBJDIR)


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

