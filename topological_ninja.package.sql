create or replace package topological_ninja

as

  /** This package provides an ability to do topological sorting of steps with dependants.
  * @author Morten Egan
  * @version 0.0.1
  * @project TOPOLOGICAL_NINJA
  */
  npg_version         varchar2(250) := '0.0.1';

  -- End result sorted types.
  type topo_number_list is table of number;
  type topo_char_list is table of varchar2(4000);

  -- Working set types and records.
  type topo_dependency_list is table of varchar2(4000) index by varchar2(4000);

  /** Do a topological sort of values and return the sorted list of values.
  * @author Morten Egan
  * @return topo_number_list The sorted list of values.
  */
  function f_s (
    dependency_list         topo_dependency_list
    , full_list_num         topo_number_list default null
    , full_list_char        topo_char_list default null
  )
  return topo_number_list;

  /** Do a topological sort of numbers and return the sorted list of numbers.
  * @author Morten Egan
  * @return topo_number_list The sorted list of numbers.
  */
  function f_s_num (
    dependency_list         topo_dependency_list
    , full_list_num         topo_number_list
  )
  return topo_number_list;

end topological_ninja;
/
