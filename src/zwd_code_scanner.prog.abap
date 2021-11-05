* https://github.com/boy0korea/ZWD_CODE_SCANNER
REPORT zwd_code_scanner.

TABLES: wdy_component, tadir.

SELECT-OPTIONS: s_packag FOR tadir-devclass,
                s_wdcomp FOR wdy_component-component_name .
PARAMETERS: p_find TYPE rssrch-tdfind LOWER CASE.

CLASS lcl_search_wb DEFINITION.
  PUBLIC SECTION.
    INTERFACES if_wb_manager.
ENDCLASS.

CLASS lcl_search_wb IMPLEMENTATION.
  METHOD if_wb_manager~process_back.
*   set todo request
    CREATE OBJECT p_wb_todo_request
      EXPORTING
        p_object_type = space
        p_object_name = space
        p_operation   = swbm_c_op_end.
  ENDMETHOD.
  METHOD if_wb_manager~process_forward.
  ENDMETHOD.
  METHOD if_wb_manager~get_status.
  ENDMETHOD.
  METHOD if_wb_manager~control_pbo.
  ENDMETHOD.
  METHOD if_wb_manager~control_pai.
  ENDMETHOD.
  METHOD if_wb_manager~request_tool_access.
    DATA: lo_search_wb_manager TYPE REF TO if_wb_manager.
    DATA: obj_tool_man TYPE REF TO cl_wb_tool_manager.
    DATA: obj_tool     TYPE REF TO if_wb_program.
    DATA: objname TYPE c LENGTH 132.
    DATA: obj_prog_state TYPE REF TO if_wb_source_state.
    DATA: len TYPE i.

    TRY.
        obj_prog_state ?= p_wb_request->object_state.

        CASE p_wb_request->object_type.
          WHEN 'OSO'. "Klasse geschützter Bereich
            objname = '==============================CO'.
            len = strlen( p_wb_request->object_name ).
            objname(len) = p_wb_request->object_name.

          WHEN OTHERS.
            objname = p_wb_request->object_name.
            CONDENSE objname.

        ENDCASE.

        DATA: str_head TYPE slin_head.
        DATA: str_info TYPE cl_slin_navi=>access_info.
        DATA: obj_slin_res TYPE REF TO cl_slin_virtual_resources.

        obj_slin_res = cl_slin_virtual_resources=>get_instance( space ).

        str_head-src_incl = objname.
        str_head-src_line = obj_prog_state->line.
        str_head-editor = 'P'.

        str_info = cl_slin_navi=>access_info_from_head(
                    vres    = obj_slin_res
                    head    = str_head ).

        DATA: lv_show TYPE flag.
        IF p_wb_request->operation EQ 'EDIT'.
          lv_show = abap_false.
        ELSE.
          lv_show = abap_true.
        ENDIF.
        cl_slin_navi=>display_object( rfcdest = space
                                      show = lv_show
                                      access_info = str_info ).

      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.
  METHOD if_wb_manager~set_workspace.
  ENDMETHOD.
  METHOD if_wb_manager~deactivate.
  ENDMETHOD.
  METHOD if_wb_manager~get_window.
  ENDMETHOD.
  METHOD if_wb_manager~create_secondary_window.
  ENDMETHOD.
  METHOD if_wb_manager~delete_secondary_window.
  ENDMETHOD.
  METHOD if_wb_manager~get_tool_resolution_agent.
  ENDMETHOD.
  METHOD if_wb_manager~set_navigation_context.
  ENDMETHOD.
  METHOD if_wb_manager~get_navigation_context.
  ENDMETHOD.
ENDCLASS.



START-OF-SELECTION.
  CONSTANTS: c_program_prefix(8) TYPE c VALUE '/1BCWDY/',
             c_spec_prefix(10)   TYPE c VALUE '/1BCWDY/S_',
             c_body_prefix(10)   TYPE c VALUE '/1BCWDY/B_'.
  DATA: lo_wb_request        TYPE REF TO cl_wb_request,
        lo_wb_search         TYPE REF TO cl_wb_search,
        lt_founds_sub        TYPE rsfounds,
        lt_founds            TYPE rsfounds,
        ls_founds            TYPE rsfnds_wa,
        lv_founds_name       TYPE rsfnds_wa-name,
        lv_seu_objkey        TYPE seu_objkey,
        lo_search_wb_manager TYPE REF TO lcl_search_wb,
        BEGIN OF ls_wdcomp,
          component_name   TYPE wdy_component-component_name,
          assistance_class TYPE wdy_component-assistance_class,
        END OF ls_wdcomp,
        lt_wdcomp         LIKE TABLE OF ls_wdcomp,
        lt_wdy_wb_geninfo TYPE TABLE OF wdy_wb_geninfo,
        ls_wdy_wb_geninfo TYPE wdy_wb_geninfo,
        lv_guid           TYPE wdy_wb_geninfo-guid,
        lt_classname      TYPE TABLE OF seoclsname,
        lv_classname      TYPE seoclsname.

  CREATE OBJECT lo_search_wb_manager.
  CREATE OBJECT lo_wb_search.
  lo_wb_search->if_wb_program~wb_manager = lo_search_wb_manager.


  IF p_find IS INITIAL.
    RETURN.
  ENDIF.
  IF s_packag IS INITIAL AND s_wdcomp IS INITIAL.
    RETURN.
  ENDIF.

  IF s_packag IS INITIAL.
    SELECT component_name assistance_class
      INTO TABLE lt_wdcomp
      FROM wdy_component
      WHERE component_name IN s_wdcomp
        AND version = 'A'.
  ELSE.
    SELECT component_name assistance_class
      INTO TABLE lt_wdcomp
      FROM wdy_component AS a
      JOIN tadir AS b
        ON a~component_name = b~obj_name
      WHERE a~component_name IN s_wdcomp
        AND a~version = 'A'
        AND b~pgmid = 'R3TR'
        AND b~object = 'WDYN'
        AND b~devclass IN s_packag.
  ENDIF.

* cl_wdy_wb_naming_service=>get_classname_for_component( )
  CHECK: lt_wdcomp IS NOT INITIAL.
  SELECT *
    INTO TABLE lt_wdy_wb_geninfo
    FROM wdy_wb_geninfo
    FOR ALL ENTRIES IN lt_wdcomp
    WHERE component_name = lt_wdcomp-component_name.

  SORT lt_wdcomp BY assistance_class.
  DELETE ADJACENT DUPLICATES FROM lt_wdcomp COMPARING assistance_class.
  DELETE lt_wdcomp WHERE assistance_class IS INITIAL.
  SORT lt_wdcomp BY component_name.

  LOOP AT lt_wdy_wb_geninfo INTO ls_wdy_wb_geninfo WHERE controller_name IS INITIAL.
    CONCATENATE c_program_prefix ls_wdy_wb_geninfo-guid INTO lv_classname.
    APPEND lv_classname TO lt_classname.
    READ TABLE lt_wdcomp INTO ls_wdcomp WITH KEY component_name = ls_wdy_wb_geninfo-component_name BINARY SEARCH.
    IF sy-subrc EQ 0.
      APPEND ls_wdcomp-assistance_class TO lt_classname.
    ENDIF.
  ENDLOOP.
  SORT lt_wdy_wb_geninfo BY guid.


  LOOP AT lt_classname INTO lv_classname.
    FREE lo_wb_request.
    CLEAR lt_founds_sub.

    lv_seu_objkey = lv_classname.

    cl_wb_search=>create_search_replace_request(
    EXPORTING
      p_obj_name    = lv_seu_objkey
      p_obj_type    = swbm_c_type_class
      p_find_string = p_find
    IMPORTING
      p_request     = lo_wb_request ).

    CALL FUNCTION 'RS_SEARCH_START'
      EXPORTING
        i_search_handle   = lo_wb_search
        i_wb_request      = lo_wb_request
        i_suppress_dialog = abap_true
        i_find_string     = p_find
        i_search_mode     = 'GLOBAL'
      IMPORTING
        e_founds          = lt_founds_sub   " Table of Hits
      EXCEPTIONS
        x_not_found       = 1
        x_aborted         = 2
        OTHERS            = 3.

    APPEND LINES OF lt_founds_sub TO lt_founds.
  ENDLOOP.

  IF lt_founds IS NOT INITIAL.

    LOOP AT lt_founds INTO ls_founds WHERE obj_name(8) EQ c_program_prefix.
      IF lv_guid <> ls_founds-obj_name+10.
        lv_guid = ls_founds-obj_name+10.
        READ TABLE lt_wdy_wb_geninfo INTO ls_wdy_wb_geninfo WITH KEY guid = lv_guid BINARY SEARCH.
        IF sy-subrc EQ 0.
          lv_founds_name = ls_wdy_wb_geninfo-component_name && ` - ` && ls_wdy_wb_geninfo-controller_name.
        ELSE.
          CLEAR: lv_founds_name.
        ENDIF.
      ENDIF.

      IF lv_founds_name IS NOT INITIAL.
        ls_founds-name = lv_founds_name.
        MODIFY lt_founds FROM ls_founds TRANSPORTING name.
      ENDIF.
    ENDLOOP.

    CALL FUNCTION 'S_SEARCH_SHOW_LIST'
      EXPORTING
        i_search_handle = lo_wb_search
        i_founds        = lt_founds
        i_wbobj_type    = swbm_c_type_class.
  ENDIF.
