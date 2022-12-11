
;;; Commentary:
;;; Code:

(require 'comint)

(defvar inf-cling-prompt-regexp (rx line-start (literal "[cling]$ ")))

(defun inf-cling-comint-start (&optional flags)
  "Move to the buffer containing Cling, or create one if it does not exist.
FLAGS defaults to C++11."
  (interactive)
  (or flags (setq flags "-std=c++11"))
  (make-comint-in-buffer "inferior-cling" "*inferior-cling*"
						 "cling" nil
						 flags)
  (switch-to-buffer "*inferior-cling*")
  (inf-cling-mode))

(defalias 'run-cling 'inf-cling-comint-start)

(defun inf-cling-send-string (string &optional process)
  "Send a STRING terminated with a newline to the inferior-cling PROCESS.
Has the effect of executing a command"
  (let ((process (or process (get-process "inferior-cling"))))
    (comint-send-string process string)
    (comint-send-string process "\n")))

(defun inf-cling-send-last-sexp ()
  "Send the previous sexp to the inferior-cling process."
  (interactive)
  (inf-cling-send-region (save-excursion (backward-sexp) (point)) (point)))

(defun inf-cling-send-region (start end)
  "Sends the region in the current buffer between START and END.
Sends the currently selected region when called interactively."
  (interactive "r")
  (inf-cling-send-string (buffer-substring start end)))

(defun inf-cling-send-buffer ()
  "Sends the current buffer to the inferior-cling buffer."
  (interactive)
  (inf-cling-send-region (point-min) (point-max)))

(defun cling-wrap-raw (string)
  "Wraps STRING in \".rawInput\", which tells Cling to accept function definitions"
  (format ".rawInput\n%s\n.rawInput" string))

(defun cling-wrap-region-and-send (start end)
  "Sends the region between START and END to cling in raw input mode."
  (interactive "r")
  (inf-cling-send-string
   (cling-wrap-raw (buffer-substring start end))))

(defun inf-cling--flatten-function-def ()
  "Flattens a function definition into a single line.
This make it easier to send to the inferior-cling buffer."
  (interactive)
  (replace-regexp "\n" "" nil (mark) (point)))

(defun inf-cling--mark-defun ()
  "Selects the defun containing the point.
Currently only works when point is on the line where the
function's name is declared."
  (interactive)
  (move-beginning-of-line nil)
  (push-mark (point))
  (re-search-forward "{")
  (save-excursion
	(inf-cling--flatten-function-def))
  (backward-char)
  (forward-sexp))

(defun cling-wrap-defun-and-send ()
  "Sends the current defun to cling in raw input mode.
 Currently only works when point is on the first line of function
definition."
  (interactive)
  (save-excursion
	(mark-defun) 						; (inf-cling--mark-defun)
    (cling-wrap-region-and-send (mark) (point))
    ;; (undo)
    ;; (undo)
	));;;this is a rather leaky way of doing temporary changes. there should be some way to save buffer contents or something
;;;probably uses with-temp-buffer

(defun inf-cling-output-filter-echoed-input (&optional arg)
  "Ignore ARG."
  (let ((inhibit-read-only t))
	(save-excursion
	  (goto-char comint-last-input-end)
	  (let ((input (ring-ref comint-input-ring
							 (ring-length comint-input-ring))))
		(when (re-search-forward
			   ;; craft to match just the echoed input for some reason
			   ;; this function is called multiple times
			   (format "^[%s]+\n" input)
			   (point-max) :noerror)
		  ;; (let ((overlay (make-overlay
		  ;; 				  (match-beginning 0)
		  ;; 				  (match-end 0))))
		  ;; 	(overlay-put overlay 'face 'secondary-selection)
		  ;; 	(run-with-timer 0.2 nil 'delete-overlay overlay))
		  ;; (delete-region (match-beginning 0)
		  ;; 			   (match-end 0))
		  (replace-match ""))))
	;; copied from `comint-send-input', is this needed?
    (when comint-prompt-read-only
      (save-excursion
        (goto-char comint-last-input-end)
        (comint-update-fence)))))

(defun inf-cling-init () nil)

(defvar inf-cling-mode-map
  (let ((map (make-sparse-keymap)))
	(set-keymap-parent map comint-mode-map)
	;; (define-key map [return] 'comint-send-input)
    ;; (define-key map (kbd "C-c r") 'inf-cling-send-region)
    ;; (define-key map (kbd "C-c d") 'cling-wrap-defun-and-send)
    map))

(define-derived-mode inf-cling-mode comint-mode "Cling"
  "Major mode for `inf-cling'.
\\<inf-cling-mode-map>"
  nil "Cling"
  (setq-local comint-prompt-regexp inf-cling-prompt-regexp)
  (setq-local comint-prompt-read-only t)
  ;; (setq-local font-lock-defaults '(julia-font-lock-keywords t))
  (setq-local paragraph-start inf-cling-prompt-regexp)
  (add-hook 'comint-output-filter-functions
			'inf-cling-output-filter-echoed-input 100
			:local)
  (add-hook 'inf-cling-mode-hook 'inf-cling-init))

(defvar inferior-cling-minor-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-r") 'inf-cling-send-region)
    (define-key map (kbd "C-c C-b") 'inf-cling-send-buffer)
    (define-key map (kbd "C-c C-e") 'inf-cling-send-last-sexp)
    ;; (define-key map (kbd "C-c d") 'cling-wrap-defun-and-send)
    map))

(define-minor-mode inferior-cling-minor-mode
  "Toggle `inferior-cling-mode'.
Interactively w/o arguments, this command toggles the mode.  A
positive prefix argument enables it, and any other prefix
argument disables it.  When `inferior-cling-mode' is enabled, we
rebind keys to facilitate working with cling."
  :keymap inferior-cling-minor-mode-map)

(provide 'inf-cling)
;;; inf-cling.el ends here
