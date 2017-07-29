#lang racket/base

(require drracket/check-syntax)
(require syntax/modread)

(require racket/class)
(require (only-in racket/list
                  group-by))
(require (only-in racket/string
                  string-join))

(define (get-data stx)
  (syntax->datum stx)
  (string-append
    (number->string (syntax-line stx))
    "+"
    (number->string (syntax-column stx))))

(define arrows-collector%
  (class (annotations-mixin object%)
    (super-new)
    (define/override (syncheck:find-source-object stx)
                     stx)
    (define/override (syncheck:add-arrow/name-dup/pxpy
                       start-source-obj start-left start-right start-px start-py
                       end-source-obj end-left end-right end-px end-py
                       actual? phase-level require-arrow? name-dup?)
                     (set! arrows
                       (cons (list (get-data start-source-obj)
                                   (get-data end-source-obj))
                             arrows)))
    (define arrows '())
    (define/public (get-collected-arrows) arrows)))

(define (arrows form)
  (define base-namespace (make-base-namespace))
  (define-values (add-syntax done)
    (make-traversal base-namespace #f))
  (define collector (new arrows-collector%))
  (parameterize ([current-annotations collector]
                 [current-namespace base-namespace])
    (add-syntax (expand form))
    (done))
  (send collector get-collected-arrows))

;; Return a syntax object (or #f) for the contents of `file`.
(define (file->syntax file #:expand? expand?)
  (define-values (base _ __) (split-path file))
  (parameterize ([current-load-relative-directory base]
                 [current-namespace (make-base-namespace)])
    (define stx
      (with-handlers ([exn:fail? (lambda () #f)])
                     (with-module-reading-parameterization
                       (lambda ()
                         (with-input-from-file file read-syntax/count-lines)))))
    (if expand?
      (expand stx) ;; do this while current-load-relative-directory is set
      stx)))

(define (read-syntax/count-lines)
  (port-count-lines! (current-input-port))
  (read-syntax))

(define (get-arrows filename)
  (arrows (file->syntax filename #:expand? #t)))

(define (generate-bindings arr)
  (map
    (lambda (ll) `(,(caar ll) ,@(map cadr ll)))
    (group-by (lambda (x) (car x)) arr)))

(define (format-output llst)
  (string-append
    "("
    (string-join
      (map (lambda (l) (string-append "("
                                      (string-join l)
                                      ")")) llst))
    ")"))

(let* ([opts (current-command-line-arguments)]
       [filename (vector-ref opts 0)])
  (format-output (generate-bindings (get-arrows filename))))
