;;;; database.scm - tests for (cuirass database) module
;;;
;;; Copyright © 2016 Mathieu Lirzin <mthl@gnu.org>
;;;
;;; This file is part of Cuirass.
;;;
;;; Cuirass is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; Cuirass is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with Cuirass.  If not, see <http://www.gnu.org/licenses/>.

(use-modules (cuirass database)
             (srfi srfi-64))

(define* (make-dummy-job #:optional (name "foo"))
  `((#:name . ,name)
    (#:derivation . ,(string-append name ".drv"))))

(define %db
  ;; Global Slot for a database object.
  (make-parameter #t))

(define %id
  ;; Global Slot for a job ID in the database.
  (make-parameter #t))

(parameterize
    ((%package-database
      ;; Use an empty and temporary database for the tests.
      (string-append (getcwd) "/" (number->string (getpid)) "-tmp.db")))
  (dynamic-wind
    (const #t)
    (λ ()
      (test-assert "db-init"
        (%db (db-init)))

      (test-assert "sqlite-exec"
        (begin
          (sqlite-exec (%db) "\
INSERT INTO build (job_spec, drv) VALUES ('job1', 'drv1');")
          (sqlite-exec (%db) "\
INSERT INTO build (job_spec, drv) VALUES ('job2', 'drv2');")
          (sqlite-exec (%db) "\
INSERT INTO build (job_spec, drv) VALUES ('job3', 'drv3');")
          (sqlite-exec (%db) "SELECT * FROM build;")))

      (test-assert "db-add-evaluation"
        (%id (db-add-evaluation (%db) (make-dummy-job))))

      (test-assert "db-get-evaluation"
        (db-get-evaluation (%db) (%id)))

      (test-equal "db-add-build-log"
        "foo log"
        (let ((job (acons #:id (%id) (make-dummy-job)))
              (log-column 3))
          (db-add-build-log (%db) job "foo log")
          (vector-ref (db-get-evaluation (%db) (%id)) log-column)))

      (test-assert "db-close"
        (db-close (%db))))
    (λ ()
      (delete-file (%package-database)))))
