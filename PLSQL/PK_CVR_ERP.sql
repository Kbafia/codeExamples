CREATE OR REPLACE PACKAGE       "PK_CVR_ERP" AS
---------------------------------------------------------------------------------
-- Id:          "AAA"."PK_CVR_ERP"
--
-- Description: Custom procedures suppporting 
--              CVR Reversal & posting process
--
-- Note:        THIS PACKAGE IS CUSTOM CODE FOR TEST
--              THIS PACKAGE IS NOT SUPPORTED BY CORE TEST SUPPORT
--
---------------------------------------------------------------------------------
-- History:
-- KB 24-SEP-2019 Initial Creation
---------------------------------------------------------------------------------

---------------------------------------------------------------------------------
-- Custom procedures
---------------------------------------------------------------------------------
PROCEDURE pERP_JRNL_MERGE (o_bs_status OUT CHAR, o_update_count OUT NUMBER);
PROCEDURE pGUI_LOAD (o_bs_status OUT CHAR, o_update_count OUT NUMBER);
PROCEDURE pREVERSAL(pTASK_ID IN NUMBER, o_bs_status OUT CHAR, o_update_count OUT NUMBER);
END PK_CVR_ERP;
/


CREATE OR REPLACE PACKAGE BODY  "PK_CVR_ERP" AS
---------------------------------------------------------------------------------
-- Id:          "AAA"."PK_CVR_ERP"
--
-- Description: Custom procedures suppporting 
--              GL_DIRECT_ENTRY process
--
-- Note:        THIS PACKAGE IS CUSTOM CODE FOR TEST
--              THIS PACKAGE IS NOT SUPPORTED BY CORE TEST SUPPORT
--
---------------------------------------------------------------------------------
-- History:
-- KB 24-SEP-2019 Initial Creation
---------------------------------------------------------------------------------

---------------------------------------------------------------------------------
-- Private procedures
---------------------------------------------------------------------------------


-- -----------------------------------------------------------------------
-- Procedure:       AAA.PK_CVR_ERP.pERP_JRNL_MERGE
-- Description:     This process runs after the IGL030 file is loaded into
--                  AAA.OGL_JRNL_FDBCK_STG. This process will look for any
--                  new entries not found in AAA.CVR_ERP_FILE_TRACKER_AAA
--                  and merge them into AAA.CVR_ERP_FILE_TRACKER_AAA. 
--                  with status "U".
-- Note:
--
-- KB 20-OCT-2019   Initial Creation XXXX-3117
-- -----------------------------------------------------------------------



PROCEDURE pERP_JRNL_MERGE
(
    o_bs_status         OUT CHAR,
	o_update_count		OUT NUMBER
)
AS

s_proc_name VARCHAR2(80) := 'AAA.PK_CVR_ERP.pERP_JRNL_MERGE';
lv_START_TIME 	PLS_INTEGER := 0;
no_records_found_erp EXCEPTION;

BEGIN
	lv_START_TIME:=DBMS_UTILITY.GET_TIME();

    MERGE INTO AAA.CVR_ERP_FILE_TRACKER_AAA TBL
    USING
    (
        SELECT DISTINCT ATTRIBUTE3, ERP_JRNL_BUS_PERIOD
        FROM OGL_JRNL_FDBCK_STG OJFS
        WHERE ATTRIBUTE3 IS NOT NULL
    ) QRY
    ON (TBL.ABC_GLINT_FILE_ID = QRY.ATTRIBUTE3 AND TBL.ERP_JRNL_BUS_PERIOD = QRY.ERP_JRNL_BUS_PERIOD)
    WHEN NOT MATCHED THEN
    INSERT (    TBL.ABC_GLINT_FILE_ID,
                TBL.ERP_JRNL_BUS_PERIOD,
                TBL.EVENT_STATUS,
                TBL.CREATED_DATE,
                TBL.UPDATED_DATE
           )
    VALUES (    QRY.ATTRIBUTE3,
                QRY.ERP_JRNL_BUS_PERIOD,
                'U',
                SYSDATE,
                SYSDATE
           );
    o_update_count := SQL%ROWCOUNT;

-- ************************************IF STATEMENT NOTES******************************************************* 
   -- IF NO NEW ERP JRNLS FOUND, RAISE EXCEPTION AND DO NOTHING.
   -- ELSE COMMIT MERGED RECORDS INTO AAA.CVR_ERP_FILE_TRACKER_AAA TABLE.
    IF o_update_count = 0   
        THEN 
        DBMS_OUTPUT.PUT_LINE('Process raised ''no_records_found_AAA'' exception. Please check FR_LOG for details.');
        RAISE no_records_found_erp;
    ELSE 
        DBMS_OUTPUT.PUT_LINE(o_update_count||' records inserted into AAA.CVR_ERP_FILE_TRACKER_AAA.');
        BBB.pr_message(0, 'CVR ERP GLINT JOURNAL MERGE (AAA.PK_CVR_ERP.pERP_JRNL_MERGE) - execution time: ' || (DBMS_UTILITY.GET_TIME() - lv_START_TIME)/100.0 || ' s.', 9, s_proc_name, null, null, null, 'AAA', 'PL/SQL');
        BBB.pr_message(0, o_update_count||' records merged into AAA.CVR_ERP_FILE_TRACKER_AAA.', 9, s_proc_name, null, null, null, 'AAA', 'PL/SQL');
        commit;
        BBB.pr_message(0, 'GL_DIRECT_ENTRY_TEMP_AAA Event_Status Update (AAA.PK_CVR_ERP.pUPD_AAA_STATUS) - End', 9, s_proc_name, null, null, null, 'AAA', 'PL/SQL');
        o_bs_status := 'C';
    END IF;
-- *************************************************************************************************************  

    DBMS_OUTPUT.PUT_LINE('Process completed successfully. Full log details can be found in FR_LOG');

EXCEPTION
  WHEN no_records_found_erp THEN
        BBB.pr_error(0, 'No new ABC GLINT JOURNALS found from IGL030 ERP load.', 1, s_proc_name, 'OGL_JRNL_FDBCK_STG', null, 'ATTRIBUTE3', 'AAA', 'PL/SQL','A');
	    o_bs_status := 'C';
	    o_update_count := 0;

   WHEN OTHERS THEN
        rollback;
        DBMS_OUTPUT.PUT_LINE('Process failed on fatal error. Please check FR_LOG for details.');
    	BBB.pr_error(0, 'CVR ERP GLINT JOURNAL MERGE (AAA.PK_CVR_ERP.pERP_JRNL_MERGE) failed due to unhandled error. Check FR_LOG and ABC Audit Log.', 0, s_proc_name, NULL, NULL, NULL, 'AAA', 'PL/SQL');
        RAISE_APPLICATION_ERROR(-20001, 'Fatal error during call of AAA.PK_CVR_ERP.pERP_JRNL_MERGE: ' || SQLERRM);
	    o_bs_status := 'F';
	    o_update_count := 0;           
COMMIT;

END pERP_JRNL_MERGE;

-- -----------------------------------------------------------------------
-- Procedure:       AAA.PK_CVR_ERP.pGUI_LOAD
-- Description:     This process runs after pERP_JRNL_MERGE and it will look
--                  for any new IGL030 loads, then load any entries on that file
--                  that don't match the IGL013 file into FR_GENERAL_LOOKUP.
--                                   
-- Note:
--
-- KB 20-OCT-2019   Initial Creation XXXX-3117
-- -----------------------------------------------------------------------



PROCEDURE pGUI_LOAD
(
    o_bs_status         OUT CHAR,
	o_update_count		OUT NUMBER
)
AS

s_proc_name VARCHAR2(80) := 'AAA.PK_CVR_ERP.pGUI_LOAD';
lv_START_TIME 	PLS_INTEGER := 0;
lv_UPDATE_SQL   VARCHAR2(1000);
v_ABC_glint_file_id VARCHAR2(50);

no_records_found_gui EXCEPTION;


   -- Cursor to loop around all records to process in the hopper for the specified genral code
   CURSOR cur_unprocessed_files
   IS
      select distinct ABC_glint_file_id 
      from cvr_erp_file_tracker_AAA 
      where event_status = 'U';

    r_gui_inserts CVR_GUI_RECORDS_AAA_V%rowtype;
    CURSOR cur_gui_inserts (ABC_glint_file_id VARCHAR2)
    IS
        select *
        from CVR_GUI_RECORDS_AAA_V v
        where ABC_glint_file_id = v.ERP_GLINT_FILE_ID;
 -- end cursor  with statement

BEGIN
    o_update_count := 0;
	lv_START_TIME:=DBMS_UTILITY.GET_TIME();
DBMS_OUTPUT.PUT_LINE('OPEN cur_unprocessed_files LOOP');
FOR i IN cur_unprocessed_files 

         LOOP        
         DBMS_OUTPUT.PUT_LINE('v_ABC_glint_file_id values is '|| i.ABC_glint_file_id);
           OPEN cur_gui_inserts(i.ABC_glint_file_id);
               LOOP
                    FETCH cur_gui_inserts INTO r_gui_inserts;
                    EXIT WHEN cur_gui_inserts%notfound;
                   -- dbms_output.put_line('CALLING BBB.pr_sr_general_lookup_insert PROC');

                    BBB.pr_sr_general_lookup_insert(
                                                  a_general_lookup_type_code => 'CVR_JOURNAL_APPROVAL'
                                                , a_match_key1 => r_gui_inserts.YR_FILE_JRNL 
                                                , a_match_key2 => r_gui_inserts.GLINT_SEGMENT1
                                                , a_match_key3 => r_gui_inserts.GLINT_SEGMENT2
                                                , a_match_key4 => r_gui_inserts.GLINT_SEGMENT3
                                                , a_match_key5 => r_gui_inserts.GLINT_SEGMENT4
                                                , a_match_key6 => r_gui_inserts.GLINT_SEGMENT5
                                                , a_match_key7 => r_gui_inserts.GLINT_SEGMENT6
                                                , a_match_key8 => r_gui_inserts.GLINT_SEGMENT7
                                                , a_match_key9 => r_gui_inserts.GLINT_BATCH_ID
                                                , a_match_key10 => r_gui_inserts.GLINT_CONCAT_SEGMENTS
                                                , a_lookup_value1 => r_gui_inserts.ERP_SEGMENT1
                                                , a_lookup_value2 => r_gui_inserts.ERP_SEGMENT2
                                                , a_lookup_value3 => r_gui_inserts.ERP_SEGMENT3
                                                , a_lookup_value4 => r_gui_inserts.ERP_SEGMENT4
                                                , a_lookup_value5 => r_gui_inserts.ERP_SEGMENT5
                                                , a_lookup_value6 => r_gui_inserts.ERP_SEGMENT6
                                                , a_lookup_value7 => r_gui_inserts.ERP_SEGMENT7
                                                , a_lookup_value8 => r_gui_inserts.ERP_BATCH_ID
                                                , a_lookup_value9 => r_gui_inserts.ERP_CONCAT_SEGMENTS
                                                , a_lookup_value10 => 'U'
                                                );
                    o_update_count := o_update_count+SQL%ROWCOUNT;
               END LOOP;
           CLOSE cur_gui_inserts;
         lv_UPDATE_SQL:= 'update cvr_erp_file_tracker_AAA set event_status = ''P'', UPDATED_DATE = sysdate where ABC_glint_file_id = '||i.ABC_glint_file_id;
         DBMS_OUTPUT.PUT_LINE(lv_UPDATE_SQL);
         EXECUTE IMMEDIATE lv_UPDATE_SQL;
         commit;
         END LOOP;
IF o_update_count = 0
THEN raise no_records_found_gui;
END IF;

DBMS_OUTPUT.PUT_LINE('NO v_ABC_glint_file_id FOUND - CLOSE LOOP');
o_bs_status := 'C';

EXCEPTION 
WHEN no_records_found_gui THEN
        BBB.pr_error(0, 'No CVR records found to be loaded into GUI.', 1, s_proc_name, null, null, null, 'AAA', 'PL/SQL','A');
	    o_bs_status := 'C';
	    o_update_count := 0;


WHEN OTHERS THEN
        rollback;
        DBMS_OUTPUT.PUT_LINE('Process failed on fatal error. Please check FR_LOG for details.');
    	BBB.pr_error(0, 'CVR GUI LOAD (AAA.PK_CVR_ERP.pGUI_LOAD) failed due to unhandled error. Check FR_LOG and ABC Audit Log.', 0, s_proc_name, NULL, NULL, NULL, 'AAA', 'PL/SQL');
        RAISE_APPLICATION_ERROR(-20001, 'Fatal error during call of AAA.PK_CVR_ERP.pGUI_LOAD: ' || SQLERRM);
	    o_bs_status := 'F';
	    o_update_count := 0;           

END pGUI_LOAD;
-- -----------------------------------------------------------------------
-- Procedure:       AAA.PK_CVR_ERP.pREVERSAL
-- Description:     
--                  Scan FR_GENERAL_LOOKUP for 'A'pproved records and create
--                  reversal and new nopostb journal records for CVR error rows
--                  and loads them into AAA.ABC_JOURNAL_REVERSAL_AAA table.
--                  
--                  Afterwards, update records in FR_GENERAL_LOOKUP
--                  from 'A' to 'P' after they have been succesfully run
--                  through this process.
--
--                  Records will run through existing reversal journal process
--                  as part of the nightly batch run and go through adjustment hopper
--                  into FR_ACCOUNTING_EVENT, then get posted in CCC.
--
--
-- KB 20-OCT-2019   Initial Creation XXXX-3117
--
-- Notes:
--
-- MAPPING NOTES:
--     JL.JL_ENTITY    = APPR.LK_MATCH_KEY2--'TESTO'     --LK_LOOKUP_VALUE1
--     JL.JL_SEGMENT_3 = APPR.LK_MATCH_KEY3--'00'        --LK_LOOKUP_VALUE2
--     JL.JL_SEGMENT_4 = APPR.LK_MATCH_KEY4--'000'       --LK_LOOKUP_VALUE3
--     JL.JL_ACCOUNT   = APPR.LK_MATCH_KEY5 --'284222'   --LK_LOOKUP_VALUE4
--     JL.JL_SEGMENT_5 = APPR.LK_MATCH_KEY6 --'000000'   --LK_LOOKUP_VALUE5 
--     JL.JL_SEGMENT_6 = APPR.LK_MATCH_KEY7 --'000'      --LK_LOOKUP_VALUE6
--     JL.JL_SEGMENT_7 = APPR.LK_MATCH_KEY8 --'00000'    --LK_LOOKUP_VALUE7
--     JL.JL_SEGMENT_8 = APPR.LK_MATCH_KEY9 --'AHPEPUP'  --LK_LOOKUP_VALUE8

-- -----------------------------------------------------------------------


PROCEDURE pREVERSAL 
(
    pTASK_ID            IN NUMBER,
    o_bs_status         OUT CHAR,
	o_update_count		OUT NUMBER
)
AS
    lv_task_id NUMBER := nvl(pTASK_ID, -9999999999999);
    lv_START_TIME 	PLS_INTEGER := 0;
    p_precheck_cnt  NUMBER := 0;
    s_proc_name VARCHAR2(80) := 'AAA.PK_CVR_ERP.pREVERSAL';
    lv_insert_count NUMBER := 0;
    lv_jrnl_counter NUMBER := 0;
    lv_min_date DATE;
    lv_max_date DATE;


    no_records_found_cvr EXCEPTION;
    no_records_found_cvr_gui EXCEPTION;
    no_records_found_cvr_tmp EXCEPTION;

    lv_TEMP_INSERT_SQL   VARCHAR2(20000);
/*20191224 GF  Removed the following join from the lv_TEMP_INSERT_SQL query below, to circumvent SLR_JRNL_HEADERS,
               which is missing May 2019 records in ProdFix and Test environments.

                                                 INNER JOIN CCC.SLR_JRNL_HEADERS JH
                                                        ON  JH.JH_JRNL_DATE = GM.RGJM_EFFECTIVE_DATE
                                                        AND JH.JH_JRNL_ID = GM.RGJM_INPUT_JRNL_ID
                                                        AND JH.JH_JRNL_TYPE NOT LIKE (''CVR%'')

                                                 INNER JOIN CCC.SLR_JRNL_LINES JL
                                                        ON  JL.JL_EFFECTIVE_DATE = JH.JH_JRNL_DATE
                                                        AND JL.JL_JRNL_HDR_ID = JH.JH_JRNL_ID
*/


CURSOR c1 IS
SELECT
    cvr_record,
    rgjl_id,
    jl_jrnl_hdr_id,
    jl_jrnl_line_number,
    jl_fak_id,
    jl_eba_id,
    jl_jrnl_status,
    jl_jrnl_status_text,
    jl_jrnl_process_id,
    jl_description,
    jl_source_jrnl_id,
    jl_effective_date,
    jl_value_date,
    jl_entity,
    jl_epg_id,
    jl_account,
    jl_segment_1,
    jl_segment_2,
    jl_segment_3,
    jl_segment_4,
    jl_segment_5,
    jl_segment_6,
    jl_segment_7,
    jl_segment_8,
    jl_segment_9,
    jl_segment_10,
    jl_attribute_1,
    jl_attribute_2,
    jl_attribute_3,
    jl_attribute_4,
    jl_attribute_5,
    jl_reference_1,
    jl_reference_2,
    jl_reference_3,
    jl_reference_4,
    jl_reference_5,
    jl_reference_6,
    jl_reference_7,
    jl_reference_8,
    jl_reference_9,
    jl_reference_10, JL_TRAN_CCY,
    jl_tran_amount,
    jl_base_rate,
    jl_base_ccy,
    jl_base_amount,
    jl_local_rate,
    jl_local_ccy,
    jl_local_amount,
    jl_created_by,
    jl_created_on,
    jl_amended_by, 
    JL_AMENDED_ON,
    jl_recon_status,
    jl_translation_date,
    jl_bus_posting_date,
    jl_period_month,
    jl_period_year,
    jl_period_ltd,
    jl_type,
    jrnl_id,
    jrnl_line_number,
    jrnl_date,
    cr_dr_flag,
    lk_lookup_key_id,
    lk_lkt_lookup_type_code,
    lk_match_key1,
    lk_match_key2,
    lk_match_key3,
    lk_match_key4,
    lk_match_key5,
    lk_match_key6,
    lk_match_key7,
    lk_match_key8,
    lk_match_key9,
    lk_match_key10,
    lk_lookup_value1,
    lk_lookup_value2,
    lk_lookup_value3,
    lk_lookup_value4,
    lk_lookup_value5,
    lk_lookup_value6,
    lk_lookup_value7,
    lk_lookup_value8,
    lk_lookup_value9,
    lk_lookup_value10,
    lk_valid_from,
    lk_valid_to,
    lk_input_by,
    lk_input_time,
    lk_auth_by,
    lk_auth_status,
    lk_delete_time,
    lk_active,
    lpg_id,
    lk_effective_from,
    lk_effective_to,
    file_id,
    glint_jrnl_line_id,
    mk10_seg8,
    lk9_seg8
FROM
    cvr_nopost_jrnl_records_v
ORDER BY JL_JRNL_HDR_ID, JL_JRNL_LINE_NUMBER
    ;

BEGIN
    lv_START_TIME:=DBMS_UTILITY.GET_TIME(); 
    -- BUILD SQL QUERY

    SELECT MIN(MTH_START_DATE), MAX(MTH_END_DATE)
    INTO lv_min_date, lv_max_date
    FROM CVR_APPROVED_JRNLS_AAA_V;

LV_TEMP_INSERT_SQL:=
'INSERT INTO AAA.CVR_JRNL_HDR_LIST_TMP
  SELECT DISTINCT JL_JRNL_HDR_ID, JL_JRNL_LINE_NUMBER, JL_EFFECTIVE_DATE, DR_CR_FLAG
  FROM 
  (
  SELECT  JL.* 
           , APPR.*            
           , CASE 
                WHEN (
                        JL.JL_ENTITY    = APPR.LK_MATCH_KEY2 
                    AND JL.JL_SEGMENT_3 IN (APPR.LK_MATCH_KEY3,''NVS'')
                    AND JL.JL_SEGMENT_4 IN (APPR.LK_MATCH_KEY4,''NVS'') 
                    AND JL.JL_ACCOUNT   IN (APPR.LK_MATCH_KEY5,''NVS'')
                    AND JL.JL_SEGMENT_5 IN (APPR.LK_MATCH_KEY6,''NVS'') 
                    AND JL.JL_SEGMENT_6 IN (APPR.LK_MATCH_KEY7,''NVS'') 
                    AND JL.JL_SEGMENT_7 IN (APPR.LK_MATCH_KEY8,''NVS'') 
                    AND JL.JL_SEGMENT_8 IN (APPR.mk10_seg8,''NVS'')     
                    AND JL.JL_REFERENCE_10 IN (APPR.LK_MATCH_KEY9,''NVS'') 
                    ) 
                THEN ''Y'' 
                ELSE ''N'' 
             END AS CVR_RECORD_FLAG
         , case when jl.jl_tran_amount < 0 then ''C'' else ''D'' end as DR_CR_FLAG
    FROM DDD.RR_GLINT_BATCH_CONTROL BC
        INNER JOIN DDD.RR_GLINT_JOURNAL_FILE JF
            ON  JF.RGJF_RGBC_ID = BC.RGBC_ID

        INNER JOIN DDD.RR_GLINT_JOURNAL_LINE GL
            ON  GL.RGJL_RGJ_RGBC_ID = BC.RGBC_ID

        INNER JOIN AAA.CVR_APPROVED_JRNLS_AAA_V APPR
            ON  APPR.FILE_ID = JF.RGJF_RGF_ID
            AND APPR.GLINT_JRNL_LINE_ID = GL.RGJL_ID
            AND APPR.LK_MATCH_KEY9 = GL.REF1_BATCH_NAME

        INNER JOIN DDD.RR_GLINT_JOURNAL_MAPPING GM
            ON  GM.RGJM_RGBC_ID = BC.RGBC_ID
            AND TRUNC(LAST_DAY(GM.RGJM_EFFECTIVE_DATE)) = BC.RGBC_ACCOUNTING_DATE
            AND GM.RGJM_RGJ_ID = JF.RGJF_RGJ_ID

        INNER JOIN CCC.SLR_JRNL_LINES JL
            ON  JL.JL_EFFECTIVE_DATE = GM.RGJM_EFFECTIVE_DATE
            AND JL.JL_JRNL_HDR_ID = GM.RGJM_INPUT_JRNL_ID
            AND JL.JL_EFFECTIVE_DATE BETWEEN '''||lv_min_date||''' and '''||lv_max_date||''' 

        INNER JOIN OGL_JRNL_FDBCK_STG OGL
            ON  OGL.ATTRIBUTE3 = JF.RGJF_RGF_ID
            AND OGL.ATTRIBUTE1 = GL.RGJL_ID
    )
    WHERE CVR_RECORD_FLAG = ''Y''
';
DBMS_OUTPUT.PUT_LINE('LV_TEMP_INSERT_SQL = '||LV_TEMP_INSERT_SQL);

    -- CHECK IF THERE ARE ANY RECORDS MARKED FOR REVERSAL IN FR_GENERAL_LOOKUP
    BBB.pr_message(0, 'CVR GLINT JOURNAL MERGE (AAA.PK_CVR_ERP.pREVERSAL) - START', 9, s_proc_name, null, null, null, 'AAA', 'PL/SQL');


    -- CHECK IF THERE ARE ANY APPROVED RECORDS IN GUI
    SELECT COUNT(1)
    INTO p_precheck_cnt
    FROM BBB.fr_general_lookup 
    WHERE lk_lkt_lookup_type_code = 'CVR_JOURNAL_APPROVAL'
    AND lk_lookup_value10 = 'A'
    AND lk_active = 'A'
    ;

    IF p_precheck_cnt > 0 
    THEN
        BBB.pr_message(0, 'CVR (AAA.PK_CVR_ERP.pREVERSAL) - BEGIN TEMP TABLE DATA INSERT', 9, s_proc_name, null, null, null, 'AAA', 'PL/SQL');    
        EXECUTE IMMEDIATE 'truncate table CVR_JRNL_HDR_LIST_TMP';
        EXECUTE IMMEDIATE LV_TEMP_INSERT_SQL;
        lv_insert_count := SQL%ROWCOUNT;
        BBB.pr_message(0, 'CVR (AAA.PK_CVR_ERP.pREVERSAL) - FINISHED TEMP TABLE DATA INSERT', 9, s_proc_name, null, null, null, 'AAA', 'PL/SQL');    

        IF lv_insert_count = 0 THEN
            ROLLBACK;
            RAISE no_records_found_cvr_tmp;
        ELSE
            COMMIT;
        END IF;

    ELSE
        RAISE no_records_found_cvr_gui;

    END IF;
     --CREATE REVERSAL & CVR JOURNAL RECORDS AND INSERT INTO AAA.ABC_JOURNAL_REVERSAL_AAA table
        FOR i IN c1 LOOP

            --REVERSALS
            INSERT INTO AAA.ABC_JOURNAL_REVERSAL_AAA (JRS_ID, JRS_JL_JRNL_HDR_ID, JRS_JL_JRNL_LINE, JRS_TRAN_AMOUNT_REVERSAL, JRS_TRAN_CCY, JRS_VALUE_DATE, JRS_ENTITY, 
                        JRS_EPG_ID, JRS_ACCOUNT, JRS_SEGMENT_1, JRS_SEGMENT_2, JRS_SEGMENT_3, JRS_SEGMENT_4, JRS_SEGMENT_5, JRS_SEGMENT_6, JRS_SEGMENT_7, JRS_SEGMENT_8, JRS_SEGMENT_9, 
                        JRS_SEGMENT_10, JRS_ATTRIBUTE_1, JRS_ATTRIBUTE_2, JRS_ATTRIBUTE_3, JRS_ATTRIBUTE_4, JRS_ATTRIBUTE_5, JRS_REFERENCE_1, JRS_REFERENCE_2, JRS_REFERENCE_3, JRS_REFERENCE_4, 
                        JRS_REFERENCE_5, JRS_REFERENCE_6, JRS_REFERENCE_7, JRS_REFERENCE_8, JRS_REFERENCE_9, JRS_REFERENCE_10, EVENT_STATUS, JRS_CREATED_DATE, JRS_UPDATED_DATE, JRS_BUS_DATE, 
                        JRS_BUS_PERIOD, JRS_TASK_ID, JRS_BUS_DATE_REVERSAL, LPG_ID, RETRIES, JRS_JRNL_TYPE_OVERRIDE)

                        VALUES(SQ_ABC_JOURNAL_REVERSAL.NEXTVAL,i.JL_JRNL_HDR_ID,i.JL_JRNL_LINE_NUMBER,i.JL_TRAN_AMOUNT*-1, i.JL_TRAN_CCY, i.JL_VALUE_DATE, i.JL_ENTITY, i.JL_EPG_ID, i.JL_ACCOUNT, i.JL_SEGMENT_1, 
                               i.JL_SEGMENT_2,i.JL_SEGMENT_3,i.JL_SEGMENT_4,i.JL_SEGMENT_5,i.JL_SEGMENT_6,i.JL_SEGMENT_7, i.JL_SEGMENT_8, i.JL_SEGMENT_9, i.JL_SEGMENT_10,
                               i.JL_ATTRIBUTE_1,i.JL_ATTRIBUTE_2,i.JL_ATTRIBUTE_3,i.JL_ATTRIBUTE_4,i.JL_ATTRIBUTE_5,i.JL_REFERENCE_1,i.JL_REFERENCE_2,i.JL_REFERENCE_3,i.JL_REFERENCE_4,
                               i.JL_REFERENCE_5,i.JL_REFERENCE_6,i.JL_REFERENCE_7,i.JL_REFERENCE_8,i.JL_REFERENCE_9,i.JL_REFERENCE_10,'U',i.JL_CREATED_ON,i.JL_AMENDED_ON,i.JL_BUS_POSTING_DATE,
                               to_number(to_char(i.JL_BUS_POSTING_DATE,'RRRRMM')),lv_task_id,i.JL_EFFECTIVE_DATE,2,0, 'CVRNOPOSTREV'
                              );
            lv_jrnl_counter := lv_jrnl_counter+1;
            -- NEW CVR JOURNALS
            IF i.cvr_record = 'N'
            THEN
                INSERT INTO AAA.ABC_JOURNAL_REVERSAL_AAA 
                            (JRS_ID, JRS_JL_JRNL_HDR_ID, JRS_JL_JRNL_LINE, JRS_TRAN_AMOUNT_REVERSAL, JRS_TRAN_CCY, JRS_VALUE_DATE, JRS_ENTITY, 
                            JRS_EPG_ID, JRS_ACCOUNT, JRS_SEGMENT_1, JRS_SEGMENT_2, JRS_SEGMENT_3, JRS_SEGMENT_4, JRS_SEGMENT_5, JRS_SEGMENT_6, JRS_SEGMENT_7, JRS_SEGMENT_8, JRS_SEGMENT_9, 
                            JRS_SEGMENT_10, JRS_ATTRIBUTE_1, JRS_ATTRIBUTE_2, JRS_ATTRIBUTE_3, JRS_ATTRIBUTE_4, JRS_ATTRIBUTE_5, JRS_REFERENCE_1, JRS_REFERENCE_2, JRS_REFERENCE_3, JRS_REFERENCE_4, 
                            JRS_REFERENCE_5, JRS_REFERENCE_6, JRS_REFERENCE_7, JRS_REFERENCE_8, JRS_REFERENCE_9, JRS_REFERENCE_10, EVENT_STATUS, JRS_CREATED_DATE, JRS_UPDATED_DATE, JRS_BUS_DATE, 
                            JRS_BUS_PERIOD, JRS_TASK_ID, JRS_BUS_DATE_REVERSAL, LPG_ID, RETRIES, JRS_JRNL_TYPE_OVERRIDE)

                            VALUES(SQ_ABC_JOURNAL_REVERSAL.NEXTVAL,i.JL_JRNL_HDR_ID,i.JL_JRNL_LINE_NUMBER,i.JL_TRAN_AMOUNT, i.JL_TRAN_CCY, i.JL_VALUE_DATE, i.JL_ENTITY, i.JL_EPG_ID, i.JL_ACCOUNT, i.JL_SEGMENT_1, 
                                   i.JL_SEGMENT_2,i.JL_SEGMENT_3,i.JL_SEGMENT_4,i.JL_SEGMENT_5,i.JL_SEGMENT_6,i.JL_SEGMENT_7, i.JL_SEGMENT_8, i.JL_SEGMENT_9, i.JL_SEGMENT_10,
                                   i.JL_ATTRIBUTE_1,i.JL_ATTRIBUTE_2,i.JL_ATTRIBUTE_3,i.JL_ATTRIBUTE_4,i.JL_ATTRIBUTE_5,i.JL_REFERENCE_1,i.JL_REFERENCE_2,i.JL_REFERENCE_3,i.JL_REFERENCE_4,
                                   i.JL_REFERENCE_5,i.JL_REFERENCE_6,i.JL_REFERENCE_7,i.JL_REFERENCE_8,i.JL_REFERENCE_9,i.JL_REFERENCE_10,'U',i.JL_CREATED_ON,i.JL_AMENDED_ON,i.JL_BUS_POSTING_DATE,
                                   to_number(to_char(i.JL_BUS_POSTING_DATE,'RRRRMM')),lv_task_id,i.JL_EFFECTIVE_DATE,2,0, 'CVRNOPOSTB'
                                  );
            ELSE
                INSERT INTO AAA.ABC_JOURNAL_REVERSAL_AAA 
                            (JRS_ID, JRS_JL_JRNL_HDR_ID, JRS_JL_JRNL_LINE, JRS_TRAN_AMOUNT_REVERSAL, JRS_TRAN_CCY, JRS_VALUE_DATE, JRS_ENTITY, 
                            JRS_EPG_ID, JRS_ACCOUNT, JRS_SEGMENT_1, JRS_SEGMENT_2, JRS_SEGMENT_3, JRS_SEGMENT_4, JRS_SEGMENT_5, JRS_SEGMENT_6, JRS_SEGMENT_7, JRS_SEGMENT_8, JRS_SEGMENT_9, 
                            JRS_SEGMENT_10, JRS_ATTRIBUTE_1, JRS_ATTRIBUTE_2, JRS_ATTRIBUTE_3, JRS_ATTRIBUTE_4, JRS_ATTRIBUTE_5, JRS_REFERENCE_1, JRS_REFERENCE_2, JRS_REFERENCE_3, JRS_REFERENCE_4, 
                            JRS_REFERENCE_5, JRS_REFERENCE_6, JRS_REFERENCE_7, JRS_REFERENCE_8, JRS_REFERENCE_9, JRS_REFERENCE_10, EVENT_STATUS, JRS_CREATED_DATE, JRS_UPDATED_DATE, JRS_BUS_DATE, 
                            JRS_BUS_PERIOD, JRS_TASK_ID, JRS_BUS_DATE_REVERSAL, LPG_ID, RETRIES, JRS_JRNL_TYPE_OVERRIDE)

                            VALUES(SQ_ABC_JOURNAL_REVERSAL.NEXTVAL --JRS_ID
                                  , i.JL_JRNL_HDR_ID --JRS_JL_JRNL_HDR_ID
                                  , i.JL_JRNL_LINE_NUMBER --JRS_JL_JRNL_LINE
                                  , i.JL_TRAN_AMOUNT --JRS_TRAN_AMOUNT_REVERSAL
                                  , i.JL_TRAN_CCY --JRS_TRAN_CCY
                                  , i.JL_VALUE_DATE --JRS_VALUE_DATE
                                  , i.LK_LOOKUP_VALUE1 --JRS_ENTITY
                                  , i.JL_EPG_ID --JRS_EPG_ID
                                  , i.LK_LOOKUP_VALUE4 --JRS_ACCOUNT
                                  , i.JL_SEGMENT_1 --JRS_SEGMENT_1
                                  , i.JL_SEGMENT_2 --JRS_SEGMENT_2
                                  , i.LK_LOOKUP_VALUE2 --JRS_SEGMENT_3
                                  , i.LK_LOOKUP_VALUE3 --JRS_SEGMENT_4
                                  , i.LK_LOOKUP_VALUE5 --JRS_SEGMENT_5
                                  , i.LK_LOOKUP_VALUE6 --JRS_SEGMENT_6
                                  , i.LK_LOOKUP_VALUE7 --JRS_SEGMENT_7
                                  , i.lk9_seg8 --JRS_SEGMENT_8
                                  , i.JL_SEGMENT_9 --JRS_SEGMENT_9
                                  , i.JL_SEGMENT_10 --JRS_SEGMENT_10
                                  , i.JL_ATTRIBUTE_1 --JRS_ATTRIBUTE_1
                                  , i.JL_ATTRIBUTE_2 --JRS_ATTRIBUTE_2
                                  , i.JL_ATTRIBUTE_3 --JRS_ATTRIBUTE_3
                                  , i.JL_ATTRIBUTE_4 --JRS_ATTRIBUTE_4
                                  , i.JL_ATTRIBUTE_5 --JRS_ATTRIBUTE_5
                                  , i.JL_REFERENCE_1 --JRS_REFERENCE_1
                                  , i.JL_REFERENCE_2 --JRS_REFERENCE_2
                                  , i.JL_REFERENCE_3 --JRS_REFERENCE_3
                                  , i.JL_REFERENCE_4 --JRS_REFERENCE_4
                                  , i.JL_REFERENCE_5 --JRS_REFERENCE_5
                                  , i.JL_REFERENCE_6 --JRS_REFERENCE_6
                                  , i.JL_REFERENCE_7 --JRS_REFERENCE_7
                                  , i.JL_REFERENCE_8 --JRS_REFERENCE_8
                                  , i.JL_REFERENCE_9 --JRS_REFERENCE_9
                                  , i.JL_REFERENCE_10 --JRS_REFERENCE_10
                                  , 'U' --EVENT_STATUS
                                  , i.JL_CREATED_ON --JRS_CREATED_DATE
                                  , i.JL_AMENDED_ON --JRS_UPDATED_DATE
                                  , i.JL_BUS_POSTING_DATE --JRS_BUS_DATE
                                  , to_number(to_char(i.JL_BUS_POSTING_DATE,'RRRRMM')) --JRS_BUS_PERIOD
                                  , lv_task_id --JRS_TASK_ID
                                  , i.JL_EFFECTIVE_DATE --JRS_BUS_DATE_REVERSAL
                                  , 2 --LPG_ID
                                  , 0 -- RETRIES
                                  ,'CVRNOPOSTB' --JRS_JRNL_TYPE_OVERRIDE
                                  );            
            END IF;
            lv_jrnl_counter := lv_jrnl_counter+1;
        END LOOP;

        if lv_jrnl_counter = 0
        then
            ROLLBACK;
            raise no_records_found_cvr;
        else
        --UPDATE STATUS TO 'P' FOR GENERAL LOOKUP RECORDS.
        BBB.PR_CVR_FDR_UPDATE;

        COMMIT;   
        BBB.pr_message(0, 'CVR GLINT JOURNAL MERGE (AAA.PK_CVR_ERP.pREVERSAL) - execution time: ' || (DBMS_UTILITY.GET_TIME() - lv_START_TIME)/100.0 || ' s.', 9, s_proc_name, null, null, null, 'AAA', 'PL/SQL');
        BBB.pr_message(0, 'CVR GLINT JOURNAL MERGE (AAA.PK_CVR_ERP.pREVERSAL) - End', 9, s_proc_name, null, null, null, 'AAA', 'PL/SQL');
        o_update_count := lv_jrnl_counter; 
        o_bs_status := 'C';
        end if;

EXCEPTION 
    WHEN no_records_found_cvr_gui THEN
    BBB.pr_error(0, 'No approved CVR journals found in FR_GENERAL_LOOKUP.', 1, s_proc_name, 'OGL_JRNL_FDBCK_STG', null, 'ATTRIBUTE3', 'AAA', 'PL/SQL','A');
    o_bs_status := 'C';
    o_update_count := 0;

    WHEN no_records_found_cvr_tmp THEN
    BBB.pr_error(0, 'No approved CVR journals found in AAA.CVR_NOPOST_JRNL_RECORDS_V.', 1, s_proc_name, null, null, null, 'AAA', 'PL/SQL','A');
    o_bs_status := 'F';
    o_update_count := 0;

    WHEN no_records_found_cvr THEN
    BBB.pr_error(0, 'No new journals created in AAA.ABC_JOURNAL_REVERSAL_AAA.', 1, s_proc_name, null, null, null, 'AAA', 'PL/SQL','A');
    o_bs_status := 'F';
    o_update_count := 0;


    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Process failed on fatal error. Please check FR_LOG for details.');
        BBB.pr_error(0, 'CVR ERP REVERSAL JOURNALS (AAA.PK_CVR_ERP.pREVERSAL) failed due to unhandled error. Check FR_LOG and ABC Audit Log.', 0, s_proc_name, NULL, NULL, NULL, 'AAA', 'PL/SQL');
        RAISE_APPLICATION_ERROR(-20001, 'Fatal error during call of AAA.PK_CVR_ERP.pREVERSAL: ' || SQLERRM);
        o_bs_status := 'F';
        o_update_count := 0;

END pReversal;

END PK_CVR_ERP;
/
