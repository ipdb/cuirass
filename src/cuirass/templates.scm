;;; templates.scm -- HTTP API
;;; Copyright © 2018 Tatiana Sholokhova <tanja201396@gmail.com>
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

(define-module (cuirass templates)
  #:use-module (ice-9 format)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:export (html-page
            specifications-table
            evaluation-info-table
            build-eval-table))

(define (html-page title body)
  "Return HTML page with given TITLE and BODY."
  `(html (@ (xmlns "http://www.w3.org/1999/xhtml")
            (xml:lang "en")
            (lang "en"))
         (head
          (meta (@ (charset "utf-8")))
          (meta (@ (name "viewport")
                   (content ,(string-join '("width=device-width"
                                            "initial-scale=1"
                                            "shrink-to-fit=no")
                                          ", "))))
          (link (@ (rel "stylesheet")
                   (href "/static/css/bootstrap.css")))
          (link (@ (rel "stylesheet")
                   (href "/static/css/open-iconic-bootstrap.css")))
          (title ,title))
         (body
          (nav (@ (class "navbar navbar-expand-lg navbar-light bg-light"))
               (a (@ (class "navbar-brand") (href "/"))
                  (img (@ (src "/static/images/logo.png")
                          (alt "logo")
                          (height "25")))))
          (main (@ (role "main") (class "container pt-4 px-1"))
                ,body
                (hr)))))

(define (specifications-table specs)
  "Return HTML for the SPECS table."
  `((p (@ (class "lead")) "Specifications")
    (table
     (@ (class "table table-sm table-hover"))
     ,@(if (null? specs)
           `((th (@ (scope "col")) "No elements here."))
           `((thead (tr (th (@ (scope "col")) Name)
                        (th (@ (scope "col")) Inputs)))
             (tbody
              ,@(map
                 (lambda (spec)
                   `(tr (td (a (@ (href "/jobset/" ,(assq-ref spec #:name)))
                               ,(assq-ref spec #:name)))
                        (td ,(string-join
                              (map (lambda (input)
                                     (format #f "~a (on ~a)"
                                             (assq-ref input #:name)
                                             (assq-ref input #:branch)))
                                   (assq-ref spec #:inputs)) ", "))))
                 specs)))))))

(define (pagination first-link prev-link next-link last-link)
  "Return html page navigation buttons with LINKS."
  `(div (@ (class row))
        (nav
         (@ (class "mx-auto") (aria-label "Page navigation"))
         (ul (@ (class "pagination"))
             (li (@ (class "page-item"))
                 (a (@ (class "page-link")
                       (href ,first-link))
                    "<< First"))
             (li (@ (class "page-item"
                      ,(if (string-null? prev-link) " disabled")))
                 (a (@ (class "page-link")
                       (href ,prev-link))
                    "< Previous"))
             (li (@ (class "page-item"
                      ,(if (string-null? next-link) " disabled")))
                 (a (@ (class "page-link")
                       (href ,next-link))
                    "Next >"))
             (li (@ (class "page-item"))
                 (a (@ (class "page-link")
                       (href ,last-link))
                    "Last >>"))))))

(define (evaluation-info-table name evaluations id-min id-max)
  "Return HTML for the EVALUATION table NAME. ID-MIN and ID-MAX are
  global minimal and maximal id."
  `((p (@ (class "lead")) "Evaluations of " ,name)
    (table
     (@ (class "table table-sm table-hover table-striped"))
     ,@(if (null? evaluations)
           `((th (@ (scope "col")) "No elements here."))
           `((thead
              (tr
               (th (@ (scope "col")) "#")
               (th (@ (scope "col")) Commits)
               (th (@ (scope "col")) Success)))
             (tbody
              ,@(map
                 (lambda (row)
                   `(tr (th (@ (scope "row"))
                            (a (@ (href "/eval/" ,(assq-ref row #:id)))
                               ,(assq-ref row #:id)))
                        (td ,(string-join
                              (map (cut substring <> 0 7)
                                   (string-tokenize (assq-ref row #:commits)))
                              ", "))
                        (td (a (@ (href "#") (class "badge badge-success"))
                               ,(assq-ref row #:succeeded))
                            (a (@ (href "#") (class "badge badge-danger"))
                               ,(assq-ref row #:failed))
                            (a (@ (href "#") (class "badge badge-secondary"))
                               ,(assq-ref row #:scheduled)))))
                 evaluations)))))
    ,(if (null? evaluations)
         (pagination "" "" "" "")
         (let* ((eval-ids (map (cut assq-ref <> #:id) evaluations))
                (page-id-min (last eval-ids))
                (page-id-max (first eval-ids)))
           (pagination
            (format #f "?border-high=~d" (1+ id-max))
            (if (= page-id-max id-max)
                ""
                (format #f "?border-low=~d" page-id-max))
            (if (= page-id-min id-min)
                ""
                (format #f "?border-high=~d" page-id-min))
            (format #f "?border-low=~d" (1- id-min)))))))

(define (build-eval-table builds build-min build-max)
  "Return HTML for the BUILDS table NAME. BUILD-MIN and BUILD-MAX are
   global minimal and maximal (stoptime, id) pairs."
  (define (table-header)
    `(thead
      (tr
       (th (@ (scope "col")) '())
       (th (@ (scope "col")) ID)
       (th (@ (scope "col")) Specification)
       (th (@ (scope "col")) "Finished at")
       (th (@ (scope "col")) Job)
       (th (@ (scope "col")) Nixname)
       (th (@ (scope "col")) System))))

  (define (table-row build)
    `(tr
      (td ,(case (assq-ref build #:buildstatus)
             ((0) `(span (@ (class "oi oi-check text-success")
                            (title "Succeeded")
                            (aria-hidden "true"))
                         ""))
             ((1 2 3 4) `(span (@ (class "oi oi-x text-danger")
                                  (title "Failed")
                                  (aria-hidden "true"))
                               ""))
             (else `(span (@ (class "oi oi-clock text-warning")
                             (title "Scheduled")
                             (aria-hidden "true"))
                          ""))))
      (th (@ (scope "row")),(assq-ref build #:id))
      (td ,(assq-ref build #:jobset))
      (td ,(strftime "%c" (localtime (assq-ref build #:stoptime))))
      (td ,(assq-ref build #:job))
      (td ,(assq-ref build #:nixname))
      (td ,(assq-ref build #:system))))

  (define (build-id build)
    (match build
      ((stoptime id) id)))

  (define (build-stoptime build)
    (match build
      ((stoptime id) stoptime)))

  `((table
     (@ (class "table table-sm table-hover table-striped"))
     ,@(if (null? builds)
           `((th (@ (scope "col")) "No elements here."))
           `(,(table-header)
             (tbody ,@(map table-row builds)))))
    ,(if (null? builds)
         (pagination "" "" "" "")
         (let* ((build-time-ids (map (lambda (row)
                                       (list (assq-ref row #:stoptime)
                                             (assq-ref row #:id)))
                                     builds))
                (page-build-min (last build-time-ids))
                (page-build-max (first build-time-ids)))
           (pagination
            (format #f "?border-high-time=~d&border-high-id=~d"
                    (build-stoptime build-max)
                    (1+ (build-id build-max)))
            (if (equal? page-build-max build-max)
                ""
                (format #f "?border-low-time=~d&border-low-id=~d"
                        (build-stoptime page-build-max)
                        (build-id page-build-max)))
            (if (equal? page-build-min build-min)
                ""
                (format #f "?border-high-time=~d&border-high-id=~d"
                        (build-stoptime page-build-min)
                        (build-id page-build-min)))
            (format #f "?border-low-time=~d&border-low-id=~d"
                    (build-stoptime build-min)
                    (1- (build-id build-min))))))))