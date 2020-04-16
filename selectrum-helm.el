;;; selectrum-helm.el --- Use Selectrum for Helm -*- lexical-binding: t -*-

;; Copyright (C) 2020 Radon Rosborough

;; Author: Radon Rosborough <radon.neon@gmail.com>
;; Created: 15 Apr 2020
;; Homepage: https://github.com/raxod502/selectrum
;; Keywords: extensions
;; Package-Requires: ((emacs "25.1") (helm "3.6.1") (selectrum "1.0"))
;; SPDX-License-Identifier: MIT
;; Version: 1.0

;;; Commentary:

;; This file provides a minor mode that causes all Helm commands to
;; redirect to use Selectrum instead, at some loss of functionality.

;;; Code:

;; To see the outline of this file, run M-x outline-minor-mode and
;; then press C-c @ C-t. To also show the top-level functions and
;; variable declarations in each section, run M-x occur with the
;; following query: ^;;;;* \|^(

(require 'let-alist)
(require 'map)
(require 'subr-x)

(cl-defun selectrum-helm--normalize-source (source)
  "Normalize single Helm SOURCE alist."
  (let-alist source
    (let ((cands (cond
                  ((functionp .candidates)
                   (funcall .candidates))
                  ((symbolp .candidates)
                   (symbol-value .candidates))
                  (t
                   .candidates))))
      (dolist (func (if (listp .candidate-transformer)
                        .candidate-transformer
                      (list .candidate-transformer)))
        (setq cands (funcall func cands)))
      (setq cands (mapcar (lambda (cand)
                            (when (consp cand)
                              (setq cand
                                    (propertize
                                     (car cand)
                                     'selectrum-helm-return
                                     (cdr cand))))
                            (setq cand
                                  (propertize
                                   cand
                                   'selectrum-helm-action
                                   .action))
                            cand)
                          cands))
      cands)))

(cl-defun selectrum-helm--normalize-sources (sources)
  "Given SOURCES as passed to `helm', return flat list of candidate strings."
  (cond
   ((symbolp sources)
    (setq sources (symbol-value sources)))
   ((symbolp (car-safe (car-safe sources)))
    (setq sources (list sources))))
  (apply #'append (mapcar #'selectrum-helm--normalize-source sources)))

(defun selectrum-helm--adapter (&rest plist)
  "Receive arguments to `helm' and invoke `selectrum-read' instead.
For PLIST, see `helm'. This is an `:override' advice for `helm'."
  (let* ((result (selectrum-read
                  (or (plist-get plist :prompt) helm--prompt)
                  (selectrum-helm--normalize-sources (plist-get plist :sources))
                  :default-candidate (plist-get plist :preselect)
                  :initial-input (plist-get plist :input)
                  :history (plist-get plist :history)))
         (cand (or (get-text-property 0 'selectrum-helm-return result) result)))
    (when-let ((action (get-text-property 0 'selectrum-helm-action result)))
      (if (functionp action)
          (funcall action cand)
        (when (symbolp action)
          (setq action (symbol-value action)))
        (funcall (cdr (car action)) cand)))))

(define-minor-mode selectrum-helm-mode
  "Minor mode to use Selectrum to implement Helm commands."
  :global t
  (if selectrum-helm-mode
      (advice-add #'helm :override #'selectrum-helm--adapter)
    (advice-remove #'helm #'selectrum-helm--adapter)))

;;;; Closing remarks

(provide 'selectrum-helm)

;; Local Variables:
;; checkdoc-verb-check-experimental-flag: nil
;; indent-tabs-mode: nil
;; outline-regexp: ";;;;* "
;; sentence-end-double-space: nil
;; End:

;;; selectrum-helm.el ends here
