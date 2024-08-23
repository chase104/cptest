DROP PROCEDURE IF EXISTS lf_reset_report_v2;
SET collation_connection = 'utf8mb4_general_ci';
CREATE PROCEDURE `lf_reset_report_v2`(
  IN p_course_id BIGINT,
  IN p_module_id BIGINT,
  IN p_report_id BIGINT,
  IN p_user_id BIGINT,
  IN p_modified_by BIGINT
)
BEGIN

/*
  current:  20240314140745-lf_report_reset_v2
  previous: 20231106163112-lf_report_reset_v2
            20230928170538-lf_report_reset_v2
            20221020214921-lf_report_reset_v2
            20220114193816-lf_report_reset_v2
            20210804153045-lf_report_reset_v2
            20201014164823-lf_report_reset_v2
*/

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;
    UPDATE
      lf_report_grades
    SET
      grade_status = 0,
      submit_state = 0,
      grade_value = NULL,
      submission_date = NULL,
      general_comment = NULL,
      comment_count = 0,
      submit_count = NULL,
      draft_count = NULL,
      used_provisional_data = NULL,
      flagged_late_penalty = NULL
    WHERE
      mdl_user_id=p_user_id
    AND
      mdl_lfreport_id=p_report_id
    AND
      deleted_at IS NULL;

   UPDATE
      lf_report_grade_items
   LEFT JOIN
      lf_report_attempts
    ON
      lf_report_grade_items.id = lf_report_attempts.lf_report_grade_item
    SET
      lf_report_attempts.deleted_at=NOW(),
      lf_report_grade_items.deleted_at=NOW()
    WHERE
      lf_report_grade_items.mdl_user_id_take=p_user_id
    AND
      lf_report_grade_items.mdl_lfreport_id=p_report_id
    AND
      lf_report_grade_items.deleted_at IS NULL;

    INSERT INTO lf_report_grade_item_logs (
      lf_report_grade_item_id,
      definition_item_id,
      mdl_lfreport_id,
      mdl_user_id_take,
      item_type,
      grade_value,
      mdl_user_id_grade,
      grader_comment,
      take_status,
      grade_status,
      created_at,
      updated_at,
      deleted_at,
      deleted_by)
    SELECT
      id,
      definition_item_id,
      mdl_lfreport_id,
      mdl_user_id_take,
      item_type,
      grade_value,
      mdl_user_id_grade,
      grader_comment,
      take_status,
      grade_status,
      created_at,
      updated_at,
      now(),
      p_modified_by
    FROM lf_report_grade_items
    WHERE deleted_at IS NOT NULL
      AND lf_report_grade_items.mdl_user_id_take=p_user_id
      AND lf_report_grade_items.mdl_lfreport_id=p_report_id;

    DELETE FROM lf_report_grade_items
    WHERE deleted_at IS NOT NULL
      AND mdl_user_id_take=p_user_id
      AND mdl_lfreport_id=p_report_id;

    UPDATE lf_grade_item_status
    INNER JOIN mdl_grade_items
      ON mdl_grade_items.id = lf_grade_item_status.mdl_grade_item_id
      AND mdl_grade_items.courseid = lf_grade_item_status.mdl_course_id
    SET lf_grade_item_status.status = 'INIT',
        lf_grade_item_status.status_change_timestamp = UNIX_TIMESTAMP(NOW()) * 1000,
        lf_grade_item_status.updated_at = NOW(),
        lf_grade_item_status.status_modified_by = p_modified_by
    WHERE lf_grade_item_status.mdl_user_id = p_user_id
      AND mdl_grade_items.iteminstance = p_report_id
      AND mdl_grade_items.itemtype = 'mod'
      AND mdl_grade_items.itemmodule = 'lfreport'
      AND mdl_grade_items.courseid = p_course_id;

    INSERT INTO lf_tii_submissions_logs (
      lf_tii_submissions_id,
      mdl_course_id,
      activity_type,
      activity_id,
      mdl_user_id_author,
      activity_attempt_id,
      status,
      tii_submission_id,
      tii_pdf_id,
      overall_similarity,
      age_id,
      created_at,
      updated_at,
      deleted_at,
      deleted_by)
    SELECT
      id,
      mdl_course_id,
      activity_type,
      activity_id,
      mdl_user_id_author,
      activity_attempt_id,
      status,
      tii_submission_id,
      tii_pdf_id,
      overall_similarity,
      age_id,
      created_at,
      updated_at,
      now(),
      p_modified_by
    FROM lf_tii_submissions
    WHERE deleted_at IS NULL
      AND mdl_course_id = p_course_id
      AND activity_id = p_report_id
      AND mdl_user_id_author = p_user_id;

    DELETE FROM lf_tii_submissions
    WHERE deleted_at IS NULL
      AND mdl_course_id = p_course_id
      AND activity_id = p_report_id
      AND mdl_user_id_author = p_user_id;


  COMMIT;

END
