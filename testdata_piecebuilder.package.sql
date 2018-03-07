create or replace package testdata_piecebuilder

as

  /** Helper functions to build individual functionality of the testdata generator.
  * @author Morten Egan
  * @version 0.0.1
  * @project TESTDATA_NINJA
  */
  npg_version         varchar2(250) := '0.0.1';

  /** Help generate the necesarry values for a builtin generator.
  * @author Morten Egan
  * @param field_spec The specs of the field either in classic notation.
  */
  procedure parse_builtin (
    field_spec                in                    clob
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
  );

  /** Help generate the necesarry values for a builtin generator.
  * @author Morten Egan
  * @param field_spec The specs of the field either in JSON format.
  */
  procedure parse_builtin_json (
    field_spec                in                    testdata_ninja.j_result_tab
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
  );

  /** Help generate the necessary values for a builtin generator.
  * @author Morten Egan
  * @param field_spec The specs of the field either in classic notation.
  */
  procedure parse_fixed (
    field_spec                in                    clob
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
  );

  /** Help generate the necessary values for a builtin generator.
  * @author Morten Egan
  * @param field_spec The specs of the field either in JSON format.
  */
  procedure parse_fixed_json (
    field_spec                in                    testdata_ninja.j_result_tab
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
  );

  /** Help generate the necesarry values for a reference generator.
  * @author Morten Egan
  * @param field_spec The specs of the field either in classic notation.
  */
  procedure parse_reference (
    field_spec                in                    clob
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
  );

  /** Help generate the necesarry values for a reference generator.
  * @author Morten Egan
  * @param field_spec The specs of the field either in JSON format.
  */
  procedure parse_reference_json (
    field_spec                in                    testdata_ninja.j_result_tab
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
  );

  /** Generate values for reference list.
  * @author Morten Egan
  * @param field_spec The specs of the field either in classic notation.
  */
  procedure parse_referencelist (
    field_spec                in                    clob
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
  );

  /** Generate values for reference list.
  * @author Morten Egan
  * @param field_spec The specs of the field either in JSON format.
  */
  procedure parse_referencelist_json (
    field_spec                in                    testdata_ninja.j_result_tab
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
  );

  /** Generate values for generated fields.
  * @author Morten Egan
  * @param field_spec The specs of the field either in classic notation or in JSON format.
  */
  procedure parse_generated (
    field_spec                in                    clob
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
    , input_tracker           in out nocopy         testdata_ninja.track_input_tab2
    , input_idx               in                    number
  );

  /** Generate values for generated fields.
  * @author Morten Egan
  * @param field_spec The specs of the field either in JSON format.
  */
  procedure parse_generated_json (
    field_spec                in                    testdata_ninja.j_result_tab
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
    , input_tracker           in out nocopy         testdata_ninja.track_input_tab2
    , input_idx               in                    number
  );

end testdata_piecebuilder;
/
