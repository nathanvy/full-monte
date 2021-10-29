;;;; References:
;;; M. Broadie and  ̈O. Kaya. Exact simulation of stochastic volatility and other affine jump diffusion processes. Operations Research, 54:217–231, 2006.
;;; S. Heston. A closed-form solution for options with stochastic volatility with applications to bond and currency options. Review of Financial Studies, 6:327–343, 1993.
;;;  Grzelak, Lech Aleksander and Witteveen, Jeroen and Suarez-Taboada, Maria and Oosterlee, Cornelis W., The Stochastic Collocation Monte Carlo Sampler: Highly Efficient Sampling from 'Expensive' Distributions, 2015

(ql:quickload "cl-ana.statistics")
(ql:quickload "special-functions")

;;this fn assumes that input-list is a proper list in the form of
;; (("timestamp" "float") ("timestamp" "float") ... )
;; what we really want is just the cdr of every sublist, coerced to a float
(defun massage-input-data (input-list)
  (loop for sublist in input-list
	collect (read-from-string (cadr sublist)))) ; yes I know read-from-string is a security risk.  Be careful with this input

;;annualized volatility
(defun annual-vol (price-list)
  (* (sqrt 252)
     (cl-ana.statistics:standard-deviation (loop for i from 1 below (length price-list)
						    collect (/ (- (elt price-list i) (elt price-list (- i 1)))
							       (elt price-list (- i 1)))))))

;; log returns = ln(today's price / yesterday's price)
(defun calc-returns (price-list)
  (loop for i from 1 below (length price-list)
	collect (log (/ (elt price-list i)
			(elt price-list (- i 1))))))

;; use inverse transform sampling to get normally-distributed floats on [-1.0, 1.0] from
;; the implementation's uniformly-distributed RNG:
(defun draw-random-normal ()
  (special-functions:inverse-erf (coerce (- (random 2.0) 1.0) 'double-float)))

;; Applies geometric Brownian motion to a stock price S, with drift coefficient mu and dispersion coefficient sigma.  Returns the new spot price St.
;; in other words: dSt = St [mu dt + sigma dWt] is our model, which we can reformulate as an
;; exponential thanks to Ito's lemma:  St = S0 e^( [mu - sigma^2] T /2 + sigma r sqrt(t) )
;; where r is the random walk on (0,1) whose movements are normally distributed
;; trust me it's easier with the reformulation because e^[whatever] will never drop below zero
(defun gbm-model (s0 mu sigma &optional (delta-t 1))
  (* s0 (exp (+
	      (* (- mu (* (expt sigma 2) 0.5)) delta-t)
	      (* (draw-random-normal) sigma (sqrt delta-t))))))

;; future-proofing for adding local and stochastic vol models later
;; for now you should always pass 'constant to this function
(defun select-sigma (vol)
  (cond
    ((eq vol 'constant) (annual-vol *input*))
    (T 0.1)))

;; expects data-vec to be sorted in ascending order.
;; returns the index to the left of where the value x would occur if
;; it were present in the data vector.  In the event of duplcate values
;; e.g. #(0 1 1 1 2 3 4 5 6) it returns the rightmost
(defun modified-binary-search (data-vec x predicate)
  (loop
    with l = 0
    with r = (- (length data-vec) 1)
    for m = (floor (+ l r) 2)
    for mth = (elt data-vec m)

    if (funcall predicate mth x)
      do (setf l m)
    else do (setf r m)

    until (<= (- r l) 1)
    finally (return l)))

;; empirical CDF of the data (which should correspond roughly to a log-normal distr.
(defun ecdf (data x)
  (let* ((n (length data))
	 (increment (/ 1.0 n))
	 (dv (coerce (sort (copy-seq data) #'<) 'vector))
	 (probability (modified-binary-search dv x #'<)))
    (* increment (+ probability 1))))

;;I just got this data from Google Finance, it's just daily closing prices for $X
(defparameter *input* (massage-input-data (mapcar (lambda (str)
						    (uiop:split-string str :separator ","))
						  (uiop:read-file-lines "X-daily-closes-2000Jan1-2021Oct17.csv"))))
(defparameter *log-returns* (calc-returns *input*))

;; first we'll chew the data to get estimates of the expected return and the
;; historical volatility.  In a later version we'll use stochastic volatility
;;
;; Then we'll simulate thousands of 5-day trading weeks for US Steel ($X) using the
;; real-world 25 Oct 2021 close price, and see where it closes on Friday.
;; for each "week" we'll apply GBM to Tuesday, Wednesday, Thursday, and Friday, or
;; in other words we apply the model 4 times per round.
;;
;; the list friday-returns will (should) be log-normally distributed.  We can test this
;; by calling 'cl-ana.statistics:anderson-darling-normality-test (or another test of our choice)
;; on the log returns, since the log of lognormal data will be normal.
;;
;; then we will take the friday-returns data to create an empirical CDF to let us estimate the
;; probability that a stock will close on Friday at or below a given strike price.  Fuck yeah.
(defun main ()
  (let* ((monday-close 24.6)
	 (sigma (select-sigma 'constant))
	 (strike 25.5)
	 (rounds 10000)
	 (delta-t 4)
	 (mu (- (expt (/ (car (last *input*))
			  (car *input*)) (/ 365.0 (length *input*))) 1))) 
    (format t "Simulating ~a weeks with mu = ~a, sigma = ~a... " rounds mu sigma)
    (let ((friday-returns (loop repeat rounds
				for price = monday-close
				do (setf price (gbm-model price mu sigma delta-t))
				collect price)))
      (format t "Done.~%")
      (format t "Probability of friday close being at or below ~a is approximately ~a ~%" strike (ecdf friday-returns strike)))))
