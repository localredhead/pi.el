EMACS ?= emacs

all: test

test:
	${EMACS} -Q -batch -L . -L test -l pi.el -l test/pi-test.el -f ert-run-tests-batch-and-exit

lint:
	${EMACS} -Q -batch --eval "(progn \
	(require 'package) \
	(push '(\"melpa\" . \"https://melpa.org/packages/\") package-archives) \
	(package-initialize) \
	(unless (package-installed-p 'package-lint) \
	  (package-refresh-contents) \
	  (package-install 'package-lint)) \
	(require 'package-lint) \
	(setq byte-compile-error-on-warn t) \
	(find-file \"pi.el\") \
	(package-lint-current-buffer) \
	(kill-emacs (if (boundp 'package-lint-errors) (length package-lint-errors) 0)))"

melpazoid:
	chmod +x ./melpazoid-check.sh
	./melpazoid-check.sh

compile:
	${EMACS} -Q -batch -f batch-byte-compile pi.el

clean-elc:
	rm -f *.elc

check: test lint melpazoid

.PHONY: all test lint melpazoid compile clean-elc check
