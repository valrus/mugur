;;; ergodox.el --- Configure and flash the Ergodox keyboard -*- lexical-binding: t -*-

(require 's)

(let ((keycodes (make-hash-table :test 'equal))
      (modtap-keys (make-hash-table :test 'equal))
      (modifier-keys (make-hash-table :test 'equal)))
  (defun set-keycodes ()
    (cl-dolist (entry
         '(;; Letters and Numbers
           (a) (b) (c) (d) (e) (f) (g) (h) (i) (j) (k) (l) (m) (n)
           (o) (p) (q) (r) (s) (t) (u) (v) (w) (x) (y) (z)           
           (1) (2) (3) (4) (5) (6) (7) (8) (9) (0)

           ;; F Keys
           (F1)  (F2)  (F3)  (F4)  (F5)  (F6)  (F7)  (F8)  (F9)  (F10)
           (F11) (F12) (F13) (F14) (F15) (F16) (F17) (F18) (F19) (F20)
           (F21) (F22) (F23) (F24)
           
           ;; Punctuation
           (ENT "enter")  (ESC "escape")   (bspace) (TAB "tab")
           (space "space")     (- "minus")    (= "equal")
           (lbracket "lbracket") ("[" "lbracket")
           (rbracket "rbracket") ("]" "rbracket") (\ "bslash")
           (nonus-hash "nonus_hash") (colon "scolon")   (quote "quote") (grave "grave")
           (comma "comma")      (dot "dot")      (/ "slash")
           
           ;; Shifted Keys
           (~ "tilde") (! "exclaim") (@ "at")
           (hash)  ($ "dollar")  (% "percent")
           (^ "circumflex") (& "ampersand") (* "asterix")
           (left-paren "left_paren") (right-paren "right_paren")
           (_ "underscore") (+ "plus")
           (left-curly "left_curly_brace") (right-curly "right_curly_brace")
           ({ "left_curly_brace") (} "right_curly_brace")
           (| "pipe") (: "colon") (double-quote "double_quote")
           (< "left_angle_bracket") (> "right_angle_bracket")
           (? "question")
           
           ;; Modifiers
           (CC "lctrl") (MM "lalt")
           (SS "lshift") (GG "lgui")

           ;; Commands
           (<insert> "insert") ("<home>" "home") ("<prior>" "pgup")
           ("<delete>" "delete") ("<end>" "end")   ("<next>" "pgdown")
           ("<right>" "right")   ("<left>" "left") ("<down>" "down")
           ("<up>" "up")

           ;; Media Keys
           ("vol_up" "audio_vol_up") ("vol_down" "audio_vol_down")
           ("mute" "audio_mute") ("stop" "media_stop")

           ;; Mouse Keys
           (ms-up) (ms-down) (ms-left) (ms-right)
           (ms-btn1) (ms-btn2) (ms-btn3) (ms-btn4) (ms-btn5)
           (ms-wh-up) (ms-wh-down) (ms-wh-left) (ms-wh-right)
           (ms-accel1) (ms-accel2) (ms-accel3)
           
           ;; Special Keys
           (--- "_x_") (() "___"))
               keycodes)
      (puthash (car entry)
               (if (= (length entry) 2)
                   (cadr entry)
                 (if (numberp (car entry))
                     (number-to-string (car entry))
                   (symbol-name (car entry))))
               keycodes)))
 
  (defun set-modtap-keys ()
    (cl-dolist (entry '((C "MOD_LCTL")
                        (M "MOD_LALT")
                        (S "MOD_LSFT")
                        (G "MOD_LGUI"))
                      modtap-keys)
      (puthash (car entry) (cadr entry) modtap-keys))
    (setf set t))

  (defun set-modifier-keys ()
    (cl-dolist (entry '((C     "LCTL")
                        (M     "LALT")
                        (S     "LSFT")
                        (G     "LWIN")
                        (C-M   "LCA")
                        (C-M-S "MEH")
                        (C-M-G "HYPR"))
                      modifier-keys)
      (puthash (car entry) (cadr entry) modifier-keys))
    (setf set t))
  
  (defun keycode (key)
    (if (not (hash-table-empty-p keycodes))
        (awhen (gethash key keycodes)
          (if (or (not key) (equal key '---))
              ;; Handle the transparent key differently
              it
            (concat "KC_" (upcase it))))
      (set-keycodes)
      (keycode key)))

  (defun modtap-key (key)
    (if (not (hash-table-empty-p modtap-keys))
        (gethash key modtap-keys)
      (set-modtap-keys)
      (modtap-key key)))

  (defun modifier-key (key)
    (if (not (hash-table-empty-p modifier-keys))
        (gethash key modifier-keys)
      (set-modifier-keys)
      (modifier-key key))))

(defun layer-toggle (layer key)
  "LAYER when held, KEY when tapped."
  (s-format "LT($0, $1)" 'elt
            (list layer (keycode key))))

(defun modtap (mod key)
  "MOD when held, KEY when tapped."
  (s-format "MT($0, $1)" 'elt
            (list (modtap-key mod)
                  (keycode key))))

(defun modifier (mod key)
  "Hold MOD and press KEY."
  (s-format "$0($1)" 'elt
            (list (modifier-key mod)
                  (keycode key))))

(defun layer-switch (action layer)
  "Switch to the given LAYER."
  (format "%s(%s)"
          (upcase (symbol-name action))
          (upcase (symbol-name layer))))

(defun layer-switch-lm-or-lt (action layer mod-or-key)
  "Switch to the given LAYER (with tap or mod)"
  (let ((action-str (symbol-name action)))
    (format "%s(%s, %s)"
            (upcase (symbol-name action))
            (upcase (symbol-name layer))
            (if (string-equal action-str "lm")
                (modifier-key mod-or-key)
              (keycode mod-or-key)))))

(defun one-shot-mod (mod)
  "Hold down MOD for one key press only."
  (format "OSM(%s)" (modtap-key mod)))

(defun one-shot-layer (layer)
  "Switch to LAYER for one key press only."
  (format "OSL(%s)" (upcase (symbol-name layer))))

(cl-defstruct layer
  name pos keys)

(let (layers)
  (defun transform-keys (keys)
    (mapcar (lambda (key)
         (pcase key
           (`() (keycode '()))
           ((and `(,mod)
                 (guard (and (symbolp mod)
                             (let ((items (s-split "-" (symbol-name mod))))
                               ;; Is the first char a modifier key?
                               (modifier-key (intern (car items)))))))
            (let ((items (s-split "-" (symbol-name mod))))
              (modifier (intern (car items))
                        (intern (cadr items)))))
           (`(,s) (keycode s))
           (`(mod-tap ,mod ,key) (modtap mod key))
           (`(osm ,mod) (one-shot-mod mod))
           (`(osl ,layer) (one-shot-layer layer))
           ((and `(,action ,layer)
                 (guard (member action '(df mo osl tg to tt))))
            (layer-switch action layer))
           ((and `(,action ,layer ,mod-or-key)
                 (guard (member action '(lm lt))))
            (layer-switch-lm-or-lt action layer mod-or-key))))
       keys))
  
  (defun define-layer (name pos keys)
    (cl-pushnew
     (make-layer :name (upcase name)
                 :pos pos
                 :keys (transform-keys keys))
     layers
     :test (lambda (old new)
             (string-equal (layer-name old)
                           (layer-name new)))))

  (defun all-layers ()
    (cl-sort (copy-sequence layers)
             #'< :key #'layer-pos)))

(defun generate-layer-codes-enum ()
  (let ((layers (mapcar #'layer-name (all-layers))))
    (insert "enum layer_codes {\n")
    (insert (format "\t%s = 0,\n" (car layers)))
    (setf layers (cdr layers))
    (cl-dolist (layer (butlast layers))
      (insert (format "\t%s,\n" layer)))
    (insert (format "\t%s\n" (car (last layers))))
    (insert "};\n\n")))

(defconst ergodox-layout-template
  "[$0] = LAYOUT_ergodox(
    $1,  $2,  $3,  $4,  $5,  $6,  $7,
    $8,  $9,  $10, $11, $12, $13, $14,
    $15, $16, $17, $18, $19, $20,
    $21, $22, $23, $24, $25, $26, $27,
    $28, $29, $30, $31, $32,
                             $33, $34,
                                  $35,
                        $36, $37, $38,
    // ----------------------------------------------
    $39, $40, $41, $42, $43, $44, $45,
    $46, $47, $48, $49, $50, $51, $52,
    $53, $54, $55, $56, $57, $58,
    $59, $60, $61, $62, $63, $64, $65,
    $66, $67, $68, $69, $70,
    $71, $72,
    $73,
    $74, $75, $76)")

(defun generate-keymaps-matrix ()
  (let ((layers (all-layers)))
    (insert "const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {\n\n")
    (insert (cl-reduce (lambda (item1 item2)
                         (concat item1 ", \n\n" item2))
                       (mapcar (lambda (layer)
                            (s-format ergodox-layout-template
                                      'elt
                                      (cons (layer-name layer)
                                            (layer-keys layer))))
                          layers))))
  (insert "\n};"))

(define-layer "base" 0
 '((---)        (---)    (---)         (---)         (---)     (---) (---)
   (---)        (---)     (w)           (e)           (r)       (t)  (---)
   (---)         (a)  (mod-tap G t) (mod-tap M d) (mod-tap C f) (g)
   (osm S)       (z)      (x)           (c)           (v)       (b)  (---)
   (tg emacs_l) (---)    (---)         (---)         (---)
   
                                                               (---) (---)
                                                                     (M-x)
                                   (lt emacs_r DEL) (lt xwindow SPC) (TAB)
   ;; ------------------------------------------------------------------   
   (---) (---)   (---)         (---)          (---)      (---)  (---)
   (---)  (y) (lt num_up u) (lt numeric i)     (o)       (---)  (---)
          (h) (mod-tap C j) (lt symbols k) (mod-tap M l)  (p)  (tg mdia)
   (---)  (n)     (m)         (comma)         (dot)       (q)  (osm S)
                 (---)         (---)          (---)      (---)  (---)

   (---) (---)
   (C-z)
   (lt mdia ESC) (lt emacs_l ENT) (---)
   ))

(define-layer "xwindow" 1
  '(( ) ( ) ( ) ( ) ( ) ( ) ( )
    ( ) ( ) ( ) ( ) ( ) ( ) ( )
    ( ) ( ) ( ) ( ) ( ) ( )
    ( ) ( ) ( ) ( ) ( ) ( ) ( )
    ( ) ( ) ( ) ( ) ( )
                        ( ) ( )
                            ( )
                    ( ) ( ) ( )
 ;; ---------------------------------
    ( ) ( ) ( )   ( )  ( )   ( )  ( )
    ( ) ( ) ( )  (G-b) ( )   ( )  ( )
        ( ) (F4) (F3)  (G-t) (F5) ( )
    ( ) ( ) ( )  ( )   ( )   ( )  ( )
            ( )  ( )   ( )   ( )  ( )
    ( ) ( )
    ( )
    ( ) ( ) ( )
    ))


(define-layer "numeric" 4
  '(( ) ( ) ( ) ( ) ( ) ( ) ( )
    ( ) ( ) (1) (2) (3) ( ) ( )
    ( ) (0) (4) (5) (6) ( )
    ( ) (0) (7) (8) (9) ( ) ( )
    ( ) ( ) ( ) ( ) ( )
                        ( ) ( )
                            ( )
                    ( ) ( ) ( )
 ;; ---------------------------
    ( ) ( ) ( ) ( ) ( ) ( ) ( )
    ( ) ( ) ( ) ( ) ( ) ( ) ( )
        ( ) ( ) ( ) ( ) ( ) ( )
    ( ) ( ) ( ) ( ) ( ) ( ) ( )
            ( ) ( ) ( ) ( ) ( )
    ( ) ( )
    ( )
    ( ) ( ) ( )
    ))


(define-layer "symbols" 6
  '(( ) ( ) ("[") ("]") ({) (}) ( )
    ( ) ( ) ( ) ( ) ( ) ( ) ( )
    ( ) ( ) ( ) ( ) ( ) ( )
    ( ) ( ) ( ) ( ) ( ) ( ) ( )
    ( ) ( ) ( ) ( ) ( )
                        ( ) ( )
                            ( )
                    ( ) ( ) ( )
 ;; ---------------------------
    ( ) ( ) ( ) ( ) ( ) ( ) ( )
    ( ) ( ) ( ) ( ) ( ) ( ) ( )
        ( ) ( ) ( ) ( ) ( ) ( )
    ( ) ( ) ( ) ( ) ( ) ( ) ( )
            ( ) ( ) ( ) ( ) ( )
    ( ) ( )
    ( )
    ( ) ( ) ( )
    ))

(cl-defstruct keycode
  key macro)

(let (keycodes)
  (defun define-macro (key macro)
    (cl-pushnew
     (make-keycode :key key
                   :macro macro)
     keycodes
     :test #'equal)))

(define-macro 'em_split (C-x 3))

(defconst keymap-filename "./elisp-keymap.c")

(with-temp-file keymap-filename
  (generate-layer-codes-enum)
  (generate-keymaps-matrix))


;; (define-layer "template"
;;   '(( ) ( ) ( ) ( ) ( ) ( ) ( )
;;     ( ) ( ) ( ) ( ) ( ) ( ) ( )
;;     ( ) ( ) ( ) ( ) ( ) ( )
;;     ( ) ( ) ( ) ( ) ( ) ( ) ( )
;;     ( ) ( ) ( ) ( ) ( )
;;                         ( ) ( )
;;                             ( )
;;                     ( ) ( ) ( )
;;  ;; ---------------------------
;;     ( ) ( ) ( ) ( ) ( ) ( ) ( )
;;     ( ) ( ) ( ) ( ) ( ) ( ) ( )
;;         ( ) ( ) ( ) ( ) ( ) ( )
;;     ( ) ( ) ( ) ( ) ( ) ( ) ( )
;;             ( ) ( ) ( ) ( ) ( )
;;     ( ) ( )
;;     ( )
;;     ( ) ( ) ( )
;;     ))

