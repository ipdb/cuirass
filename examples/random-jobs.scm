;;; random.scm -- Definition of the random build jobs
;;; Copyright © 2018 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2018 Clément Lassieur <clement@lassieur.org>
;;;
;;; This file is part of Cuirass.
;;;
;;; Cuirass is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; Cuirass is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with Cuirass.  If not, see <http://www.gnu.org/licenses/>.


(use-modules (guix)
             (srfi srfi-1)
             (srfi srfi-26))

(define (make-job name derivation)
  (lambda ()
    `((#:job-name . ,name)
      (#:derivation . ,(derivation-file-name (force derivation)))
      (#:license . ((name . "GPLv3+")))
      (#:description "dummy job")
      (#:long-description "really dummy job"))))

(define %seed
  (logxor (cdr (gettimeofday))
          (car (gettimeofday))
          (cdr (gettimeofday))))

(define %state
  (seed->random-state %seed))

(define* (random-derivation store #:optional (suffix ""))
  (let ((nonce (random 1e6)))
    (run-with-store store
      (gexp->derivation (string-append "random" suffix)
                        #~(let ((state (seed->random-state #$%seed)))
                            (sleep (pk 'sleeping (random 10 state)))
                            (when (zero? (random 4 state))
                              (error "we're faillliiiiing!"))
                            #$nonce
                            (mkdir #$output))))))


(define (make-random-jobs store arguments)
  (let ((checkout (assq-ref arguments 'cuirass)))
    (format (current-error-port)
            "evaluating random jobs from directory ~s, commit ~s~%"
            (assq-ref checkout 'file-name)
            (assq-ref checkout 'revision)))

  (when (zero? (random 7 %state))
    (error "Evaluation is failing!"))

  (unfold (cut > <> 10)
          (lambda (i)
            (let ((suffix (number->string i)))
              (make-job (string-append "foo" suffix)
                        (delay (random-derivation store suffix)))))
          1+
          0))
