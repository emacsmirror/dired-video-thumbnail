;;; dired-video-thumbnail-test.el --- Tests for dired-video-thumbnail -*- lexical-binding: t; -*-

;; Copyright (C) 2025 James Dyer

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Unit tests for dired-video-thumbnail using ERT (Emacs Regression Testing).

;;; Code:

(require 'ert)
(require 'dired-video-thumbnail)

;;; Test Utilities

(defvar dired-video-thumbnail-test-dir
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing test files.")

;;; Tests for utility functions

(ert-deftest dired-video-thumbnail-test-video-p ()
  "Test `dired-video-thumbnail--video-p' function."
  (let ((test-file (expand-file-name "test_001.mp4" dired-video-thumbnail-test-dir)))
    ;; Should return non-nil for actual video files
    (should (dired-video-thumbnail--video-p test-file)))

  ;; Test with various extensions
  (let ((temp-dir (make-temp-file "video-test" t)))
    (unwind-protect
        (progn
          ;; Create dummy files
          (write-region "" nil (expand-file-name "test.mp4" temp-dir))
          (write-region "" nil (expand-file-name "test.avi" temp-dir))
          (write-region "" nil (expand-file-name "test.mkv" temp-dir))
          (write-region "" nil (expand-file-name "test.txt" temp-dir))
          (write-region "" nil (expand-file-name "test" temp-dir))

          ;; Test video extensions
          (should (dired-video-thumbnail--video-p (expand-file-name "test.mp4" temp-dir)))
          (should (dired-video-thumbnail--video-p (expand-file-name "test.avi" temp-dir)))
          (should (dired-video-thumbnail--video-p (expand-file-name "test.mkv" temp-dir)))

          ;; Test non-video files
          (should-not (dired-video-thumbnail--video-p (expand-file-name "test.txt" temp-dir)))
          (should-not (dired-video-thumbnail--video-p (expand-file-name "test" temp-dir))))
      ;; Cleanup
      (delete-directory temp-dir t))))

(ert-deftest dired-video-thumbnail-test-ensure-cache-dir ()
  "Test `dired-video-thumbnail--ensure-cache-dir' function."
  (let ((dired-video-thumbnail-cache-dir (make-temp-name "/tmp/test-cache-")))
    (unwind-protect
        (progn
          ;; Directory shouldn't exist yet
          (should-not (file-directory-p dired-video-thumbnail-cache-dir))

          ;; Call ensure function
          (dired-video-thumbnail--ensure-cache-dir)

          ;; Directory should now exist
          (should (file-directory-p dired-video-thumbnail-cache-dir)))
      ;; Cleanup
      (when (file-directory-p dired-video-thumbnail-cache-dir)
        (delete-directory dired-video-thumbnail-cache-dir)))))

(ert-deftest dired-video-thumbnail-test-cache-path ()
  "Test `dired-video-thumbnail--cache-path' function."
  (let ((dired-video-thumbnail-cache-dir "/tmp/test-cache/")
        (test-file "/path/to/video.mp4"))
    ;; Cache path should be in cache directory
    (let ((cache-path (dired-video-thumbnail--cache-path test-file)))
      (should (string-prefix-p dired-video-thumbnail-cache-dir cache-path))
      (should (string-suffix-p ".jpg" cache-path))

      ;; Same file should always produce same cache path (within same mtime)
      (let ((cache-path-2 (dired-video-thumbnail--cache-path test-file)))
        (should (string= cache-path cache-path-2))))))

;;; Tests for formatting functions

(ert-deftest dired-video-thumbnail-test-format-duration ()
  "Test `dired-video-thumbnail--format-duration' function."
  ;; Test various durations
  (should (string= (dired-video-thumbnail--format-duration 0) "0:00"))
  (should (string= (dired-video-thumbnail--format-duration 30) "0:30"))
  (should (string= (dired-video-thumbnail--format-duration 60) "1:00"))
  (should (string= (dired-video-thumbnail--format-duration 90) "1:30"))
  (should (string= (dired-video-thumbnail--format-duration 3599) "59:59"))
  (should (string= (dired-video-thumbnail--format-duration 3600) "1:00:00"))
  (should (string= (dired-video-thumbnail--format-duration 3661) "1:01:01"))
  (should (string= (dired-video-thumbnail--format-duration 7322) "2:02:02"))

  ;; Test with nil
  (should-not (dired-video-thumbnail--format-duration nil))

  ;; Test with floats
  (should (string= (dired-video-thumbnail--format-duration 90.5) "1:30"))
  (should (string= (dired-video-thumbnail--format-duration 125.7) "2:05")))

(ert-deftest dired-video-thumbnail-test-relative-name ()
  "Test `dired-video-thumbnail--relative-name' function."
  (let ((dired-video-thumbnail--source-dir "/home/user/videos/"))
    ;; Test absolute path within source dir
    (should (string= (dired-video-thumbnail--relative-name "/home/user/videos/test.mp4")
                     "test.mp4"))
    (should (string= (dired-video-thumbnail--relative-name "/home/user/videos/subdir/test.mp4")
                     "subdir/test.mp4"))

    ;; Test when source dir is nil
    (let ((dired-video-thumbnail--source-dir nil))
      (should (string= (dired-video-thumbnail--relative-name "/home/user/videos/test.mp4")
                       "test.mp4")))))

;;; Tests for sorting functions

(ert-deftest dired-video-thumbnail-test-sort-by-name ()
  "Test sorting videos by name."
  (let ((videos '("/path/to/zebra.mp4" "/path/to/alpha.mp4" "/path/to/beta.mp4"))
        (dired-video-thumbnail--sort-by 'name)
        (dired-video-thumbnail--sort-order 'ascending))
    (let ((sorted (dired-video-thumbnail--sort-videos videos)))
      (should (equal sorted '("/path/to/alpha.mp4" "/path/to/beta.mp4" "/path/to/zebra.mp4"))))

    ;; Test descending
    (let ((dired-video-thumbnail--sort-order 'descending))
      (let ((sorted (dired-video-thumbnail--sort-videos videos)))
        (should (equal sorted '("/path/to/zebra.mp4" "/path/to/beta.mp4" "/path/to/alpha.mp4")))))))

(ert-deftest dired-video-thumbnail-test-sort-by-size ()
  "Test sorting videos by size."
  (let* ((temp-dir (make-temp-file "video-sort-test" t))
         (small-file (expand-file-name "small.mp4" temp-dir))
         (medium-file (expand-file-name "medium.mp4" temp-dir))
         (large-file (expand-file-name "large.mp4" temp-dir)))
    (unwind-protect
        (progn
          ;; Create files of different sizes
          (write-region (make-string 100 ?x) nil small-file)
          (write-region (make-string 500 ?x) nil medium-file)
          (write-region (make-string 1000 ?x) nil large-file)

          (let ((videos (list large-file small-file medium-file))
                (dired-video-thumbnail--sort-by 'size)
                (dired-video-thumbnail--sort-order 'ascending))
            (let ((sorted (dired-video-thumbnail--sort-videos videos)))
              (should (equal sorted (list small-file medium-file large-file))))))
      ;; Cleanup
      (delete-directory temp-dir t))))

;;; Tests for filtering functions

(ert-deftest dired-video-thumbnail-test-filter-by-name ()
  "Test filtering videos by name."
  (let ((videos '("/path/to/test_001.mp4" "/path/to/test_002.mp4" "/path/to/movie.mp4"))
        (dired-video-thumbnail--filter-name "test_"))
    (let ((filtered (dired-video-thumbnail--filter-videos videos)))
      (should (equal (length filtered) 2))
      (should (member "/path/to/test_001.mp4" filtered))
      (should (member "/path/to/test_002.mp4" filtered))
      (should-not (member "/path/to/movie.mp4" filtered)))))

(ert-deftest dired-video-thumbnail-test-filter-by-duration ()
  "Test filtering videos by duration."
  (let ((videos '("/path/to/short.mp4" "/path/to/medium.mp4" "/path/to/long.mp4"))
        (dired-video-thumbnail--video-info-cache (make-hash-table :test 'equal)))
    ;; Set up mock video info
    (puthash "/path/to/short.mp4" '(:duration 30) dired-video-thumbnail--video-info-cache)
    (puthash "/path/to/medium.mp4" '(:duration 120) dired-video-thumbnail--video-info-cache)
    (puthash "/path/to/long.mp4" '(:duration 300) dired-video-thumbnail--video-info-cache)

    ;; Test minimum duration filter
    (let ((dired-video-thumbnail--filter-duration-min 60))
      (let ((filtered (dired-video-thumbnail--filter-videos videos)))
        (should (equal (length filtered) 2))
        (should-not (member "/path/to/short.mp4" filtered))
        (should (member "/path/to/medium.mp4" filtered))
        (should (member "/path/to/long.mp4" filtered))))

    ;; Test maximum duration filter
    (let ((dired-video-thumbnail--filter-duration-min nil)
          (dired-video-thumbnail--filter-duration-max 150))
      (let ((filtered (dired-video-thumbnail--filter-videos videos)))
        (should (equal (length filtered) 2))
        (should (member "/path/to/short.mp4" filtered))
        (should (member "/path/to/medium.mp4" filtered))
        (should-not (member "/path/to/long.mp4" filtered))))

    ;; Test range
    (let ((dired-video-thumbnail--filter-duration-min 60)
          (dired-video-thumbnail--filter-duration-max 150))
      (let ((filtered (dired-video-thumbnail--filter-videos videos)))
        (should (equal (length filtered) 1))
        (should (equal filtered '("/path/to/medium.mp4")))))))

(ert-deftest dired-video-thumbnail-test-filter-by-size ()
  "Test filtering videos by file size."
  (let* ((temp-dir (make-temp-file "video-filter-test" t))
         (small-file (expand-file-name "small.mp4" temp-dir))
         (medium-file (expand-file-name "medium.mp4" temp-dir))
         (large-file (expand-file-name "large.mp4" temp-dir)))
    (unwind-protect
        (progn
          ;; Create files of different sizes
          (write-region (make-string 100 ?x) nil small-file)
          (write-region (make-string 5000 ?x) nil medium-file)
          (write-region (make-string 10000 ?x) nil large-file)

          (let ((videos (list small-file medium-file large-file)))
            ;; Test minimum size filter
            (let ((dired-video-thumbnail--filter-size-min 1000))
              (let ((filtered (dired-video-thumbnail--filter-videos videos)))
                (should (equal (length filtered) 2))
                (should-not (member small-file filtered))
                (should (member medium-file filtered))
                (should (member large-file filtered))))

            ;; Test maximum size filter
            (let ((dired-video-thumbnail--filter-size-min nil)
                  (dired-video-thumbnail--filter-size-max 6000))
              (let ((filtered (dired-video-thumbnail--filter-videos videos)))
                (should (equal (length filtered) 2))
                (should (member small-file filtered))
                (should (member medium-file filtered))
                (should-not (member large-file filtered))))))
      ;; Cleanup
      (delete-directory temp-dir t))))

(ert-deftest dired-video-thumbnail-test-combined-filters ()
  "Test combining multiple filters."
  (let* ((temp-dir (make-temp-file "video-combined-filter-test" t))
         (file1 (expand-file-name "test_small.mp4" temp-dir))
         (file2 (expand-file-name "test_large.mp4" temp-dir))
         (file3 (expand-file-name "movie_small.mp4" temp-dir)))
    (unwind-protect
        (progn
          ;; Create files
          (write-region (make-string 100 ?x) nil file1)
          (write-region (make-string 5000 ?x) nil file2)
          (write-region (make-string 100 ?x) nil file3)

          (let ((videos (list file1 file2 file3))
                (dired-video-thumbnail--filter-name "test_")
                (dired-video-thumbnail--filter-size-min 50))
            (let ((filtered (dired-video-thumbnail--filter-videos videos)))
              ;; Should match both name pattern and size requirement
              (should (equal (length filtered) 2))
              (should (member file1 filtered))
              (should (member file2 filtered))
              (should-not (member file3 filtered)))))
      ;; Cleanup
      (delete-directory temp-dir t))))

;;; Tests for video information parsing

(ert-deftest dired-video-thumbnail-test-video-info-caching ()
  "Test that video info is cached properly."
  (let ((dired-video-thumbnail--video-info-cache (make-hash-table :test 'equal))
        (test-file "/path/to/test.mp4")
        (test-info '(:width 1920 :height 1080 :duration 120)))
    ;; Manually add to cache
    (puthash test-file test-info dired-video-thumbnail--video-info-cache)

    ;; Should retrieve from cache
    (let ((info (dired-video-thumbnail--get-video-info test-file)))
      (should (equal info test-info))
      (should (= (plist-get info :width) 1920))
      (should (= (plist-get info :height) 1080))
      (should (= (plist-get info :duration) 120)))))

;;; Tests for finding videos

(ert-deftest dired-video-thumbnail-test-find-videos-non-recursive ()
  "Test finding videos in a directory non-recursively."
  ;; Use the actual test directory
  (let ((videos (dired-video-thumbnail--find-videos dired-video-thumbnail-test-dir nil)))
    ;; Should find some videos
    (should (> (length videos) 0))
    ;; All results should be video files
    (dolist (video videos)
      (should (dired-video-thumbnail--video-p video)))
    ;; Should all be in the test directory (not subdirectories)
    (dolist (video videos)
      (should (string= (file-name-directory video)
                       (file-name-as-directory dired-video-thumbnail-test-dir))))))

(ert-deftest dired-video-thumbnail-test-find-videos-recursive ()
  "Test finding videos recursively."
  (let* ((temp-dir (make-temp-file "video-recursive-test" t))
         (subdir (expand-file-name "subdir" temp-dir))
         (file1 (expand-file-name "test1.mp4" temp-dir))
         (file2 (expand-file-name "test2.mp4" subdir)))
    (unwind-protect
        (progn
          ;; Create directory structure
          (make-directory subdir)
          (write-region "" nil file1)
          (write-region "" nil file2)

          ;; Non-recursive should find only top-level
          (let ((videos (dired-video-thumbnail--find-videos temp-dir nil)))
            (should (= (length videos) 1))
            (should (member file1 videos)))

          ;; Recursive should find both
          (let ((videos (dired-video-thumbnail--find-videos temp-dir t)))
            (should (= (length videos) 2))
            (should (member file1 videos))
            (should (member file2 videos))))
      ;; Cleanup
      (delete-directory temp-dir t))))

;;; Tests for format active filters

(ert-deftest dired-video-thumbnail-test-format-active-filters ()
  "Test formatting of active filter descriptions."
  ;; No filters
  (let ((dired-video-thumbnail--filter-name nil)
        (dired-video-thumbnail--filter-duration-min nil)
        (dired-video-thumbnail--filter-duration-max nil)
        (dired-video-thumbnail--filter-size-min nil)
        (dired-video-thumbnail--filter-size-max nil))
    (should (string= (dired-video-thumbnail--format-active-filters) "")))

  ;; Name filter only
  (let ((dired-video-thumbnail--filter-name "test_")
        (dired-video-thumbnail--filter-duration-min nil)
        (dired-video-thumbnail--filter-duration-max nil)
        (dired-video-thumbnail--filter-size-min nil)
        (dired-video-thumbnail--filter-size-max nil))
    (should (string-match-p "name:/test_/" (dired-video-thumbnail--format-active-filters))))

  ;; Duration range filter
  (let ((dired-video-thumbnail--filter-name nil)
        (dired-video-thumbnail--filter-duration-min 60)
        (dired-video-thumbnail--filter-duration-max 300)
        (dired-video-thumbnail--filter-size-min nil)
        (dired-video-thumbnail--filter-size-max nil))
    (let ((result (dired-video-thumbnail--format-active-filters)))
      (should (string-match-p "duration:" result))
      (should (string-match-p "1:00" result))
      (should (string-match-p "5:00" result))))

  ;; Size range filter
  (let ((dired-video-thumbnail--filter-name nil)
        (dired-video-thumbnail--filter-duration-min nil)
        (dired-video-thumbnail--filter-duration-max nil)
        (dired-video-thumbnail--filter-size-min (* 10 1024 1024))  ; 10MB
        (dired-video-thumbnail--filter-size-max (* 100 1024 1024))) ; 100MB
    (let ((result (dired-video-thumbnail--format-active-filters)))
      (should (string-match-p "size:" result))
      (should (string-match-p "10MB" result))
      (should (string-match-p "100MB" result)))))

;;; Tests for marking helpers

(ert-deftest dired-video-thumbnail-test-get-dired-marked-set ()
  "Test that marked files are collected in one pass over dired."
  (let* ((temp-dir (make-temp-file "video-mark-set-test" t))
         (file1 (expand-file-name "a.mp4" temp-dir))
         (file2 (expand-file-name "b.mp4" temp-dir))
         (file3 (expand-file-name "c.mp4" temp-dir)))
    (unwind-protect
        (progn
          (write-region "" nil file1)
          (write-region "" nil file2)
          (write-region "" nil file3)
          (let ((dired-buf (dired-noselect temp-dir)))
            (unwind-protect
                (with-temp-buffer
                  (setq dired-video-thumbnail--dired-buffer dired-buf)
                  (setq dired-video-thumbnail--local-marks
                        (make-hash-table :test 'equal))
                  (setq dired-video-thumbnail--marked-set nil)
                  (with-current-buffer dired-buf
                    (dired-goto-file file1)
                    (dired-mark 1)
                    (dired-goto-file file3)
                    (dired-mark 1))
                  (let ((set (dired-video-thumbnail--get-dired-marked-set)))
                    (should (gethash file1 set))
                    (should-not (gethash file2 set))
                    (should (gethash file3 set)))
                  ;; Changing marks in dired invalidates the cached set
                  ;; automatically through the modification tick.
                  (with-current-buffer dired-buf
                    (dired-goto-file file2)
                    (dired-mark 1))
                  (should (gethash file2
                                   (dired-video-thumbnail--get-dired-marked-set)))
                  ;; Explicit invalidation rebuilds as well.
                  (dired-video-thumbnail--invalidate-marked-cache)
                  (should (gethash file2
                                   (dired-video-thumbnail--get-dired-marked-set))))
              (when (buffer-live-p dired-buf)
                (kill-buffer dired-buf)))))
      (delete-directory temp-dir t))))

(ert-deftest dired-video-thumbnail-test-marked-set-includes-local-marks ()
  "Test that local marks for files outside dired are included in the set."
  (with-temp-buffer
    (setq dired-video-thumbnail--dired-buffer nil)
    (setq dired-video-thumbnail--local-marks (make-hash-table :test 'equal))
    (puthash "/tmp/outside.mp4" t dired-video-thumbnail--local-marks)
    (setq dired-video-thumbnail--marked-set nil)
    (let ((set (dired-video-thumbnail--get-dired-marked-set)))
      (should (gethash "/tmp/outside.mp4" set))
      (should (dired-video-thumbnail--file-marked-p "/tmp/outside.mp4"))
      (should-not (dired-video-thumbnail--file-marked-p "/tmp/other.mp4")))))

(ert-deftest dired-video-thumbnail-test-count-marked-caching ()
  "Test that the marked count is cached until invalidated."
  (with-temp-buffer
    (setq dired-video-thumbnail--current-videos
          '("/tmp/a.mp4" "/tmp/b.mp4" "/tmp/c.mp4"))
    (setq dired-video-thumbnail--local-marks (make-hash-table :test 'equal))
    (setq dired-video-thumbnail--marked-set (make-hash-table :test 'equal))
    (setq dired-video-thumbnail--marked-count nil)
    (puthash "/tmp/a.mp4" t dired-video-thumbnail--marked-set)
    (puthash "/tmp/c.mp4" t dired-video-thumbnail--marked-set)
    (should (= (dired-video-thumbnail--count-marked) 2))
    ;; Direct mutation of the set is ignored while the count is cached.
    (puthash "/tmp/b.mp4" t dired-video-thumbnail--marked-set)
    (should (= (dired-video-thumbnail--count-marked) 2))
    ;; Invalidating makes the next call recompute from the set.
    (dired-video-thumbnail--invalidate-marked-cache)
    (setq dired-video-thumbnail--marked-set (make-hash-table :test 'equal))
    (puthash "/tmp/a.mp4" t dired-video-thumbnail--marked-set)
    (puthash "/tmp/b.mp4" t dired-video-thumbnail--marked-set)
    (puthash "/tmp/c.mp4" t dired-video-thumbnail--marked-set)
    (should (= (dired-video-thumbnail--count-marked) 3))))

(ert-deftest dired-video-thumbnail-test-mark-targets ()
  "Test single-pass marking of videos, including local fallback marks."
  (let* ((temp-dir (make-temp-file "video-mark-targets-test" t))
         (subdir (expand-file-name "sub" temp-dir))
         (file1 (expand-file-name "a.mp4" temp-dir))
         (file2 (expand-file-name "b.mp4" temp-dir))
         (file3 (expand-file-name "c.mp4" temp-dir))
         (outside (expand-file-name "d.mp4" subdir)))
    (unwind-protect
        (progn
          (make-directory subdir)
          (write-region "" nil file1)
          (write-region "" nil file2)
          (write-region "" nil file3)
          (write-region "" nil outside)
          (let ((dired-buf (dired-noselect temp-dir)))
            (unwind-protect
                (with-temp-buffer
                  (setq dired-video-thumbnail--dired-buffer dired-buf)
                  (setq dired-video-thumbnail--local-marks
                        (make-hash-table :test 'equal))
                  (setq dired-video-thumbnail--marked-set nil)
                  (setq dired-video-thumbnail--marked-count nil)
                  (let ((targets (make-hash-table :test 'equal)))
                    (puthash file1 t targets)
                    (puthash file2 t targets)
                    (puthash outside t targets)
                    (dired-video-thumbnail--mark-targets targets ?*)
                    (with-current-buffer dired-buf
                      (save-excursion
                        (dired-goto-file file1)
                        (beginning-of-line)
                        (should (looking-at-p dired-re-mark))
                        (dired-goto-file file2)
                        (beginning-of-line)
                        (should (looking-at-p dired-re-mark))
                        (dired-goto-file file3)
                        (beginning-of-line)
                        (should-not (looking-at-p dired-re-mark))))
                    ;; The subdirectory file is marked locally.
                    (should (gethash outside dired-video-thumbnail--local-marks))
                    (should (dired-video-thumbnail--file-marked-p outside))
                    (should (dired-video-thumbnail--file-marked-p file1))
                    (should-not (dired-video-thumbnail--file-marked-p file3))
                    ;; Unmarking in one pass clears dired and local marks.
                    (dired-video-thumbnail--mark-targets targets ?\s)
                    (should-not (dired-video-thumbnail--file-marked-p outside))
                    (should-not (dired-video-thumbnail--file-marked-p file1))))
              (when (buffer-live-p dired-buf)
                (kill-buffer dired-buf)))))
      (delete-directory temp-dir t))))

(ert-deftest dired-video-thumbnail-test-position-of-file ()
  "Test locating a thumbnail by file name."
  (with-temp-buffer
    (insert " ")
    (let ((pos1 (1+ (point-min))))
      (insert "thumb1")
      (put-text-property pos1 (point) 'dired-video-thumbnail-file "/tmp/a.mp4")
      (put-text-property pos1 (point) 'dired-video-thumbnail-thumb-state "/tmp/a.jpg")
      (insert " ")
      (let ((pos2 (1+ (point))))
        (insert "thumb2")
        (put-text-property pos2 (point) 'dired-video-thumbnail-file "/tmp/b.mp4")
        (should (= (dired-video-thumbnail--position-of-file "/tmp/a.mp4") pos1))
        (should (= (dired-video-thumbnail--position-of-file "/tmp/b.mp4") pos2))
        (should-not (dired-video-thumbnail--position-of-file "/tmp/c.mp4"))))))

;;; Run all tests

(provide 'dired-video-thumbnail-test)
;;; dired-video-thumbnail-test.el ends here
