;
; Sketch, in R5RS Scheme, for a little language with Ahead-of-Time `eval`.
;

; NOTE: `eval-aot` and `eval-runtime` in the meta-language take 2 arguments, but
; for simplicity, `eval` in the object language takes only 1 argument (because
; all functions in the object language take only 1 argument)

; TODO: clear up what is represented by what
; TODO: `if`, and aggressive folding of same
; TODO: `let`, and aggressive folding of same

; --------------------------------- Environments --------------------------------- ;

; An environment is an alist that maps names to either (known <value>) or (unknown)
; (or of course a name might not be in the environment: assoc returns #f)

(define empty-env '())

(define extend-env-known (lambda (name value env)
  (cons (cons name (list 'known value)) env)))

(define extend-env-unknown (lambda (name env)
  (cons (cons name (list 'unknown)) env)))

(define std-env
  (extend-env-known '+ +
    (extend-env-known '* *
      (extend-env-known 'eval (lambda (phrase) (eval-aot phrase std-env))
        (extend-env-known 'pi 3 empty-env)))))

; --------------------------------- Evaluator --------------------------------- ;

;
; Evaluation function.
; First we reduce the phrase using constant folding,
; then we eval as usual.
;
(define eval-aot (lambda (phrase env)
  (eval-runtime (constant-fold phrase env) env)))

;
; "Inner" evaluation function that assumes the phrase has
; already been constant-folded.  Of course, this also works
; on phrases that haven't been constant-folded, too.
;
(define eval-runtime (lambda (phrase env)
  (let* ((bound-to (assoc phrase env)))
    (cond
      (bound-to
        (let* ((entry (cdr bound-to))
               (constantness (car entry)))
          (cond
            ((equal? constantness 'known)
              (cadr entry))
            (else
              (error "malformed env entry:" bound-to)))))
      ((lambda-phrase? phrase)
        (lambda-phrase-to-lambda phrase env))
      ((quote-phrase? phrase)
        (cadr phrase))
      ((literal? phrase)
        phrase)
      ((list? phrase)
        (let* ((rator (eval-runtime (car phrase) env))
               (rands (map (lambda (s) (eval-runtime s env)) (cdr phrase))))
          (apply rator rands)))
      (else
        (error "malformed phrase for eval:" phrase))))))

; helper
(define lambda-phrase-to-lambda (lambda (phrase env)
  (let* ((lambda-arg (caadr phrase))
          (lambda-body (caddr phrase)))
    (lambda (x)
      (let* ((inner-env (extend-env-known lambda-arg x env)))
        (eval-runtime lambda-body inner-env))))))

; --------------------------------- Transformer --------------------------------- ;

;
; Constant folding, somewhat aggressive.
;
(define constant-fold (lambda (phrase env)
  (let* ((bound-to (assoc phrase env)))
    (cond
      (bound-to
        (let* ((entry (cdr bound-to))
               (constantness (car entry)))
          (cond
            ((equal? constantness 'known)
              (cadr entry))
            ((equal? constantness 'unknown)
              phrase)
            (else
              (error "malformed env entry:" bound-to)))))
      ((lambda-phrase? phrase)
        (let* ((lambda-args  (cadr phrase))
               (lambda-body  (caddr phrase))
               (inner-env    (extend-env-unknown (car lambda-args) env))
               (reduced-body (constant-fold lambda-body inner-env))
               (new-phrase   (list 'lambda lambda-args reduced-body)))
          (lambda-phrase-to-lambda new-phrase env)))
      ((quote-phrase? phrase)
        (cadr phrase))
      ((literal? phrase)
        phrase)
      ((list? phrase)
        (let* ((reduced-phrase (map (lambda (s) (constant-fold s env)) phrase)))
          (cond
            ((all-constants? reduced-phrase)
              (let* ((rator (car reduced-phrase))
                     (rands (cdr reduced-phrase)))
                ;(print "---> applying " rator " to " rands)
                (let* ((result (apply rator rands)))
                  ; TODO: we may have to add `quote` here, if the result
                  ; is a literal symbol or list?
                  ;(print "<--- got " result)
                  result)))
            (else
              reduced-phrase))))
      (else
        (error "malformed phrase for constant fold:" phrase))))))

; --------------------------------- Predicates --------------------------------- ;

(define all-constants? (lambda (many)
  (cond
    ((null? many)
      #t)
    ((literal? (car many))
      (all-constants? (cdr many)))
    (else
      #f))))

(define lambda-phrase? (lambda (phrase)
  (and (list? phrase) (equal? (car phrase) 'lambda))))

(define quote-phrase? (lambda (phrase)
  (and (list? phrase) (equal? (car phrase) 'quote))))

(define literal? (lambda (phrase)
  (or (number? phrase)
      (procedure? phrase)
      ;(lambda-phrase? phrase)  FIXME: when constant folding applies a list where
      ;the first element is a lambda phrase, it needs to treat it like a real lambda.
      ;Until then, we can't really consider a literal lambda phrase to be a literal.
      (quote-phrase? phrase)
  )))

; ----------------------------------- TESTS ----------------------------------- ;

(define test-em (lambda (phrase)
  (print "unevaluated:   " phrase)
  (print "eval-runtime:  " (eval-runtime phrase std-env))
  (print "constant-fold: " (constant-fold phrase std-env))
  (print "eval-aot:      " (eval-aot phrase std-env))
  (print "")
))

(define test (lambda ()
  (test-em (quote
    (+ 2 (* pi 5))
  ))

  (test-em (quote
    ((lambda (x) (* x x)) 4)
  ))

  (test-em (quote
    (lambda (x) (* x (+ 2 pi)))
  ))

  (test-em (quote
    ((lambda (x) (* x (+ 2 pi))) 4)
  ))

  ;(test-em (quote
  ;  (quote (a (b c) d))
  ;))

  (test-em (quote
    (eval (quote (+ 3 5)))
  ))
))
