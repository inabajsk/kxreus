;;;
;;; eusview-xft.l : UTF-8 (Japanese) labels for EusLisp X panels with Xft (libXft + fontconfig)
;;;	2026.10.5
;;;
;;;  The X core fonts of EusLisp's panels have no Japanese: the motion names of the .h4p projects
;;;  (UTF-8) are shown as garbage. This file draws the labels with Xft instead (defforeign into
;;;  libXft; no compile). Used by eusview.l and kxrviewer.l (robot-control-panel motion menus,
;;;  read at run time from *rcb4eus-dir*, so the compiled kxrviewer.so works without it):
;;;
;;;   (xft-init)                         t if Xft and a Japanese font were found (else nil: fall back)
;;;   x::xft-button-item                 button-item whose label is drawn with Xft (UTF-8)
;;;   x::xft-label-item                  a label (not a button), (send item :value "テキスト")
;;;   (send panel :create-item x::xft-button-item "前進" receiver :method)
;;;   (send menu-panel :create-item x::xft-button-item "12 XL2G_歩行" receiver (list :method 12))
;;;
;;;  Fonts (fontconfig names, first one that has "あ"): *xft-font-names*, or EUSVIEW_FONT="name".
;;;  Ubuntu: libxft2 (installed with X), fonts-noto-cjk (or fonts-ipafont / fonts-takao).
;;;  macOS: XQuartz /opt/X11/lib/libXft.2.dylib, Hiragino / BIZ UD fonts.
;;;

(defvar *xft-font-names*
  '("Noto Sans CJK JP" "Noto Sans JP" "IPAGothic" "IPAPGothic" "TakaoGothic" "TakaoPGothic"
    "VL Gothic" "BIZ UDPGothic" "Hiragino Sans" "Hiragino Kaku Gothic ProN" "Hiragino Kaku Gothic Pro"))
(defvar *xft-pixel-size* 14)
(defvar *xft-lib* nil)
(defvar *xft-font* nil)         ;; XftFont *
(defvar *xft-font-name* nil)
(defvar *xft-black* nil)        ;; XftColor (16 bytes)
(defvar *xft-tried* nil)
(defvar *xft-ascent* 12)
(defvar *xft-height* 16)

(defun xft-lib-candidates ()
  (if (memq :darwin *features*)
      '("/opt/X11/lib/libXft.2.dylib" "/opt/X11/lib/libXft.dylib" "/usr/local/lib/libXft.2.dylib"
        "/opt/homebrew/lib/libXft.2.dylib")
    '("/usr/lib/x86_64-linux-gnu/libXft.so.2" "/usr/lib/aarch64-linux-gnu/libXft.so.2"
      "/usr/lib/arm-linux-gnueabihf/libXft.so.2" "/usr/lib64/libXft.so.2" "/usr/lib/libXft.so.2")))

(defun xft-protect-call (fn)
  (catch :xft-error
    (let ((*error-handler* #'(lambda (&rest args)
                                (format *error-output* ";; xft: ~A~%" (elt args 1))
                                (throw :xft-error nil))))
      (funcall fn))))

(defun xft-load ()
  (unless *xft-lib*
    (let ((f (find-if #'probe-file (xft-lib-candidates))) m)
      (when f
        (setq m (xft-protect-call #'(lambda () (load-foreign f))))
        (when m
          (defforeign xft-font-open-name m "XftFontOpenName" (:integer :integer :string) :integer)
          (defforeign xft-char-exists m "XftCharExists" (:integer :integer :integer) :integer)
          (defforeign xft-draw-create m "XftDrawCreate" (:integer :integer :integer :integer) :integer)
          (defforeign xft-draw-destroy m "XftDrawDestroy" (:integer) :integer)
          (defforeign xft-color-alloc-name m "XftColorAllocName" (:integer :integer :integer :string :string) :integer)
          (defforeign xft-draw-string-utf8 m "XftDrawStringUtf8"
            (:integer :string :integer :integer :integer :string :integer) :integer)
          (defforeign xft-text-extents-utf8 m "XftTextExtentsUtf8"
            (:integer :integer :string :integer :string) :integer)
          (setq *xft-lib* m)))))
  *xft-lib*)

(defun xft-short (s i &optional signed)
  "16 bit integer at byte i of string s (little endian)"
  (let ((v (+ (elt s i) (* 256 (elt s (1+ i))))))
    (if (and signed (>= v 32768)) (- v 65536) v)))

(defun xft-extents (str)
  "(width height y x-advance) of the UTF-8 string str (pixels)"
  (let ((gi (make-string 12)))
    (xft-text-extents-utf8 x::*display* *xft-font* str (length str) gi)
    (list (xft-short gi 0) (xft-short gi 2) (xft-short gi 6 t) (xft-short gi 8 t))))

(defun xft-colormap ()
  (unless (fboundp 'x::DefaultColormap) ;; not in every EusLisp X build: XDefaultColormap of libX11
    (eval `(defforeign x::DefaultColormap ,*xft-lib* "XDefaultColormap" (:integer :integer) :integer)))
  (x::DefaultColormap x::*display* x::*screen-no*))

(defun xft-init (&optional force)
  "open a Japanese font with Xft; t if ok (nil without libXft / a Japanese font / errors)"
  (when (or force (not *xft-tried*))
    (setq *xft-tried* t)
    (unless (xft-protect-call #'(lambda () (xft-init-1) t))
      (setq *xft-font* nil)))
  (if *xft-font* t nil))
(defun xft-init-1 ()
  (progn
    (setq *xft-tried* t *xft-font* nil)
    (when (and (boundp 'x::*display*) (numberp x::*display*) (/= x::*display* 0) (xft-load))
      (dolist (name (append (if (unix:getenv "EUSVIEW_FONT") (list (unix:getenv "EUSVIEW_FONT")))
                            *xft-font-names*))
        (let ((f (xft-font-open-name x::*display* x::*screen-no*
                                     (format nil "~A:pixelsize=~A" name *xft-pixel-size*))))
          (when (and (numberp f) (/= f 0) (/= 0 (xft-char-exists x::*display* f #x3042)))
            (setq *xft-font* f *xft-font-name* name)
            (return))))
      (when *xft-font*
        (setq *xft-black* (make-string 16))
        (xft-color-alloc-name x::*display* x::*visual* (xft-colormap) "black" *xft-black*)
        (let ((e (xft-extents "あAg")))
          (setq *xft-ascent* (max 8 (elt e 2)) *xft-height* (max 12 (+ (elt e 1) 2))))
        (format t ";; xft: font ~S (~A px)~%" *xft-font-name* *xft-pixel-size*)))))

(defun xft-draw-string (win x y str)
  "draw the UTF-8 string str in the X window win at x, baseline y"
  (let ((d (get win :xft-draw)))
    (unless d
      (setq d (xft-draw-create x::*display* (send win :drawable) x::*visual* (xft-colormap)))
      (setf (get win :xft-draw) d))
    (xft-draw-string-utf8 d *xft-black* *xft-font* x y str (length str))))

(in-package "X")

(defclass xft-button-item :super button-item :slots (xft-width))
(defmethod xft-button-item
  (:create
   (label receiver method &rest args &key width &allow-other-keys)
   (send-super* :create label receiver method args)
   (when user::*xft-font*
     (setq xft-width (car (user::xft-extents label)))
     (send self :resize (max (or width 0) (+ xft-width 12)) (+ user::*xft-height* 8)))
   self)
  (:label
   (&optional newlab (min-width 10))
   (if (and newlab user::*xft-font*)
       (progn (setq label newlab xft-width (car (user::xft-extents newlab)))
              (send self :resize (max min-width (+ xft-width 12)) (+ user::*xft-height* 8))
              label)
     (send-super :label newlab min-width)))
  (:draw-label
   (&optional (state :up) (color bg-color) (border 2) (offset))
   (cond
    ((null user::*xft-font*) (send-super :draw-label state color border offset))
    (t
     (send self :3d-fill-rectangle 0 0 width height border
           light-edge-color dark-edge-color bg-color topleft-edge-polygon state)
     (unless offset (setq offset (or (cdr (assoc state '((:up . 0) (:down . 2) (:flat . 1)))) 0)))
     (send self :flush)
     (user::xft-draw-string self (+ (if (derivedp parent menu-panel) 6 (max 4 (/ (- width (or xft-width 0)) 2))) offset)
                            (+ (/ (- height user::*xft-height*) 2) user::*xft-ascent* offset) label)
     (send self :flush)))))

;; a label: left aligned, flat, no action. (send item :value "...")
(defclass xft-label-item :super xft-button-item :slots (fixed-width))
(defmethod xft-label-item
  (:create
   (label &rest args &key (width 400) &allow-other-keys)
   (setq fixed-width width)
   (send-super* :create label nil nil :width width :state :flat args)
   (send self :resize width (if user::*xft-font* (+ user::*xft-height* 8) (send self :height)))
   self)
  (:value
   (&optional v)
   (when v
     (setq label v)
     (if user::*xft-font* (setq xft-width (car (user::xft-extents v)))
       (setf labeldots (textdots v fontid)))
     (send self :draw-label :flat))
   label)
  (:draw-label
   (&optional (state :flat) (color bg-color) (border 2) (offset))
   (cond
    ((null user::*xft-font*)
     (send self :3d-fill-rectangle 0 0 width height border
           light-edge-color dark-edge-color bg-color topleft-edge-polygon :flat)
     (send self :string 6 (+ (/ height 2) (/ (- (aref labeldots 0) (aref labeldots 1)) 2)) label)
     (send self :flush))
    (t
     (send self :3d-fill-rectangle 0 0 width height border
           light-edge-color dark-edge-color bg-color topleft-edge-polygon :flat)
     (send self :flush)
     (user::xft-draw-string self 6 (+ (/ (- height user::*xft-height*) 2) user::*xft-ascent*) label)
     (send self :flush))))
  (:ButtonPress (event) nil)
  (:ButtonRelease (event) nil)
  (:EnterNotify (event) nil))

(in-package "USER")
(provide :eusview-xft)
