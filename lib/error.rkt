#lang racket/base

(require (for-syntax racket/base
                     racket/syntax)
         "../object.rkt"
         "../private/error.rkt"
         "../private/function.rkt"
         "../private/object.rkt"
         "../private/statement.rkt"
         "../private/this.rkt"
         (prefix-in
          ecma:
          (combine-in
           "../convert.rkt"
           "../types.rkt")))

(provide get-properties)

(define (get-properties)
  `(["Error" . ,error-constructor]
    ["EvalError" . ,eval-error-constructor]
    ["RangeError" . ,range-error-constructor]
    ["ReferenceError" . ,reference-error-constructor]
    ["SyntaxError" . ,syntax-error-constructor]
    ["TypeError" . ,type-error-constructor]
    ["URIError" . ,uri-error-constructor]))

(struct Error Object ()
  #:property prop:class 'Error)

(define (make-error-prototype+constructor name super-prototype)
  (letrec
      ([prototype
        (Error super-prototype (make-hash) #t)]
       [constructor
        (letrec
            ([call
              (λ args
                (apply construct args))]
             [construct
              (λ ([message 'undefined])
                (Error
                 prototype
                 (make-hash
                  (if (eq? 'undefined message)
                      '()
                      `(("message" . ,(make-data-property
                                       (ecma:to-string message))))))
                 #t))])
          (make-native-constructor call construct))])
    (define-object-properties prototype
      ["constructor" constructor]
      ["name" name]
      ["message" ""])
    (define-object-properties constructor
      ["prototype" prototype])
    (values prototype constructor)))

(define-values (error:prototype error-constructor)
  (make-error-prototype+constructor "Error" Object:prototype))

(define-syntax (define-native-error stx)
  (syntax-case stx ()
    [(_ base-str)
     (let ([base-name (string->symbol
                       (string-append
                        (string-downcase
                         (syntax-e #'base-str))
                        "-error"))])
       (with-syntax
         ([proto-id (format-id stx "~a:prototype" base-name)]
          [cons-id (format-id stx "~a-constructor" base-name)]
          [throw-id (format-id stx "throw-~a" base-name)])
         #'(define-values (proto-id cons-id throw-id)
             (let-values
                 ([(proto cons)
                   (make-error-prototype+constructor
                    (string-append base-str "Error")
                    error:prototype)])
               (values proto
                       cons
                       (λ (msg)
                         (throw
                          ((constructor-new-proc cons-id) msg))))))))]))

(define-native-error "Eval")
(define-native-error "Range")
(define-native-error "Reference")
(define-native-error "Syntax")
(define-native-error "Type")
(define-native-error "URI")

(define-object-properties error:prototype
  ["toString"
   (make-native-function
    (λ ()
      (unless (Object? this)
        (raise-native-error 'type "this: not an object"))
      (define name
        (let ([name (get-property-value this "name")])
          (if (ecma:undefined? name)
              "Error"
              (ecma:to-string name))))
      (define msg
        (let ([msg (get-property-value this "message")])
          (if (ecma:undefined? msg)
              ""
              (ecma:to-string msg))))
      (cond
        [(string=? "" name) msg]
        [(string=? "" msg) name]
        [else (string-append name ": " msg)])))])

(native-error-handler
 (λ (type message)
   (case type
     [(range) (throw-range-error message)]
     [(reference) (throw-reference-error message)]
     [(syntax) (throw-syntax-error message)]
     [(type) (throw-type-error message)]
     [(uri) (throw-uri-error message)]
     [else
      (error 'native-error-handler
             "unknown error type: ~a"
             type)])))
