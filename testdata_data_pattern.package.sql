create or replace package testdata_data_pattern

as

  /** Pattern utilities for the testdata_ninja package.
  * @author Morten Egan
  * @version 0.0.1
  * @project TESTDATA_NINJA
  */
  npg_version         varchar2(250) := '0.0.1';

  type pattern_dict_rec is record (
    regexp_pattern              varchar2(4000)
    , pattern_name              varchar2(250)
    , random_generator          varchar2(250)
    , generator_args            varchar2(4000)
  );
  type pattern_dict_tab is table of pattern_dict_rec;
  pattern_dict      pattern_dict_tab;

  /** Find a known pattern in a column.
  * @author Morten Egan
  * @param metadata The metadata
  */
  procedure find_known_pattern_in_col (
    metadata              in out nocopy       testdata_ninja.main_tab_meta
    , col_idx             in                  number
  );

  /** Try and guess pattern from data instead of known pattern.
  * @author Morten Egan
  * @param metadata The metadata
  */
  procedure guess_pattern_in_col (
    metadata              in out nocopy       testdata_ninja.main_tab_meta
    , col_idx             in                  number
  );

end testdata_data_pattern;
/
