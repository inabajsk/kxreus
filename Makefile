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
dir: check-jskeus check-roseus
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

#
# roseus built against $(JSKEUS_DIR) (inabajsk/jskeus) instead of the apt
# ros-$(ROS_DISTRO)-euslisp/jskeus. jsk_roseus is cloned into a catkin
# workspace $(ROSEUS_WS) together with thin euslisp/jskeus wrapper packages
# (ros/euslisp, ros/jskeus) that point EUSDIR at $(JSKEUS_DIR)/eus, so that
# roseus.so is compiled with our eus.h and bin/roseus runs our irteusgl.
# After make roseus:
#   source $(ROSEUS_WS)/devel/setup.bash; roseus
# -fpermissive: inabajsk/EusLisp eus_proto.h prototypes defun() strictly, and
# roseus.cpp/eustf.cpp still pass (pointer (*)()) casts, an error in C++.
#
ROS_DISTRO ?= $(firstword $(notdir $(wildcard /opt/ros/one /opt/ros/noetic /opt/ros/melodic)))
ROS_SETUP ?= /opt/ros/$(ROS_DISTRO)/setup.bash
ROSEUS_WS ?= $(HOME)/roseus_ws
ROSEUS_GIT_URL ?= https://github.com/jsk-ros-pkg/jsk_roseus
ROSEUS_GIT_BRANCH ?= master

roseus: check-jskeus
	@if [ ! -f $(ROS_SETUP) ]; then \
		echo "$(ROS_SETUP) not found -- install ROS (noetic/one) first"; exit 1; \
	fi
	mkdir -p $(ROSEUS_WS)/src
	if [ ! -d $(ROSEUS_WS)/src/jsk_roseus ]; then \
		git clone $(ROSEUS_GIT_URL) -b $(ROSEUS_GIT_BRANCH) $(ROSEUS_WS)/src/jsk_roseus; \
	fi
	rm -rf $(ROSEUS_WS)/src/kxreus_euslisp
	cp -r $(PWD)/ros $(ROSEUS_WS)/src/kxreus_euslisp
	bash -c 'source $(ROS_SETUP) && cd $(ROSEUS_WS) && \
		rosdep install -r -y -i --from-paths src/jsk_roseus/roseus --ignore-src --skip-keys "euslisp jskeus"; \
		catkin init && \
		catkin config --extend /opt/ros/$(ROS_DISTRO) --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS=-fpermissive -DJSKEUS_DIR=$(JSKEUS_DIR) && \
		catkin build euslisp jskeus roseus'
	@echo "roseus built with $(JSKEUS_DIR). Use: source $(ROSEUS_WS)/devel/setup.bash; roseus"

# run as a prerequisite of dir: (and so of every build), like check-jskeus --
# builds roseus only when $(ROSEUS_WS)/devel/bin/roseus doesn't exist yet.
# Skipped (not an error) when ROS is not installed.
check-roseus: check-jskeus
	@if [ ! -f $(ROS_SETUP) ]; then \
		echo "$(ROS_SETUP) not found -- skip building roseus"; \
	elif [ ! -x $(ROSEUS_WS)/devel/bin/roseus ]; then \
		echo "$(ROSEUS_WS)/devel/bin/roseus not found -- building roseus with $(JSKEUS_DIR) first"; \
		$(MAKE) roseus; \
	fi

clean-roseus:
	rm -rf $(ROSEUS_WS)/build $(ROSEUS_WS)/devel $(ROSEUS_WS)/logs


#
# EusView demo (eusview.l): irtviewer + X panels like the EusView iPhone/Mac app
# (robot chooser KXR/KHR/JSK, poses, project motions by the RCB4 emulation, ODE, live).
#   make eusview           run it from this terminal (REPL)
#   make eusview-desktop   Ubuntu: a launcher icon (applications menu + desktop) that runs eusview.sh
#   make eusview-desktop EUSVIEW_TERMINAL=true   open it in a terminal (with the REPL)
#   make eusview-desktop-clean
#
EUSVIEW_TERMINAL ?= false
EUSVIEW_OS ?= $(shell /usr/bin/uname -s)
EUSVIEW_APPS_DIR ?= $(HOME)/.local/share/applications
EUSVIEW_DESKTOP_FILE = $(EUSVIEW_APPS_DIR)/eusview.desktop

# physics of eusview.l without kxrdyna.l: ODE through eusview-ode/odesim.cpp (the EusView app's
# C layer) -> $(EUSVIEW_ODE_LIB), loaded by eusview-physics.l (defforeign).
#   Ubuntu: sudo apt install libode-dev; make eusview-ode
#   macOS : ODE_DIR=<dir with libode.a and Headers/ or include/> make eusview-ode
EUSVIEW_UNAME = $(shell /usr/bin/uname -s)-$(shell /usr/bin/uname -m)
EUSVIEW_ARCH ?= $(or $(ARCHDIR),$(if $(filter Linux-x86_64,$(EUSVIEW_UNAME)),Linux64,$(if $(filter Linux-%,$(EUSVIEW_UNAME)),LinuxARM,$(shell /usr/bin/uname -s))))
EUSVIEW_ODE_LIB = $(PWD)/$(EUSVIEW_ARCH)/lib/libeusviewode.so
ODE_DIR ?= $(firstword $(wildcard $(HOME)/mnist/eusview/ios/third_party/ODE.xcframework/macos-$(shell /usr/bin/uname -m)))
EUSVIEW_ODE_SRC = eusview-ode/odesim.cpp eusview-ode/eusviewode.cpp

eusview-ode: $(EUSVIEW_ODE_LIB)

$(EUSVIEW_ODE_LIB): $(EUSVIEW_ODE_SRC) eusview-ode/odesim.h
	@mkdir -p $(dir $@)
	@if [ "$(EUSVIEW_OS)" = Darwin ]; then \
		if [ -z "$(ODE_DIR)" ] || [ ! -f "$(ODE_DIR)/libode.a" ]; then \
			echo "eusview-ode: set ODE_DIR to a directory with libode.a and Headers/ode (or include/ode), e.g. brew install ode -> ODE_DIR=$$(brew --prefix 2>/dev/null)/opt/ode/lib"; exit 1; fi; \
		INC=$$( [ -d "$(ODE_DIR)/Headers" ] && echo "$(ODE_DIR)/Headers" || echo "$(ODE_DIR)/../include" ); \
		echo "c++ ... $(ODE_DIR)/libode.a -> $@"; \
		c++ -O2 -fPIC -shared -std=c++14 -include algorithm -I$$INC -o $@ $(EUSVIEW_ODE_SRC) $(ODE_DIR)/libode.a || exit 1; \
	else \
		if pkg-config --exists ode 2>/dev/null; then \
			CF="$$(pkg-config --cflags ode)"; LF="$$(pkg-config --libs ode)"; \
		elif [ -f /usr/include/ode/ode.h ]; then CF="-DdDOUBLE"; LF="-lode"; \
		else echo "eusview-ode: ODE not found -- sudo apt install libode-dev"; exit 1; fi; \
		echo "g++ ... $$CF $$LF -> $@"; \
		g++ -O2 -fPIC -shared -std=c++14 -include algorithm $$CF -o $@ $(EUSVIEW_ODE_SRC) $$LF || exit 1; \
	fi
	@echo "eusview-ode: $@"

eusview:
	-@$(MAKE) --no-print-directory eusview-ode || echo "eusview-ode failed: eusview runs without physics"
	./eusview.sh $(ROBOT)

eusview-desktop:
	-@$(MAKE) --no-print-directory eusview-ode || echo "eusview-ode failed: eusview runs without physics (sudo apt install libode-dev; make eusview-ode)"
	@if [ "$(EUSVIEW_OS)" != Linux ]; then \
		echo "eusview-desktop: the freedesktop launcher is for Ubuntu (Linux) -- nothing made on $(EUSVIEW_OS). Run: make eusview"; \
	else \
		chmod +x $(PWD)/eusview.sh; \
		mkdir -p $(EUSVIEW_APPS_DIR); \
		{ echo "[Desktop Entry]"; \
		  echo "Type=Application"; \
		  echo "Version=1.0"; \
		  echo "Name=EusView"; \
		  echo "Comment=EusLisp robot viewer (kxreus): KXR/KHR/JSK robots, poses, motions, ODE"; \
		  echo "Comment[ja]=EusLisp のロボットビューア（kxreus）: KXR/KHR/JSK のロボット・姿勢・モーション・物理"; \
		  echo "Exec=$(PWD)/eusview.sh"; \
		  echo "Path=$(PWD)"; \
		  echo "Icon=$(PWD)/images/eusview.png"; \
		  echo "Terminal=$(EUSVIEW_TERMINAL)"; \
		  echo "Categories=Education;Science;Robotics;"; \
		  echo "StartupNotify=true"; \
		} > $(EUSVIEW_DESKTOP_FILE); \
		chmod +x $(EUSVIEW_DESKTOP_FILE); \
		DESK=$$(xdg-user-dir DESKTOP 2>/dev/null); \
		if [ -z "$$DESK" ] || [ "$$DESK" = "$(HOME)" ] || [ ! -d "$$DESK" ]; then \
			for d in "$(HOME)/Desktop" "$(HOME)/デスクトップ"; do [ -d "$$d" ] && DESK="$$d" && break; done; \
		fi; \
		if [ -n "$$DESK" ] && [ -d "$$DESK" ] && [ "$$DESK" != "$(HOME)" ]; then \
			cp $(EUSVIEW_DESKTOP_FILE) "$$DESK/eusview.desktop"; \
			chmod +x "$$DESK/eusview.desktop"; \
			if command -v gio >/dev/null 2>&1; then gio set "$$DESK/eusview.desktop" metadata::trusted true 2>/dev/null || true; fi; \
			echo "eusview-desktop: $$DESK/eusview.desktop"; \
		else \
			echo "eusview-desktop: no desktop folder (xdg-user-dir DESKTOP) -- only the applications menu"; \
		fi; \
		if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database $(EUSVIEW_APPS_DIR) 2>/dev/null || true; fi; \
		if command -v desktop-file-validate >/dev/null 2>&1; then desktop-file-validate $(EUSVIEW_DESKTOP_FILE) || true; fi; \
		echo "eusview-desktop: $(EUSVIEW_DESKTOP_FILE) (Exec=$(PWD)/eusview.sh)"; \
		echo "  GNOME: if the icon shows a cross, right-click it -> 'Allow Launching'"; \
	fi

eusview-desktop-clean:
	rm -f $(EUSVIEW_DESKTOP_FILE)
	DESK=$$(xdg-user-dir DESKTOP 2>/dev/null); for d in "$$DESK" "$(HOME)/Desktop" "$(HOME)/デスクトップ"; do [ -n "$$d" ] && rm -f "$$d/eusview.desktop"; done; true
