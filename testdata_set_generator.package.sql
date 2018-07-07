create or replace package testdata_set_generator
authid current_user

as

  /** Package to create full sets of generators to build complete data sets.
  * @author Morten Egan
  * @version 1.0.0
  * @project TESTDATA_NINJA
  */
  npg_version         varchar2(250) := '1.0.0';

  /** Procedure to create a set of generator expanded from one table.
  * @author Morten Egan
  * @param set_name The name of the generator set.
  * @param generator_format The format of the generator.
  */
  procedure generator_set_create (
    set_name                    in        varchar2
    , set_center_table          in        varchar2 default null
    , backward_branching        in        boolean default true
  );

end testdata_set_generator;
/