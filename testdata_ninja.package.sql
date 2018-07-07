create or replace package testdata_ninja
authid current_user

as

  /** Main package of the testdata code. Generators are defined here.
  * @author Morten Egan
  * @version 1.0.0
  * @project TESTDATA_NINJA
  */
  npg_version         varchar2(250) := '1.0.0';

  -- Keep track of input values.
  type track_input_rec is record (
    input_position        number
    , input_name          varchar2(128)
    , draw_from_col       varchar2(128)
    , draw_from_col_num   number
  );
  type track_input_tab1 is table of track_input_rec;
  type track_input_tab2 is table of track_input_tab1;
  g_input_track           track_input_tab2;

  -- json variables
  type j_result_rec is record (
    j_column_name                       varchar2(250)
    , j_column_datatype                 varchar2(250)
    , j_column_type                     varchar2(250)
    , j_builtin_type                    varchar2(250)
    , j_builtin_function                varchar2(250)
    , j_builtin_startfrom               varchar2(250)
    , j_builtin_increment_min           varchar2(250)
    , j_builtin_increment_max           varchar2(250)
    , j_builtin_increment_component     varchar2(250)
    , j_fixed_value                     varchar2(250)
    , j_reference_table                 varchar2(250)
    , j_reference_column                varchar2(250)
    , j_reference_distribution_type     varchar2(250)
    , j_distribution_simple_val         varchar2(250)
    , j_distribution_range_start        varchar2(250)
    , j_distribution_range_end          varchar2(250)
    , j_distribution_weighted           varchar2(4000)
    , j_reference_static_list           varchar2(250)
    , j_generator                       varchar2(250)
    , j_nullable                        varchar2(250)
    , j_arguments                       varchar2(250)
  );
  type j_result_tab is table of j_result_rec;

  -- Globals
  g_default_generator_rows        number := 10;

  type col_assumptions is record (
    col_is_unique                 number
    , col_all_null                number
    , col_low_high_same           number
  );

  type col_chk_cons is table of varchar2(4000) index by binary_integer;

  type main_tab_col_meta is record (
    column_name                   varchar2(128)
    , column_type                 varchar2(128)
    , column_base_data            all_tab_cols%rowtype
    , column_base_stats           all_tab_col_statistics%rowtype
    , column_assumptions          col_assumptions
    , inf_col_domain              varchar2(128)
    , inf_col_change_pattern      varchar2(128)
    , inf_col_type                varchar2(128)
    , inf_col_generator           varchar2(512)
    , inf_col_generator_args      varchar2(4000)
    , inf_col_generator_nullable  number
    , inf_fixed_value             varchar2(4000)
    , inf_builtin_type            varchar2(100)
    , inf_builtin_function        varchar2(100)
    , inf_builtin_startpoint      varchar2(100)
    , inf_builtin_increment       varchar2(100)
    , inf_builtin_define_code     varchar2(4000)
    , inf_builtin_logic_code      varchar2(4000)
    , column_is_foreign           number
    , column_def_ref_tab          varchar2(128)
    , column_def_ref_col          varchar2(128)
    , inf_ref_type                varchar2(128)
    , inf_ref_distr_start         varchar2(4000)
    , inf_ref_distr_end           varchar2(4000)
    , inf_ref_define_code         varchar2(4000)
    , inf_ref_loader_code         varchar2(4000)
    , inf_ref_logic_code          varchar2(4000)
    , column_is_check             number
    , column_is_unique            number
    , inf_unique_define_code      varchar2(4000)
    , inf_unique_logic_code       varchar2(4000)
  );
  type main_tab_cols is table of main_tab_col_meta;

  type main_tab_meta is record (
    table_name                    varchar2(128)
    , table_base_data             all_tables%rowtype
    , table_base_stats            all_tab_statistics%rowtype
    , inf_table_domain            varchar2(128)
    , table_columns               main_tab_cols
  );

  type generator_column_rec is record (
    column_name           varchar2(500)
    , data_type           varchar2(500)
    , column_type         varchar2(500)
    , column_rule         varchar2(4000)
    , generator           varchar2(500)
    , generator_args      varchar2(500)
    , generator_nullable  number
    , reference_table     varchar2(4000)
    , reference_column    varchar2(500)
    , ref_dist_type       varchar2(500)
    , ref_dist_default    varchar2(500)
    , ref_define_code     varchar2(4000)
    , ref_loader_code     varchar2(4000)
    , ref_logic_code      varchar2(4000)
    , fixed_value         varchar2(4000)
    , builtin_type        varchar2(100)
    , builtin_function    varchar2(100)
    , builtin_startpoint  varchar2(100)
    , builtin_increment   varchar2(100)
    , builtin_define_code varchar2(4000)
    , builtin_logic_code  varchar2(4000)
  );
  type generator_columns is table of generator_column_rec;

  /** Parse the generator format into expected record types before building.
  * This makes building the custom generator a lot easier.
  * @author Morten Egan
  * @return generator_columns The columns in a parsed format.
  */
  function parse_generator_cols (
    column_metadata             in        varchar2
    , column_order              out       topological_ninja.topo_number_list
  )
  return generator_columns;

  /** Procedure to create custom generators.
  * @author Morten Egan
  * @param generator_name The name of the generator.
  * @param generator_format The format of the generator.
  */
  procedure generator_create (
    generator_name              in        varchar2
    , generator_format          in        varchar2 default null
    , generator_table           in        varchar2 default null
    , generator_table_owner     in        varchar2 default user
  );

end testdata_ninja;
/
