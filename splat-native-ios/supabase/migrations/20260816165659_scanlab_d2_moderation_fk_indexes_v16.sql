create index scanlab_moderation_reviews_scan_idx
  on scanlab_private.moderation_reviews(scan_id);

create index scanlab_report_dismissals_review_idx
  on scanlab_private.report_dismissals(review_id);
