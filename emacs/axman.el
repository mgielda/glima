;;; axman.el --- Automatic decrypter for attachments in emails.

;; Description: Automatic decrypter for attachments in emails.
;; Author:  Yoshinari Nomura <nom@quickhack.net>
;; Created: 2016-08-24
;; Version: 0.1.0
;; Keywords: Mail Decrypter Zip
;; URL: https://github.com/yoshinari-nomura/axman
;; Package-Requires:

;;;
;;; Commentary:
;;;

;; Minimum setup:
;;  1) setup axzip ruby script in glima.
;;     https://github.com/yoshinari-nomura/glima
;;
;;  2) add belows in your .emacs:
;;     (setq load-path
;;           (cons "~/path/to/this/file load-path"))
;;     (autoload 'axman-mew-decrypt-current-message-gmail "axman")
;;     (autoload 'axman-mew-decrypt-current-message-local "axman")
;;
;; How to use:
;;  1) In mew-summary buffer (ie. %inbox),
;;     point at an email with encrypted-ZIP attachment.
;;
;;  2) M-x axman-mew-decrypt-current-message-local
;;
;;  3) It will find the password from the current folder (%inbox)
;;     inspecting in passwordish-emails.
;;
;; axman-mew-decrypt-current-message-gmail is another version that works
;; with Gmail server.  It would be useful if your email server is
;; Gmail with IMAP enabled.
;;

;;; Code:

(defcustom axman-attachment-store-directory "~/Downloads"
  "Where to store unlocked zip file."
  :group 'axman
  :type 'directory)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper function works with Mew.

(defvar mew-regex-sumsyn-long)
(defvar mew-regex-sumsyn-short)

(declare-function mew-header-get-value "mew")
(declare-function mew-sumsyn-match "mew")
(declare-function mew-sumsyn-folder-name "mew")
(declare-function mew-sumsyn-message-number "mew")
(declare-function mew-msg-get-filename "mew")
(declare-function mew-expand-msg "mew")
(declare-function mew-expand-folder "mew")
(declare-function mew-summary-goto-message "mew")
(declare-function mew-summary-set-message-buffer "mew")

(defmacro mewx-with-current-message-buffer (&rest body)
  "Eval BODY after switch from summary to message."
  `(save-excursion
     (mew-summary-goto-message)
     (mew-sumsyn-match mew-regex-sumsyn-short)
     (mew-summary-set-message-buffer
      (mew-sumsyn-folder-name)
      (mew-sumsyn-message-number))
     ,@body))

(defun mewx-current-info (property)
  "Get PROPERTY of pointed messsage."
  (when (mew-sumsyn-match mew-regex-sumsyn-long)
    (let* ((folder (mew-sumsyn-folder-name))
           (number (mew-sumsyn-message-number))
           (path (mew-msg-get-filename (mew-expand-msg folder number)))
           (directory (mew-expand-folder folder)))
      (cdr (assoc
            property
            `((folder    . ,folder)
              (number    . ,number)
              (path      . ,path)
              (directory . ,directory)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Decrypt attachments

(defmacro axman-with-decrypter-buffer (buffer message &rest body)
  "Wrap decrypter in BUFFER with MESSAGE.
BODY should returns process object of ``start-process''."
  `(let ((,buffer (get-buffer-create " *Axman*")))
     (save-selected-window
       (pop-to-buffer ,buffer)
       (delete-region (point-min) (point-max))
       (insert "Decrypting " (or ,message "") "...\n")
       (recenter -1))
     (set-process-sentinel
      ,@body
      (lambda (proc event)
        (let ((,buffer (process-buffer proc)))
          (with-current-buffer ,buffer
            (if (save-excursion
                  (re-search-backward "^Wrote to \\(.*\\)\\." nil t))
                (start-process "open" ,buffer "open" "-R" (match-string 1)))))))))

(put 'axman-with-decrypter-buffer 'lisp-indent-function 2)

(defun axman-start-gmail-decrypter (target-mail extract-directory)
  "Invoke Gmail decrypter process.  Return process object.
It decrypts zip-attachments in TARGET-MAIL and stores the decrypted zip-files
into EXTRACT-DIRECTORY.  TARGET-MAIL should be in the form of Gmail message-id
like: 15c5723f8d3dba57."
  (axman-with-decrypter-buffer process-buffer target-mail
    (start-process "glima" process-buffer
                   "glima" "dezip" target-mail extract-directory)))

(defun axman-start-mh-decrypter (target-mail password-source extract-directory)
  "Invoke MH decrypter process.  Return process object.
It decrypts zip-attachments in TARGET-MAIL using PASSWORD-SOURCE,
and stores the decrypted zip-files into EXTRACT-DIRECTORY.
TARGET-MAIL a filename of MHC-style mail.
MH decrypter takes PASSWORD-SOURCE as a MH-style folder directory
from where piking password mails."
  (axman-with-decrypter-buffer process-buffer target-mail
    (start-process "axezip" process-buffer
                   "axezip" target-mail password-source extract-directory)))

;;;###autoload
(defun axman-mew-decrypt-current-message-gmail ()
  "Decrypt attachment from Gmail."
  (interactive)
   (let ((message-id
          (mewx-with-current-message-buffer
           (mew-header-get-value "X-GM-MSGID:"))))
     (if message-id
         (axman-start-gmail-decrypter
          message-id
          axman-attachment-store-directory)
       (message "No message found."))))

;;;###autoload
(defun axman-mew-decrypt-current-message-local ()
  "Decrypt current zip attachments."
  (interactive)
  (let ((path (mewx-current-info 'path))
        (password-source (mewx-current-info 'directory)))
    (if path
        (axman-start-mh-decrypter
         path password-source
         axman-attachment-store-directory)
      (message "No message found."))))

(provide 'axman)

;;; axman.el ends here
