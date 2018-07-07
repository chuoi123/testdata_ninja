create or replace package testdata_generator_domains

as

  /** Package to supply and set data domains for tables and columns.
  * @author Morten Egan
  * @version 1.0.0
  * @project TESTDATA_NINJA
  */
  npg_version         varchar2(250) := '1.0.0';

  -- Table data domain.
  type g_tab_domains is table of varchar2(4000) index by varchar2(250);
  g_table_domains     g_tab_domains;

  -- Column data domain.
  type col_domain_rec is record (
    col_name_hit            varchar2(4000)
    , col_generator         varchar2(128)
    , col_generator_args    varchar2(4000)
    , col_args_condition    number(1)
  );
  type col_domain_tab is table of col_domain_rec;
  type col_domain_type_list is table of col_domain_tab index by varchar2(128);
  g_column_domains    col_domain_type_list;

end testdata_generator_domains;
/
