;; Copyright (c) 2020 Michael Neidel

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.


;;; Various pseudo-random number generators.
(module prng
    (prng::middle-square
     prng::middle-square-weyl-seq
     prng::blum-blum-shub
     prng::pcg
     prng::xorshift64
     prng::el-cheapo-zx
     prng::sid-noise)

  (import scheme (chicken base) (chicken bitwise) (chicken random)
	  srfi-1 srfi-13 (only mdal scale-values))

  ;;; > Anyone who considers arithmetical methods of producing random digits is,
  ;;; > of course, in a state of sin.
  ;;;
  ;;; *J. v. Neumann*

  ;;; Alias for `arithmetic-shift`
  (define << arithmetic-shift)

  (define (rand bits)
    (pseudo-random-integer (sub1 (expt 2 bits))))

  ;;; Addition of arbitrary-sized integers.
  (define (uint-arithmetic operator integer-bits operands)
    (bitwise-and (apply operator operands)
		 (sub1 (expt 2 integer-bits))))

  (define (add-uint integer-bits operands)
    (uint-arithmetic + integer-bits operands))

  (define (mul-uint integer-bits operands)
    (uint-arithmetic * integer-bits operands))

  ;;; 8-bit unsigned addition
  (define (add/8 . operands)
    (add-uint 8 operands))

  ;;; 16-bit unsigned addition
  (define (add/16 . operands)
    (add-uint 16 operands))

  ;;; 32-bit unsigned addition
  (define (add/32 . operands)
    (add-uint 32 operands))

  ;;; 64-bit unsigned addition
  (define (add/64 . operands)
    (add-uint 64 operands))

  ;;; 8-bit unsigned multiply
  (define (mul/8 . operands)
    (mul-uint 8 operands))

  ;;; 16-bit unsigned multiply
  (define (mul/16 . operands)
    (mul-uint 16 operands))

  ;;; 32-bit unsigned multiply
  (define (mul/32 . operands)
    (mul-uint 32 operands))

  ;;; 64-bit unsigned multiply
  (define (mul/64 . operands)
    (mul-uint 64 operands))

  ;;; 8-bit rotation
  (define (rol/8 i amount)
    (let ((j (bitwise-and i #xff)))
      (if (zero? amount)
	  j
	  (rol/8 (bitwise-ior (<< (bitwise-and j #x80)
						-7)
			      (<< j 1))
		 (sub1 amount)))))

  ;; ;;; Calculate the number of 1-bits in the integer x.
  ;; (define (population-count x)
  ;;   (arithmetic-shift (mul/64 #x1111111111111111
  ;; 			      (bitwise-and #x1111111111111111
  ;; 					   (mul/64 x #x2000400080010)))
  ;; 		      -60))

  ;;; A generator based on the Middle-Square Method, as devised by John von
  ;;; Neumann in 1946. It is statistically very poor and may break with
  ;;; unsuitable seeds. This implementation deviates from von Neumann's design
  ;;; by considering only the lower half of the 8 digits extracted from the
  ;;; 16-digit square. This is done to mitigate the effects of the convergence
  ;;; towards lower number sequences that is a common trait of the Middle Square
  ;;; method.
  (define (prng::middle-square amount bits #!optional (seed 12345678))
    (letrec ((gen-next
	      (lambda (n s)
		(if (zero? n)
		    '()
		    (let ((squared-str (string-pad (number->string (expt s 2))
						   16 #\0)))
		      (cons (string->number
			     (string-drop (string-take squared-str 12) 8))
			    (gen-next
			     (sub1 n)
			     (string->number
			      (string-append (string-take squared-str 4)
					     (string-take-right squared-str
								4))))))))))
      (map (lambda (x)
	     (floor (* (sub1 (expt 2 bits)) (/ x 10000))))
	   (gen-next amount seed))))

  ;;; A variation of von Neumann's Middle Square Method that applies a Weyl
  ;;; sequence to the Middle Square generator, developed by Bernard Widynski.
  ;;; Very good statistical quality. See https://arxiv.org/abs/1704.00358v4
  (define (prng::middle-square-weyl-seq amount bits
					#!optional (seed (rand bits))
					(magic #xb5ad4eceda1ce2a9))
    (letrec ((gen-next
	      (lambda (n x w)
		(if (zero? n)
		    '()
		    (let* ((next-w (add/64 w magic))
			   (x-squared+w (add/64 next-w (expt x 2)))
			   (next-x (bitwise-ior
				    (<< x-squared+w -32)
				    (bitwise-and #xffffffffffffffff
						 (<< x-squared+w 32)))))
		      (cons (bitwise-and next-x (sub1 (expt 2 bits)))
			    (gen-next (sub1 n) next-x next-w)))))))
      (gen-next amount seed 0)))

  ;;; Blum Blum Shub Generator.
  ;;; https://en.wikipedia.org/wiki/Blum_Blum_Shub
  (define (prng::blum-blum-shub amount bits
				#!optional (p 5651) (q 5623) (seed 31))
    (letrec* ((mod (* p q))
	      (bitmask (sub1 (expt 2 bits)))
	      (gen-next (lambda (n seed)
			  (if (zero? n)
			      '()
			      (let* ((next-seed (modulo (expt seed 2) mod)))
				(cons (bitwise-and next-seed bitmask)
				      (gen-next (sub1 n) next-seed)))))))
      (gen-next amount seed)))

  ;; TODO tends to break after ~60 values.
  ;;; Permuted Congruential Generator, https://www.pcg-random.org/
  ;;; `seed` and `increment` must be a 64-bit integer seed. `bits` must be
  ;;; between 1 and 32.
  (define (prng::pcg amount bits
		     #!optional (seed (rand 64)) (increment (rand 64)))
    (letrec*
	((inc (bitwise-ior increment 1))
	 (gen-next
	  (lambda (n state)
	    (if (zero? n)
		'()
		(let ((xor-shifted (<< (bitwise-xor state (<< state -18))
				       -27))
		      (rot (<< state -59)))
		  (cons (bitwise-and
			 (sub1 (expt 2 bits))
			 (bitwise-ior (<< xor-shifted (- rot))
				      (<< xor-shifted
					  (bitwise-ior 31 (- rot)))))
			(gen-next (sub1 n)
				  (add/64 (mul/64 state 6364136223846793005)
					  state))))))))
      (cdr (gen-next (+ 1 amount) seed))))

  ;;; Classic Non-scrambled 64-bit Xorshift generator, as developed by George
  ;;; Marsaglia. See https://en.wikipedia.org/wiki/Xorshift
  (define (prng::xorshift64 amount bits #!optional (state (rand 64)))
    (if (zero? amount)
	'()
	(let* ((x1 (bitwise-xor state
				(bitwise-and #xffffffffffffffff
					     (arithmetic-shift state 13))))
	       (x2 (bitwise-xor x1 (arithmetic-shift x1 -17)))
	       (next-state (bitwise-xor x2
					(bitwise-and #xffffffffffffffff
						     (arithmetic-shift x2 5)))))
	  (cons (bitwise-and next-state (sub1 (expt 2 bits)))
		(prng::xorshift64 (sub1 amount) bits next-state)))))

  ;;; Very fast but extremely poor 8-bit PRNG used to generate noise in various
  ;;; ZX Spectrum beeper engines.
  (define (prng::el-cheapo-zx amount bits #!optional (state 0) (seed #x2175))
    (letrec ((make-values
	      (lambda (amount state)
		(if (zero? amount)
		    '()
		    (let* ((next-accu (add/16 state seed))
			   (next-state (add/16 (<< (rol/8 (<< next-accu -8) 1)
						   8)
					       (bitwise-and next-accu #xff))))
		      (cons (quotient next-state #x100)
			    (make-values (sub1 amount) next-state)))))))
      (scale-values (make-values amount state) 0 (sub1 (expt 2 bits)))))

  ;;; The PRNG used to generate the noise waveform on the MOS 6581/8580 Sound
  ;;; Interface Device, which is a Fibonacci LSFR using a feedback polynomial
  ;;; x^22 + x^17 + 1. See http://www.sidmusic.org/sid/sidtech5.html. For added
  ;;; authenticity, initialize SEED to #x7ffff8.
  (define (prng::sid-noise amount bits #!optional (seed (rand 23)))
    (letrec ((make-values
	      (lambda (amount lsfr)
		(if (zero? amount)
		    '()
		    (let ((next-lsfr
			   (bitwise-and
			    #x7fffff
			    (bitwise-ior
			     (arithmetic-shift lsfr -1)
			     (arithmetic-shift
			      (bitwise-xor (arithmetic-shift lsfr -1)
					   (arithmetic-shift lsfr -6))
			      22)))))
		      (cons next-lsfr
			    (make-values (sub1 amount) next-lsfr)))))))
      (scale-values (make-values amount
				 (bitwise-and #x7fffff (bitwise-ior seed 1)))
		    0
		    (sub1 (expt 2 bits)))))

  ) ;; end module prng