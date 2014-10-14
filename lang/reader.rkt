#lang s-exp syntax/module-reader
ecmascript
#:read es-read
#:read-syntax es-read-syntax
#:whole-body-readers? #t

(require "../parse.rkt"
         "../private/compile.rkt")

(define (es-read in)
  (syntax->datum
   (es-read-syntax #f in)))

(define (es-read-syntax src in)
  (define stx
    (read-program src in))
  (define compiled
    (ecmascript->racket stx))
  compiled)
