create or replace package testdata_data_infer
authid current_user

as

  /** Package to infer or guess what test data to generate for a testdata_ninja generator.
  * @author Morten Egan
  * @version 1.0.0
  * @project TESTDATA_NINJA
  */
  npg_version         varchar2(250) := '1.0.0';

  g_column_value_max_sample_size        number := 1000;

  /** Infer data generator for a column in a table.
  * @author Morten Egan
  * @param metadata The metadata for the table.
  */
  procedure infer_generators (
    metadata             in out nocopy        testdata_ninja.main_tab_meta
  );

end testdata_data_infer;
/
