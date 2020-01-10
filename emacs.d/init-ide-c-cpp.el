;;; Code:

(require 'req-package)

;; I have both irony and rtags, although they are alternatives to each other.
;; Irony consumes much less resources, however it does not have following of symbol,
;; which rtags has. Also, rtags works with headers without any problems.
;; I will keep both of them for now, so I can decide in the future which one to use for what.
;;
;; In general, I prefer irony over rtags if they work exactly the same, since irony is more lightweight.
;; both rtags and irony have good autocomplete - rtags autocomplete also works for header files
;; out of the box which is better (irony plans to support it in the future). I do have a feeling that
;; irony sometimes returns more info on autocomplete types.
;; Flychecks seem to works similarly, although some say that rtags has better reports, and I also feel
;; that might be correct.
;; Rtags has jump to definition, find references and similar stuff which irony does not have.
;;
;; Good strategy seems to be using irony for auto-complete and flycheck,
;; since irony works correct and fast for those,
;; and on the other hand using rtags for following symbols and everything else while not letting it reindex
;; each time there is a change in a file - instead having it reindex manually from time to time.

;; Makes emacs an awesome IDE for C/C++.
(req-package irony
  :ensure t
  :config
  (progn
    (unless (irony--find-server-executable) (call-interactively #'irony-install-server))

    (add-hook 'c++-mode-hook 'irony-mode)
    (add-hook 'c-mode-hook 'irony-mode)

    ;; Here irony will search for compilation database (compile_commands.json or .clang_complete)
    ;; in project structure and use it to fuel the auto-completion.
    ;; This compilation database has to be generated by us, this is not something irony can do.
    ;; It could be generated by cmake while building project, or using `bear` with the tool
    ;; that we are using to build the project, or created manually (.clang_complete).
    ;; Since compilation databases often do not contain information about header files,
    ;; it can also be a good option to have compile_commands.json for c(pp) files and .clang_complete
    ;; as fallback for headers.
    ;; NOTE: rtags knows how to work with headers without .clang_complete!
    (setq-default irony-cdb-compilation-databases '(irony-cdb-libclang
                                                    irony-cdb-clang-complete))
    (add-hook 'irony-mode-hook 'irony-cdb-autosetup-compile-options)
    ))

(req-package company-irony  ;; Provides company with auto-complete for C and C++.
  :ensure t
  :require company irony
  :config
  (progn
    (eval-after-load 'company '(add-to-list 'company-backends 'company-irony))))

(req-package flycheck-irony  ;; Flycheck checker for C and C++.
  :ensure t
  :require flycheck irony
  :config
  (progn
    (eval-after-load 'flycheck '(add-hook 'flycheck-mode-hook #'flycheck-irony-setup))))

;; Eldoc shows argument list of the function you are currently writing in the echo area.
;; irony-eldoc brings support for C and C++.
(req-package irony-eldoc
  :ensure t
  :require eldoc irony
  :config
  (progn
    (add-hook 'irony-mode-hook #'irony-eldoc)))

;; Brings google coding style to C/C++.
;; (req-package google-c-style
;;   :config
;;   (progn
;;     (add-hook 'c-mode-common-hook 'google-set-c-style)
;;     (add-hook 'c-mode-common-hook 'google-make-newline-indent)))


;; rtags indexes C / C++ projects and enables us to do stuff like auto-completion,
;; finding references / definitions and similar - it uses libclang to actually
;; "understand" the project.
;;
;; rtags is actually just an emacs client for rdm daemon, which is the main logic and
;; runs in background and re-indexes files as needed.
;; rdm and rc (general client for rdm) can be installed through emcas by running rtags-install or manually
;; (manually gives more control, and it is best to configure it as systemd socket service),
;; and we have to do that only once, when setting up emacs / rtags for the first time.
;; I like the best approach with systemd socket for now, since there I can control number of
;; processes that rtags uses. This is important because on larger projects reindexing takes a lot of
;; CPU, so it makes sense to either go with smaller number of processes or turning automatic reindexing off.
;;
;; For each new project, we have to manually register it with rdm. That is done by running
;; `rc -J <path_to_compile_commands.json>`. If you installed rtags through emacs, rc is somewhere in its internal
;; directory structure, so you have to find it to run this command. Also, make sure that rdm is running,
;; and make sure it finishes indexing.
;; rtags will make sure to automatically detect which project currently active buffer belongs to
;; and tell rdm to switch to that project.
;;
;; NOTE: I commented rtags and helm-rtags because I had not set up rtags for the project I am working on.
;;       They should be uncommented once rtags is set up.
;; (req-package rtags
;;   :config
;;   (progn
;;     (unless (rtags-executable-find "rc") (error "Binary rc is not installed!"))
;;     (unless (rtags-executable-find "rdm") (error "Binary rdm is not installed!"))

;;     (define-key c-mode-base-map (kbd "M-.") 'rtags-find-symbol-at-point)
;;     (define-key c-mode-base-map (kbd "M-,") 'rtags-find-references-at-point)
;;     (define-key c-mode-base-map (kbd "M-?") 'rtags-display-summary)
;;     (rtags-enable-standard-keybindings)

;;     (setq rtags-use-helm t)

;;     ;; Shutdown rdm when leaving emacs.
;;     (add-hook 'kill-emacs-hook 'rtags-quit-rdm)
;;     ))

;; ;; TODO: Has no coloring! How can I get coloring?
;; (req-package helm-rtags
;;   :require helm rtags
;;   :config
;;   (progn
;;     (setq rtags-display-result-backend 'helm)
;;     ))

;; ;; Use rtags for auto-completion.
;; (req-package company-rtags
;;   :require company rtags
;;   :config
;;   (progn
;;     (setq rtags-autostart-diagnostics t)
;;     (rtags-diagnostics)
;;     (setq rtags-completions-enabled t)
;;     (push 'company-rtags company-backends)
;;     ))

;; ;; Live code checking.
;; (req-package flycheck-rtags
;;   :require flycheck rtags
;;   :config
;;   (progn
;;     ;; ensure that we use only rtags checking
;;     ;; https://github.com/Andersbakken/rtags#optional-1
;;     (defun setup-flycheck-rtags ()
;;       (flycheck-select-checker 'rtags)
;;       (setq-local flycheck-highlighting-mode nil) ;; RTags creates more accurate overlays.
;;       (setq-local flycheck-check-syntax-automatically nil)
;;       (rtags-set-periodic-reparse-timeout 2.0)  ;; Run flycheck 2 seconds after being idle.
;;       )
;;     (add-hook 'c-mode-hook #'setup-flycheck-rtags)
;;     (add-hook 'c++-mode-hook #'setup-flycheck-rtags)
;;     ))

(provide 'init-ide-c-cpp)
;;; init-ide-c-cpp.el ends here