DROP PROCEDURE IF EXISTS lf_get_report_submissions_v4;

CREATE PROCEDURE `lf_get_report_submissions_v4`(
	IN p_course_id BIGINT,
	IN p_report_id BIGINT,
	IN p_sorted_user_list MEDIUMTEXT,
	IN p_group_criteria TEXT,
	IN p_user_criteria TEXT,
	IN p_status_criteria TEXT,
	IN p_posted_criteria BIT,
	IN p_sort_item_id BIGINT,
	IN p_sort_direction VARCHAR(10),
	IN p_row_offset BIGINT,
	IN p_row_count BIGINT
)
BEGIN

	/*
		current: 	20240129155455-lf_get_report_submissions_v4.sql
		previous: 20230615190301-lf_get_report_submissions_v4.sql
							20230123164403-lf_get_report_submissions_v4.sql
							20220209065831-lf_get_report_submissions_v3.sql
							20220118181932-lf_get_report_submissions_v3.sql
							20211129204245-lf_get_report_submissions_v3.sql
							20211111164623-lf_get_report_submissions_v2.sql
							20210804153045-lf_get_report_submissions.sql
							20210112224532-lf_get_report_submissions.sql
							20201217181220-lf_get_report_submissions.sql
							20201021202706-lf_get_report_submissions.sql
							20200713234102-lf_get_report_submissions.sql
							20200505201357-lf_get_report_submissions.sql
							20191122153009-lf_get_report_submissions.sql
	*/

	CALL lf_json_array_to_temp_table('lf_tmp_status_list', 'grade_status', 'BIGINT NOT NULL PRIMARY KEY', p_status_criteria);
	SET @include_not_started = 0 IN (SELECT grade_status FROM lf_tmp_status_list);

	CALL lf_course_create_student_list_v4(p_course_id, p_sorted_user_list, p_group_criteria, p_user_criteria, 0);

	SELECT
		COUNT(CASE WHEN ((lf_report_grades.grade_status IS NULL OR lf_report_grades.grade_status = 0)
      AND lf_grade_item_status.status IN ('INIT', 'PENDING')) THEN 1 ELSE NULL END) AS not_started_count,
		COUNT(CASE WHEN (lf_report_grades.grade_status = 1 AND lf_grade_item_status.status IN ('INIT', 'PENDING')) THEN 1 ELSE NULL END) AS draft_count,
		COUNT(CASE WHEN (lf_report_grades.grade_status = 2 AND lf_grade_item_status.status IN ('INIT', 'PENDING')) THEN 1 ELSE NULL END) AS submitted_count,
		COUNT(CASE WHEN (lf_report_grades.grade_status = 3 AND lf_grade_item_status.status IN ('INIT', 'PENDING')) THEN 1 ELSE NULL END) AS grading_started_count,
		COUNT(CASE WHEN (lf_report_grades.grade_status = 4 AND lf_grade_item_status.status IN ('INIT', 'PENDING')) THEN 1 ELSE NULL END) AS grading_complete_count,
		COUNT(CASE WHEN (lf_grade_item_status.status IN ('COMPLETE', 'COMPLETE_NONE', 'COMPLETE_AUTO', 'COMPLETE_LATE')) THEN 1 ELSE NULL END) AS grade_posted_count
	FROM lf_tmp_user_list
	LEFT JOIN mdl_grade_items
		ON mdl_grade_items.iteminstance = p_report_id
		AND mdl_grade_items.itemtype = 'mod'
		AND mdl_grade_items.itemmodule = 'lfreport'
	LEFT JOIN lf_grade_item_status
		ON mdl_grade_items.id = lf_grade_item_status.mdl_grade_item_id
		AND lf_grade_item_status.mdl_user_id = lf_tmp_user_list.userid
    AND lf_grade_item_status.mdl_course_id = mdl_grade_items.courseid
	LEFT JOIN lf_report_grades
		ON lf_report_grades.mdl_user_id = lf_tmp_user_list.userid
		AND lf_report_grades.mdl_lfreport_id = p_report_id
	WHERE mdl_grade_items.courseid = p_course_id;

	DROP TEMPORARY TABLE IF EXISTS lf_tmp_user_list_filtered;
	IF(p_status_criteria IS NOT NULL || p_posted_criteria IS NOT NULL) THEN
		CREATE TEMPORARY TABLE lf_tmp_user_list_filtered AS (
			SELECT lf_tmp_user_list.*
				FROM lf_tmp_user_list
			LEFT JOIN mdl_grade_items
				ON mdl_grade_items.iteminstance = p_report_id
				AND mdl_grade_items.itemtype = 'mod'
				AND mdl_grade_items.itemmodule = 'lfreport'
				AND mdl_grade_items.courseid = p_course_id
			LEFT JOIN lf_grade_item_status
				ON mdl_grade_items.id = lf_grade_item_status.mdl_grade_item_id
				AND lf_grade_item_status.mdl_user_id = lf_tmp_user_list.userid
			AND lf_grade_item_status.mdl_course_id = mdl_grade_items.courseid
			LEFT JOIN lf_report_grades
				ON lf_report_grades.mdl_user_id = lf_tmp_user_list.userid
				AND lf_report_grades.mdl_lfreport_id = mdl_grade_items.iteminstance
			WHERE (lf_report_grades.grade_status IN (SELECT grade_status FROM lf_tmp_status_list)
					OR (@include_not_started = 1 AND lf_report_grades.grade_status IS NULL))
					AND lf_grade_item_status.status IN ('INIT', 'PENDING')
				OR (p_posted_criteria = 1 AND lf_grade_item_status.status IN ('COMPLETE', 'COMPLETE_NONE', 'COMPLETE_AUTO', 'COMPLETE_LATE'))
				);
	ELSE
		CREATE TEMPORARY TABLE lf_tmp_user_list_filtered AS SELECT * FROM lf_tmp_user_list;
  END IF;

	ALTER TABLE lf_tmp_user_list_filtered ADD COLUMN cut_off_date BIGINT, ADD COLUMN max_attempts INT, ADD COLUMN allow_provisional BOOLEAN;

	DROP TEMPORARY TABLE IF EXISTS lf_tmp_overrides_user;
	CREATE TEMPORARY TABLE lf_tmp_overrides_user LIKE lf_overrides;
	INSERT lf_tmp_overrides_user SELECT * FROM lf_overrides
		WHERE lf_overrides.mdl_course_id = p_course_id
		AND lf_overrides.mdl_instance_id = p_report_id
		AND lf_overrides.mod_type = 'report'
		AND lf_overrides.deleted_at IS NULL;

	DROP TEMPORARY TABLE IF EXISTS lf_tmp_overrides_group;
	CREATE TEMPORARY TABLE lf_tmp_overrides_group LIKE lf_overrides;
	INSERT lf_tmp_overrides_group SELECT * FROM lf_overrides
		WHERE lf_overrides.mdl_course_id = p_course_id
		AND lf_overrides.mdl_instance_id = p_report_id
		AND lf_overrides.mod_type = 'report'
		AND lf_overrides.deleted_at IS NULL;

	DROP TEMPORARY TABLE IF EXISTS lf_tmp_calc_overrides;
	CREATE TEMPORARY TABLE IF NOT EXISTS lf_tmp_calc_overrides
		(PRIMARY KEY tmp_pkey (userid))
		AS (
		SELECT
			lf_tmp_user_list_filtered.userid,
			COALESCE(userOverrides.attempts, groupOverrides.attempts, null) as attempts,
			COALESCE(userOverrides.allow_provisional, groupOverrides.allow_provisional, null) as allow_provisional
	FROM lf_tmp_user_list_filtered
	LEFT JOIN lf_tmp_overrides_user as userOverrides
		ON userOverrides.mdl_user_id = lf_tmp_user_list_filtered.userid
	LEFT JOIN lf_tmp_overrides_group as groupOverrides
		ON groupOverrides.mdl_group_id = lf_tmp_user_list_filtered.group_id);

	UPDATE lf_tmp_user_list_filtered
		LEFT JOIN (
			SELECT
				lf_grade_item_status.mdl_user_id as userId,
				lf_grade_item_status.cut_off_date_calc as cutOffDate,
				lf_grade_item_status.mdl_course_id as courseId,
				mdl_grade_items.iteminstance as reportId
			FROM lf_grade_item_status
			LEFT JOIN mdl_grade_items
				ON mdl_grade_items.id = lf_grade_item_status.mdl_grade_item_id
				AND mdl_grade_items.courseid = lf_grade_item_status.mdl_course_id
			WHERE lf_grade_item_status.mdl_course_id = p_course_id
				AND mdl_grade_items.itemtype = 'mod'
				AND mdl_grade_items.itemmodule = 'lfreport'
				AND mdl_grade_items.iteminstance = p_report_id
			) as tmp_overrides
				ON tmp_overrides.userId = lf_tmp_user_list_filtered.userid
			LEFT JOIN lf_tmp_calc_overrides
				ON lf_tmp_calc_overrides.userid = tmp_overrides.userId
			LEFT JOIN mdl_lfreport
				ON mdl_lfreport.id = tmp_overrides.reportId
				AND mdl_lfreport.mdl_course_id = tmp_overrides.courseId
			SET lf_tmp_user_list_filtered.cut_off_date = tmp_overrides.cutOffDate,
					lf_tmp_user_list_filtered.max_attempts = COALESCE(lf_tmp_calc_overrides.attempts, mdl_lfreport.max_attempts, null),
					lf_tmp_user_list_filtered.allow_provisional = COALESCE(lf_tmp_calc_overrides.allow_provisional, mdl_lfreport.provisional_data, null);

	SELECT count(*) as total_count
	  FROM lf_tmp_user_list_filtered;

	SELECT distinct
			lf_tmp_user_list_filtered.userid as studentId,
			lf_tmp_user_list_filtered.identity_id,
			lf_tmp_user_list_filtered.group_name,
			lf_tmp_user_list_filtered.cut_off_date,
			lf_tmp_user_list_filtered.max_attempts,
			lf_tmp_user_list_filtered.allow_provisional,
			mdl_grade_grades.timecreated,
		  lf_grade_item_status.status,
			similarity.max_similarity,
		  IF(lf_grade_item_status.status_change_timestamp IS NULL, UNIX_TIMESTAMP(lf_grade_item_status.updated_at) * 1000,lf_grade_item_status.status_change_timestamp) as status_change_timestamp,
			lf_report_grades.*,
			(CASE
				WHEN p_sort_item_id = 0 THEN name_sort
				WHEN p_sort_item_id = 1 THEN trim(group_name)
				WHEN p_sort_item_id = 2 AND lf_grade_item_status.status IN ('COMPLETE', 'COMPLETE_NONE', 'COMPLETE_AUTO', 'COMPLETE_LATE') THEN 5
				WHEN p_sort_item_id = 2 AND lf_grade_item_status.status NOT IN ('COMPLETE', 'COMPLETE_NONE', 'COMPLETE_AUTO', 'COMPLETE_LATE')THEN lf_report_grades.grade_status
				WHEN p_sort_item_id = 3 THEN lf_report_grades.submit_state
				WHEN p_sort_item_id = 4 THEN lf_report_grades.updated_at
				WHEN p_sort_item_id = 5 THEN lf_report_grades.submission_date
				WHEN p_sort_item_id = 6 THEN lf_report_grades.grade_value
				WHEN p_sort_item_id = 7 AND lf_grade_item_status.status IN ('COMPLETE', 'COMPLETE_NONE', 'COMPLETE_AUTO', 'COMPLETE_LATE') THEN lf_report_grades.grade_value
				WHEN p_sort_item_id = 7 AND lf_grade_item_status.status NOT IN ('COMPLETE', 'COMPLETE_NONE', 'COMPLETE_AUTO', 'COMPLETE_LATE') THEN NULL
				WHEN p_sort_item_id = 8 THEN lf_grade_item_status.status_change_timestamp
				WHEN p_sort_item_id = 9 THEN lf_report_grades.used_provisional_data
				WHEN p_sort_item_id = 10 THEN similarity.max_similarity
			END) AS sort_field,
			name_sort AS secondary_sort_field
			FROM lf_tmp_user_list_filtered
			LEFT JOIN lf_report_grades
			ON lf_report_grades.mdl_user_id = lf_tmp_user_list_filtered.userid
			AND lf_report_grades.mdl_lfreport_id = p_report_id
		LEFT JOIN mdl_grade_items
			ON mdl_grade_items.iteminstance = p_report_id
			AND mdl_grade_items.itemtype = 'mod'
			AND mdl_grade_items.itemmodule = 'lfreport'
		LEFT JOIN mdl_grade_grades
			ON mdl_grade_items.id = mdl_grade_grades.itemid
			AND mdl_grade_grades.userid = lf_tmp_user_list_filtered.userid
		LEFT JOIN lf_grade_item_status
		  ON lf_grade_item_status.mdl_grade_item_id = mdl_grade_grades.itemid
		  AND lf_grade_item_status.mdl_user_id = mdl_grade_grades.userid
		  AND lf_grade_item_status.mdl_course_id = p_course_id
		  AND lf_grade_item_status.deleted_at IS NULL
		LEFT JOIN (
			SELECT
				mdl_user_id_author,
				MAX(overall_similarity) as max_similarity
			FROM lf_tii_submissions
			WHERE mdl_course_id = p_course_id
			AND activity_id = p_report_id
			AND activity_type = 'report'
			GROUP BY mdl_user_id_author
		) as similarity
			ON similarity.mdl_user_id_author = lf_tmp_user_list_filtered.userid
		WHERE mdl_grade_items.courseid = p_course_id
		ORDER BY
			CASE WHEN (p_sort_direction = 'asc' AND p_sort_item_id = 0) THEN CAST(sort_field AS DECIMAL (10,5)) END ASC,
			CASE WHEN (p_sort_direction = 'asc' AND p_sort_item_id IN (6, 7, 10)) THEN CAST(sort_field AS DECIMAL (10,5)) END ASC,
			CASE WHEN (p_sort_direction = 'asc' AND p_sort_item_id NOT IN (0, 6, 7, 10)) THEN sort_field END ASC,
			CASE WHEN (p_sort_direction = 'desc' AND p_sort_item_id = 0) THEN CAST(sort_field AS DECIMAL (10,5)) END DESC,
			CASE WHEN (p_sort_direction = 'desc' AND p_sort_item_id IN (6, 7, 10)) THEN CAST(sort_field AS DECIMAL (10,5)) END DESC,
			CASE WHEN (p_sort_direction = 'desc' AND p_sort_item_id NOT IN (0, 6, 7, 10)) THEN sort_field END DESC,
			CASE WHEN (p_sort_direction = 'asc' AND p_sort_item_id <> 0) THEN secondary_sort_field END ASC,
			CASE WHEN (p_sort_direction = 'desc' AND p_sort_item_id <> 0) THEN secondary_sort_field END DESC
		LIMIT p_row_count OFFSET p_row_offset;
END
