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
  g_default_population_size       number := 0.001;

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

end testdata_ninja;
/
