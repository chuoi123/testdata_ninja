create or replace package testdata_ninja

as

  /** Main package of the testdata code. Generators are defined here.
  * @author Morten Egan
  * @version 0.0.1
  * @project TESTDATA_NINJA
  */
  npg_version         varchar2(250) := '0.0.1';

  -- Globals
  g_default_generator_rows        number := 10;

  type col_assumptions is record (
    col_is_unique                 number
    , col_all_null                number
    , col_low_high_same           number
  );

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
  );

  function guess_data_generator (
    data_type                   in        varchar2
    , column_name               in        varchar2
    , value_example             in        varchar2 default null
    , value_low                 in        raw default null
    , value_high                in        raw default null
  )
  return varchar2;

end testdata_ninja;
/
