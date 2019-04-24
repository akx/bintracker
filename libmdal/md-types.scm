;; This file is part of the libmdal library.
;; Copyright (c) utz/irrlicht project 2018
;; See LICENSE for license details.

;;; # Module MD-TYPES
;;; md-module record types and additional accessors

(module md-types *

  (import scheme (chicken base) (chicken string) (chicken format)
	  srfi-1 srfi-13 srfi-69 md-helpers)

  ;; ---------------------------------------------------------------------------
  ;;; ## MDMOD: INPUT NODES
  ;; ---------------------------------------------------------------------------

  ;;; val can be one of
  ;;;   () -> inactive node
  ;;;   a string of the actual value
  ;;;   a list of subnodes
  (define-record-type md:inode-instance
    (md:make-inode-instance-base val name)
    md:node-instance?
    (val md:inode-instance-val md:set-inode-instance-val!)
    (name md:inode-instance-name md:set-inode-instance-name!))

  (define (md:make-inode-instance val #!optional (name ""))
    (md:make-inode-instance-base val name))

  (define-record-printer (md:inode-instance i out)
    (begin
      (fprintf out "#<md:inode-instance>: ~A\n" (md:inode-instance-name i))
      (fprintf out "~S\n" (md:inode-instance-val i))))

  ;;; return the subnode of the given id
  (define (md:get-subnode inode-instance subnode-id)
    (find (lambda (node)
	    (string=? (md:inode-cfg-id node) subnode-id))
	  (md:inode-instance-val inode-instance)))

  ;;; it might be desirable to have 'instances' be a hash map, and only turn it
  ;;; into an alist which is then sorted on request
  ;;; (eg md:inode-get-sorted-inst)
  (define-record-type md:inode
    (md:make-inode cfg-id instances)
    md:inode?
    (cfg-id md:inode-cfg-id md:set-inode-cfg-id!)
    (instances md:inode-instances md:set-inode-instances!))

  (define-record-printer (md:inode node out)
    (begin
      (fprintf out "#<md:inode: ~A>\n" (md:inode-cfg-id node))
      (for-each (lambda (x) (fprintf out "instance ~S: ~S\n" (car x) (cdr x)))
		(md:inode-instances node))))

  ;;; return the number of instances in the given inode
  (define (md:inode-count-instances node)
    (if (not (md:inode-instances node))
	0
	(length (md:inode-instances node))))

  ;; ---------------------------------------------------------------------------
  ;;; ## MDMOD: MODULE
  ;; ---------------------------------------------------------------------------

  (define-record-type md:module
    (md:make-module cfg-id cfg global-node)
    md:module?
    (cfg-id md:mod-cfg-id md:set-mod-cfg-id!)
    (cfg md:mod-cfg md:set-mod-cfg!)
    (global-node md:mod-global-node md:set-mod-global-node!))

  (define-record-printer (md:module mod out)
    (begin
      (fprintf out "#<md:module>\n\nCONFIG ID: ~A\n\n" (md:mod-cfg-id mod))
      (fprintf out "CONFIG:\n~S\n" (md:mod-cfg mod))))

  ;;; generate a function that takes an inode as parameter, and returns the node
  ;;; instance matching the given numeric instance id
  ;;; TODO should check if node instance actually exists
  (define (md:mod-get-node-instance id)
    (lambda (node)
      (car (alist-ref id (md:inode-instances node)))))

  ;;; lo-level api, generate a function that takes an inode as param, and
  ;;; returns the node matching the given path
  (define (md:make-npath-fn pathlist)
    (if (= 2 (length pathlist))
	(lambda (node)
	  (find (lambda (subnode-id)
		  (string=? (md:inode-cfg-id subnode-id)
			    (cadr pathlist)))
		(md:inode-instance-val
		 ((md:mod-get-node-instance (string->number (car pathlist)))
		  node))))
	(lambda (node)
	  ((md:make-npath-fn (cddr pathlist))
	   ((md:make-npath-fn (take pathlist 2)) node)))))

  ;;; generate a function that takes an inode as parameter, and returns the node
  ;;; instance matching the given path
  (define (md:node-instance-path path)
    (letrec ((make-instance-path-fn
	      (lambda (pathlist)
		(if (= 1 (length pathlist))
		    (md:mod-get-node-instance (string->number (car pathlist)))
		    (lambda (node)
		      ((make-instance-path-fn (cddr pathlist))
		       ((md:make-npath-fn (take pathlist 2)) node)))))))
      (make-instance-path-fn (string-split path "/"))))

  ;;; generate a function that takes an inode as parameter, and returns the
  ;;; subnode matching the given path
  (define (md:node-path path)
    (md:make-npath-fn (string-split path "/")))


  ;;----------------------------------------------------------------------------
  ;;; ### md:mod accessor functions
  ;;----------------------------------------------------------------------------

  ;;; split a list of subnodes into two seperate lists at the given node-id. The
  ;;; second list will be the tail, including the node at split point.
  (define (md:mod-split-node-list-at node-id nodes)
    (receive (break (lambda (node)
		      (string=? node-id (md:inode-cfg-id node)))
		    nodes)))

  ;;; split a list of inode instances into two seperate lists at the given node
  ;;; instance id. The second list will be the tail, including the instance at
  ;;; split point.
  (define (md:mod-split-instances-at inst-id instances)
    (receive (break (lambda (inst)
		      (= inst-id (car inst)))
		    instances)))

  ;;; replace the subnode matching the given subnode's id in the given parent
  ;;; inode instance with the given new subnode
  (define (md:mod-replace-subnode parent-node-instance subnode)
    (let ((split-subnodes (md:mod-split-node-list-at
			   (md:inode-cfg-id subnode)
			   (md:inode-instance-val parent-node-instance))))
      (md:make-inode-instance
       (append (car split-subnodes)
	       (cons subnode (cdadr split-subnodes)))
       (md:inode-instance-name parent-node-instance))))

  ;;; replace the inode instance with the given id in the given inode with the
  ;;; given new inode instance
  (define (md:mod-replace-inode-instance inode inst-id instance)
    (let ((split-instances (md:mod-split-instances-at
			    inst-id (md:inode-instances inode))))
      (md:make-inode
       (md:inode-cfg-id inode)
       (append (car split-instances)
	       (cons (list inst-id instance)
		     (cdadr split-instances))))))

  ;;; helper fn for md:mod-set-node
  (define (md:mod-make-node-setter path-lst nesting-level)
    (if (= nesting-level (length path-lst))
	`(md:mod-replace-subnode
	  (,(md:node-instance-path (string-join path-lst "/")) ancestor-node)
	  subnode)
	`(md:mod-replace-subnode
	  (,(md:node-instance-path
	     (string-join (take path-lst nesting-level) "/")) ancestor-node)
	  ,(md:mod-make-instance-setter path-lst (+ nesting-level 1)))))

  ;;; helper fn for md:mod-set-node
  (define (md:mod-make-instance-setter path-lst nesting-level)
    `(md:mod-replace-inode-instance
      (,(md:node-path
	 (string-join (take path-lst nesting-level) "/")) ancestor-node)
      ,(string->number (car (reverse path-lst)))
      ,(md:mod-make-node-setter path-lst (+ nesting-level 1))))

  ;;; Generate a function that replaces an arbitrarily deeply nested subnode in
  ;;; the given parent node, as specified by the given node-path string.
  (define (md:mod-node-setter parent-instance-path-str)
    (let ((setter `(md:mod-replace-inode-instance
		    ancestor-node 0
		    ,(md:mod-make-node-setter
		      (string-split parent-instance-path-str "/")
		      1))))
      (eval (append '(lambda (subnode ancestor-node))
		    (list setter)))))

  ;;; Returns the values of all field node instances of the given {{row}} of the
  ;;; given non-order block-instances in the given {{group-instance}} as a
  ;;; flat list.
  ;;; {{block-instance-ids}} must be a list containing the requested numerical
  ;;; block instance IDs for each non-order block in the group.
  ;;; Empty (unset) instance values will be returned as #f.
  (define (md:mod-get-row-values group-instance block-instance-ids row)
    (flatten (map (lambda (block-instance)
		    (map (lambda (field-node)
			   (let ((instance-val
				  (md:inode-instance-val
				   (car (alist-ref
					 row (md:inode-instances
					      field-node))))))
			     (if (null? instance-val)
				 #f instance-val)))
			 (md:inode-instance-val block-instance)))
		  (map (lambda (blk-inst-id blk-node)
			 (car (alist-ref blk-inst-id
					 (md:inode-instances blk-node))))
		       block-instance-ids
		       (remove (lambda (block-node)
				 (string-contains (md:inode-cfg-id block-node)
						  "_ORDER"))
			       (md:inode-instance-val group-instance))))))

  ;;; Returns the values of all field node instances of the non-order block
  ;;; instances in the given {{group-instance}}, as a list of row value sets.
  ;;; Effectively calls md-mod-get-row-values on each row of the relevant
  ;;; blocks.
  ;;; TODO: will break if order node is the first in group instance subnodes.
  (define (md:mod-get-block-values group-instance block-instance-ids)
    (map (lambda (row)
	   (md:mod-get-row-values group-instance block-instance-ids row))
	 (iota (md:inode-count-instances
		(car (md:inode-instance-val
		      (car (alist-ref (car block-instance-ids)
				      (md:inode-instances
				       (car (md:inode-instance-val
					     group-instance)))))))))))

  ) ;; end module md-types